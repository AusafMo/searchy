"""Search routes: /search, /text-search, /similar, /duplicates."""

import os
import logging
import time
import numpy as np
from typing import List
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from constants import DEFAULT_DATA_DIR, DEFAULT_TOP_K, DEFAULT_OCR_WEIGHT, DEFAULT_SIMILARITY_THRESHOLD, OCR_TEXT_PREVIEW_LENGTH, LARGE_BATCH_SIZE
from utils import is_user_image, load_image_index, UnionFind

router = APIRouter()
logger = logging.getLogger(__name__)


class SearchRequest(BaseModel):
    query: str
    top_k: int
    data_dir: str
    ocr_weight: float = DEFAULT_OCR_WEIGHT


class DuplicatesRequest(BaseModel):
    threshold: float = DEFAULT_SIMILARITY_THRESHOLD
    data_dir: str = DEFAULT_DATA_DIR


class TextSearchRequest(BaseModel):
    query: str
    top_k: int = DEFAULT_TOP_K
    data_dir: str = DEFAULT_DATA_DIR


class SimilarRequest(BaseModel):
    image_path: str
    top_k: int = DEFAULT_TOP_K
    data_dir: str = DEFAULT_DATA_DIR


def get_file_metadata(path: str) -> dict:
    """Get file metadata (size, date) for a given path."""
    try:
        if os.path.exists(path):
            from datetime import datetime
            stat_info = os.stat(path)
            return {
                "size": stat_info.st_size,
                "date": datetime.fromtimestamp(stat_info.st_mtime).isoformat(),
                "type": os.path.splitext(path)[1].lower().lstrip('.')
            }
    except Exception:
        pass
    return {"size": 0, "date": None, "type": ""}


def find_duplicate_groups(embeddings: np.ndarray, image_paths: List[str], threshold: float) -> List[dict]:
    """Find groups of duplicate images based on embedding similarity using Union-Find."""
    n = len(embeddings)
    if n == 0:
        return []

    start_time = time.time()
    uf = UnionFind(n)

    for i in range(0, n, LARGE_BATCH_SIZE):
        end_i = min(i + LARGE_BATCH_SIZE, n)
        batch_embeddings = embeddings[i:end_i]
        remaining_embeddings = embeddings[i:]
        similarities = batch_embeddings @ remaining_embeddings.T

        for bi, row in enumerate(similarities):
            global_i = i + bi
            for rj, sim in enumerate(row):
                global_j = i + rj
                if global_j > global_i and sim >= threshold:
                    uf.union(global_i, global_j)

    groups_dict = {}
    for idx in range(n):
        root = uf.find(idx)
        if root not in groups_dict:
            groups_dict[root] = []
        groups_dict[root].append(idx)

    duplicate_groups = []
    group_id = 1

    for root, indices in groups_dict.items():
        if len(indices) < 2:
            continue

        images = []
        for idx in indices:
            path = image_paths[idx]
            metadata = get_file_metadata(path)
            images.append({
                "path": path,
                "size": metadata["size"],
                "date": metadata["date"],
                "type": metadata["type"],
                "index": idx
            })

        images.sort(key=lambda x: x["size"], reverse=True)

        ref_index = images[0]["index"]
        ref_embedding = embeddings[ref_index]
        for img in images:
            if img["index"] == ref_index:
                img["similarity"] = 1.0
            else:
                img["similarity"] = float(embeddings[img["index"]] @ ref_embedding)
            del img["index"]

        duplicate_groups.append({"id": group_id, "images": images})
        group_id += 1

    elapsed = time.time() - start_time
    logger.info(f"Found {len(duplicate_groups)} duplicate groups in {elapsed:.2f}s")
    return duplicate_groups


@router.post("/duplicates")
def find_duplicates(request: DuplicatesRequest):
    """Find duplicate images based on embedding similarity."""
    try:
        logger.info(f"Finding duplicates with threshold {request.threshold}")

        data = load_image_index(request.data_dir)
        if data is None:
            return {"groups": [], "total_duplicates": 0, "total_groups": 0}

        embeddings = data['embeddings']
        image_paths = data['image_paths']

        valid_indices = [i for i, p in enumerate(image_paths) if is_user_image(p)]
        if len(valid_indices) < len(image_paths):
            embeddings = embeddings[valid_indices]
            image_paths = [image_paths[i] for i in valid_indices]

        groups = find_duplicate_groups(embeddings, image_paths, request.threshold)
        total_duplicates = sum(len(g["images"]) - 1 for g in groups)

        return {
            "groups": groups,
            "total_duplicates": total_duplicates,
            "total_groups": len(groups)
        }
    except Exception as e:
        logger.error(f"Error finding duplicates: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search")
def search(request: SearchRequest):
    """Perform a hybrid search combining semantic similarity and OCR text matching."""
    try:
        from server import get_searcher
        logger.info(f"Received search request: {request}")
        searcher = get_searcher()
        results = searcher.search(request.query, request.data_dir, request.top_k, request.ocr_weight)

        if results and "results" in results:
            filtered_results = []
            for result in results["results"]:
                if not is_user_image(result["path"]):
                    continue
                metadata = get_file_metadata(result["path"])
                result["size"] = metadata["size"]
                result["date"] = metadata["date"]
                result["type"] = metadata["type"]
                filtered_results.append(result)
            results["results"] = filtered_results

        return results
    except Exception as e:
        logger.error(f"Error during search: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/text-search")
def text_search(request: TextSearchRequest):
    """Search images by OCR text only (no semantic search)."""
    try:
        logger.info(f"Received text search request: {request.query}")
        start_time = time.time()

        data = load_image_index(request.data_dir)
        if data is None:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0}}

        image_paths = data['image_paths']
        ocr_texts = data.get('ocr_texts', [''] * len(image_paths))

        query_lower = request.query.lower()
        results = []

        for i, (path, ocr_text) in enumerate(zip(image_paths, ocr_texts)):
            if not ocr_text:
                continue

            ocr_lower = ocr_text.lower()
            if query_lower in ocr_lower:
                score = 1.0
            else:
                query_words = set(query_lower.split())
                ocr_words = set(ocr_lower.split())
                matches = len(query_words & ocr_words)
                if matches > 0:
                    score = matches / len(query_words)
                else:
                    continue

            if is_user_image(path):
                metadata = get_file_metadata(path)
                results.append({
                    "path": path,
                    "similarity": score,
                    "ocr_text": ocr_text[:OCR_TEXT_PREVIEW_LENGTH],
                    "size": metadata["size"],
                    "date": metadata["date"],
                    "type": metadata["type"]
                })

        results.sort(key=lambda x: x["similarity"], reverse=True)
        results = results[:request.top_k]

        total_time = time.time() - start_time
        ocr_count = sum(1 for t in ocr_texts if t.strip())

        return {
            "results": results,
            "stats": {
                "total_time": f"{total_time:.2f}s",
                "images_searched": len(image_paths),
                "images_with_ocr": ocr_count,
                "matches_found": len(results)
            }
        }
    except Exception as e:
        logger.error(f"Error during text search: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/similar")
def find_similar_images(request: SimilarRequest):
    """Find images similar to a given image using CLIP embeddings."""
    try:
        from server import get_searcher
        logger.info(f"Finding images similar to: {request.image_path}")
        searcher = get_searcher()
        results = searcher.find_similar(request.image_path, request.data_dir, request.top_k)

        if "error" in results:
            raise HTTPException(status_code=400, detail=results["error"])

        if "results" in results:
            filtered_results = []
            for result in results["results"]:
                if not is_user_image(result["path"]):
                    continue
                metadata = get_file_metadata(result["path"])
                result["size"] = metadata["size"]
                result["date"] = metadata["date"]
                result["type"] = metadata["type"]
                filtered_results.append(result)
            results["results"] = filtered_results

        return results
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error finding similar images: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
