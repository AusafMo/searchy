"""
Similarity Search with multi-signal retrieval.

Improvements over the original single-pass CLIP search:
1. Prompt ensembling  — average embeddings across multiple prompt templates
                        (Radford et al., 2021: +3-5% on ImageNet)
2. BM25 for OCR       — principled text scoring replacing naive word overlap
                        (Robertson et al., Probabilistic Relevance Framework)
3. Filename matching   — use filenames as an additional retrieval signal
4. Query expansion     — augment queries with visual synonyms
5. Reciprocal Rank Fusion — fuse ranked lists from each signal
                        (Cormack et al., SIGIR 2009)
"""

import math
import numpy as np
import os
import sys
import json
import time
from collections import Counter
from PIL import Image
from typing import List, Dict, Optional, Tuple

from clip_model import model_manager, get_device
from constants import (
    DEFAULT_TOP_K, DEFAULT_OCR_WEIGHT, OCR_TEXT_PREVIEW_LENGTH,
    RRF_K, BM25_K1, BM25_B,
    PROMPT_TEMPLATES, VISUAL_DESCRIPTORS,
)
from utils import load_image_index


# ── BM25 Scoring ────────────────────────────────────────────

def _tokenize(text: str) -> List[str]:
    """Simple whitespace + lowercase tokenizer."""
    return text.lower().split()


def bm25_score(query: str, document: str, avg_doc_len: float, doc_count: int,
               doc_freq: Dict[str, int]) -> float:
    """
    BM25 score for a single query-document pair.

    Based on Robertson et al., "The Probabilistic Relevance Framework: BM25 and Beyond"
    (Foundations and Trends in IR, 2009).

    Args:
        query: The search query.
        document: The document text (OCR text or filename).
        avg_doc_len: Average document length across the corpus.
        doc_count: Total number of documents in the corpus.
        doc_freq: Dict mapping term -> number of documents containing that term.
    """
    if not query or not document:
        return 0.0

    query_terms = _tokenize(query)
    doc_terms = _tokenize(document)
    doc_len = len(doc_terms)

    if doc_len == 0 or avg_doc_len == 0:
        return 0.0

    tf_map = Counter(doc_terms)
    score = 0.0

    for term in query_terms:
        tf = tf_map.get(term, 0)
        if tf == 0:
            continue

        df = doc_freq.get(term, 0)
        # IDF with smoothing to avoid negative values
        idf = math.log((doc_count - df + 0.5) / (df + 0.5) + 1.0)
        # TF saturation with length normalization
        tf_norm = (tf * (BM25_K1 + 1)) / (tf + BM25_K1 * (1 - BM25_B + BM25_B * doc_len / avg_doc_len))
        score += idf * tf_norm

    return score


def _build_corpus_stats(documents: List[str]) -> Tuple[float, int, Dict[str, int]]:
    """Pre-compute corpus-level BM25 statistics."""
    doc_freq: Dict[str, int] = {}
    total_len = 0
    doc_count = 0

    for doc in documents:
        if not doc:
            continue
        terms = set(_tokenize(doc))
        for term in terms:
            doc_freq[term] = doc_freq.get(term, 0) + 1
        total_len += len(_tokenize(doc))
        doc_count += 1

    avg_doc_len = total_len / doc_count if doc_count > 0 else 1.0
    return avg_doc_len, max(doc_count, 1), doc_freq


# ── Reciprocal Rank Fusion ──────────────────────────────────

def reciprocal_rank_fusion(ranked_lists: List[List[int]], k: int = RRF_K) -> List[Tuple[int, float]]:
    """
    Combine multiple ranked lists using RRF.

    Cormack, Clarke & Buettcher, "Reciprocal Rank Fusion outperforms Condorcet
    and individual Rank Learning Methods" (SIGIR 2009).

    Args:
        ranked_lists: List of ranked lists, each containing document indices
                     ordered by relevance (best first).
        k: Smoothing constant (default 60, per the original paper).

    Returns:
        List of (doc_index, rrf_score) tuples, sorted by score descending.
    """
    scores: Dict[int, float] = {}

    for ranked_list in ranked_lists:
        for rank, doc_idx in enumerate(ranked_list):
            scores[doc_idx] = scores.get(doc_idx, 0.0) + 1.0 / (k + rank + 1)

    return sorted(scores.items(), key=lambda x: x[1], reverse=True)


# ── Prompt Ensembling ───────────────────────────────────────

def _ensemble_text_embeddings(query: str, templates: List[str]) -> Optional[np.ndarray]:
    """
    Generate text embedding by averaging across multiple prompt templates.

    Radford et al. (2021) showed this gives +3.5% on ImageNet zero-shot
    classification. We apply it to retrieval queries.
    """
    embeddings = []
    for template in templates:
        prompt = template.format(query)
        emb = model_manager.get_text_embedding(prompt)
        if emb is not None:
            embeddings.append(emb)

    if not embeddings:
        return None

    # Average and re-normalize
    avg_embedding = np.mean(embeddings, axis=0)
    norm = np.linalg.norm(avg_embedding)
    if norm > 0:
        avg_embedding = avg_embedding / norm

    return avg_embedding


# ── Query Expansion ─────────────────────────────────────────

def _expand_query(query: str) -> List[str]:
    """
    Generate expanded query variants using visual descriptors.

    Returns the original query plus variants with synonym substitution.
    """
    queries = [query]
    query_lower = query.lower()
    query_words = query_lower.split()

    for word in query_words:
        if word in VISUAL_DESCRIPTORS:
            for synonym in VISUAL_DESCRIPTORS[word][:2]:  # Top 2 synonyms
                expanded = query_lower.replace(word, synonym)
                if expanded != query_lower:
                    queries.append(expanded)

    return queries


# ── Filename Matching ───────────────────────────────────────

def _filename_score(query: str, filepath: str) -> float:
    """Score how well a filename matches the query."""
    filename = os.path.splitext(os.path.basename(filepath))[0]
    # Normalize: replace common separators with spaces
    filename_clean = filename.replace('_', ' ').replace('-', ' ').replace('.', ' ').lower()

    query_lower = query.lower()

    # Exact substring match
    if query_lower in filename_clean:
        return 1.0

    # Word-level overlap
    query_words = set(query_lower.split())
    filename_words = set(filename_clean.split())

    if not query_words:
        return 0.0

    matches = len(query_words & filename_words)
    return matches / len(query_words)


# ── Main Search Class ───────────────────────────────────────

class CLIPSearcher:
    """Search interface with multi-signal retrieval and RRF fusion."""

    def __init__(self):
        self.device = get_device()

    def generate_text_embedding(self, text):
        """Generate normalized text embedding."""
        embedding = model_manager.get_text_embedding(text)
        if embedding is None:
            raise Exception("Failed to generate text embedding")
        return embedding

    def generate_image_embedding(self, image_path):
        """Generate embedding for an image file."""
        try:
            image = Image.open(image_path)
            if image.mode != 'RGB':
                image = image.convert('RGB')
            return model_manager.get_image_embedding(image)
        except Exception as e:
            print(f"Error generating embedding for {image_path}: {e}", file=sys.stderr)
            return None

    def find_similar(self, image_path, data_dir, top_k=DEFAULT_TOP_K):
        """Find images similar to the given image."""
        try:
            start_time = time.time()

            query_embedding = self.generate_image_embedding(image_path)
            if query_embedding is None:
                return {"error": f"Could not process image: {image_path}"}

            data = load_image_index(data_dir)
            if data is None:
                return {"error": "No images indexed yet. Please index a folder first."}

            embeddings = data['embeddings']
            image_paths = data['image_paths']

            if len(embeddings) == 0:
                return {"error": "No images indexed yet."}

            similarities = embeddings @ query_embedding
            sorted_indices = np.argsort(similarities)[::-1]

            results = []
            for idx in sorted_indices:
                if image_paths[idx] == image_path:
                    continue
                if len(results) >= top_k:
                    break
                results.append({
                    "path": image_paths[idx],
                    "similarity": float(similarities[idx])
                })

            total_time = time.time() - start_time
            return {
                "results": results,
                "query_image": image_path,
                "stats": {
                    "total_time": f"{total_time:.2f}s",
                    "images_searched": len(embeddings),
                    "images_per_second": f"{len(embeddings)/total_time:.2f}"
                }
            }

        except Exception as e:
            print(f"Error in find_similar: {e}", file=sys.stderr)
            return {"error": str(e)}

    def search(self, query, data_dir, top_k=DEFAULT_TOP_K, ocr_weight=DEFAULT_OCR_WEIGHT):
        """
        Multi-signal search combining:
        1. Semantic similarity (CLIP/SigLIP/PE-Core embeddings with prompt ensembling)
        2. OCR text matching (BM25)
        3. Filename matching (BM25)
        4. Query expansion (visual synonyms)

        Results are fused using Reciprocal Rank Fusion (RRF).
        """
        try:
            start_time = time.time()

            data = load_image_index(data_dir)
            if data is None:
                error_response = {"error": "No images indexed yet. Please index a folder first."}
                print(json.dumps(error_response))
                return error_response

            embeddings = data['embeddings']
            image_paths = data['image_paths']
            ocr_texts = data.get('ocr_texts', [''] * len(image_paths))

            n = len(embeddings)
            if n == 0:
                error_response = {"error": "No images indexed yet. Please index a folder first."}
                print(json.dumps(error_response))
                return error_response

            print(f"Loaded {n} embeddings", file=sys.stderr)

            # ── Signal 1: Semantic search with prompt ensembling ──
            # Expand query, ensemble each variant, then average
            expanded_queries = _expand_query(query)
            all_semantic_scores = []

            for q in expanded_queries:
                q_embedding = _ensemble_text_embeddings(q, PROMPT_TEMPLATES)
                if q_embedding is not None:
                    scores = embeddings @ q_embedding
                    all_semantic_scores.append(scores)

            if not all_semantic_scores:
                # Fallback to single raw query
                raw_emb = self.generate_text_embedding(query)
                semantic_scores = embeddings @ raw_emb
            else:
                # Average scores across all expanded+ensembled queries
                semantic_scores = np.mean(all_semantic_scores, axis=0)

            semantic_ranking = np.argsort(semantic_scores)[::-1].tolist()

            # ── Signal 2: BM25 over OCR text ──────────────────────
            ocr_avg_len, ocr_doc_count, ocr_doc_freq = _build_corpus_stats(ocr_texts)
            ocr_bm25_scores = np.array([
                bm25_score(query, ocr_text, ocr_avg_len, ocr_doc_count, ocr_doc_freq)
                for ocr_text in ocr_texts
            ])
            # Only rank docs that have non-zero OCR scores
            ocr_nonzero = [(i, s) for i, s in enumerate(ocr_bm25_scores) if s > 0]
            ocr_nonzero.sort(key=lambda x: x[1], reverse=True)
            ocr_ranking = [i for i, _ in ocr_nonzero]

            # ── Signal 3: BM25 over filenames ─────────────────────
            filenames = [
                os.path.splitext(os.path.basename(p))[0].replace('_', ' ').replace('-', ' ')
                for p in image_paths
            ]
            fn_avg_len, fn_doc_count, fn_doc_freq = _build_corpus_stats(filenames)
            fn_bm25_scores = np.array([
                bm25_score(query, fn, fn_avg_len, fn_doc_count, fn_doc_freq)
                for fn in filenames
            ])
            fn_nonzero = [(i, s) for i, s in enumerate(fn_bm25_scores) if s > 0]
            fn_nonzero.sort(key=lambda x: x[1], reverse=True)
            filename_ranking = [i for i, _ in fn_nonzero]

            # ── Fuse with RRF ─────────────────────────────────────
            ranked_lists = [semantic_ranking]
            if ocr_ranking:
                ranked_lists.append(ocr_ranking)
            if filename_ranking:
                ranked_lists.append(filename_ranking)

            fused = reciprocal_rank_fusion(ranked_lists)

            # ── Build results ─────────────────────────────────────
            # Fetch a larger candidate set then trim to top_k
            candidate_limit = min(top_k * 3, n)
            results = []
            for idx, rrf_score in fused[:candidate_limit]:
                if len(results) >= top_k:
                    break

                # Display score: normalize RRF score to 0-1 range for UI
                # Max possible RRF score = num_signals / (k+1)
                max_rrf = len(ranked_lists) / (RRF_K + 1)
                display_score = min(rrf_score / max_rrf, 1.0) if max_rrf > 0 else 0.0
                # Blend with raw semantic score for more intuitive display
                raw_semantic = float(semantic_scores[idx])
                display_score = 0.6 * display_score + 0.4 * max(raw_semantic, 0.0)

                result = {
                    "path": image_paths[idx],
                    "similarity": float(min(display_score, 1.0))
                }
                if ocr_texts[idx]:
                    result["ocr_text"] = ocr_texts[idx][:OCR_TEXT_PREVIEW_LENGTH]
                results.append(result)

            total_time = time.time() - start_time
            ocr_count = sum(1 for t in ocr_texts if t.strip())
            final_output = {
                "results": results,
                "stats": {
                    "total_time": f"{total_time:.2f}s",
                    "images_searched": n,
                    "images_per_second": f"{n/total_time:.2f}",
                    "images_with_ocr": ocr_count,
                    "signals_used": len(ranked_lists),
                    "queries_expanded": len(expanded_queries),
                    "prompt_templates": len(PROMPT_TEMPLATES),
                }
            }

            print(json.dumps(final_output))
            return final_output

        except Exception as e:
            print(json.dumps({"error": str(e)}))
            return None


def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Missing arguments"}))
        return

    query = sys.argv[1]
    top_k = int(sys.argv[2])
    data_dir = sys.argv[3]

    searcher = CLIPSearcher()
    searcher.search(query, data_dir, top_k)


if __name__ == "__main__":
    main()
