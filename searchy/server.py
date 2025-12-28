import os
import argparse
import logging
import pickle
import time
from datetime import datetime
from typing import Optional, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from similarity_search import CLIPSearcher
import uvicorn
import numpy as np


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


app = FastAPI()

# Directories to skip (system, packages, caches, etc.)
SKIP_DIRS = {
    'site-packages', 'node_modules', 'vendor', '__pycache__',
    'env', 'venv', '.venv', 'virtualenv',
    'Library', 'Caches', 'cache', '.cache',
    'build', 'dist', 'target', '.git', '.svn',
    'DerivedData', 'xcuserdata', 'Pods',
    '__MACOSX', '.Trash', '.Spotlight-V100', '.fseventsd'
}

def is_user_image(path: str) -> bool:
    """Check if path is a user image (not system/package file)."""
    if not os.path.exists(path):
        return False
    if os.path.basename(path).startswith('.'):
        return False
    parts = path.split(os.sep)
    return not any(part in SKIP_DIRS for part in parts)

# Lazy initialization of searcher
_searcher = None

def get_searcher():
    global _searcher
    if _searcher is None:
        _searcher = CLIPSearcher()
    return _searcher


class SearchRequest(BaseModel):
    query: str
    top_k: int
    data_dir: str
    ocr_weight: float = 0.3  # Weight for OCR text matching (0-1)


class DuplicatesRequest(BaseModel):
    threshold: float = 0.95
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"


def get_file_metadata(path: str) -> dict:
    """Get file metadata (size, date) for a given path."""
    try:
        if os.path.exists(path):
            stat_info = os.stat(path)
            return {
                "size": stat_info.st_size,
                "date": datetime.fromtimestamp(stat_info.st_mtime).isoformat(),
                "type": os.path.splitext(path)[1].lower().lstrip('.')
            }
    except:
        pass
    return {"size": 0, "date": None, "type": ""}


def find_duplicate_groups(embeddings: np.ndarray, image_paths: List[str], threshold: float) -> List[dict]:
    """
    Find groups of duplicate images based on embedding similarity.
    Uses Union-Find to cluster similar images.
    """
    n = len(embeddings)
    if n == 0:
        return []

    # Compute pairwise similarity matrix (cosine similarity for normalized embeddings)
    # For large datasets, process in batches to avoid memory issues
    start_time = time.time()

    # Union-Find data structure
    parent = list(range(n))

    def find(x):
        if parent[x] != x:
            parent[x] = find(parent[x])
        return parent[x]

    def union(x, y):
        px, py = find(x), find(y)
        if px != py:
            parent[px] = py

    # Find similar pairs (process in batches for memory efficiency)
    batch_size = 500  # Process 500 images at a time
    for i in range(0, n, batch_size):
        end_i = min(i + batch_size, n)
        # Compare this batch against all images from i onwards
        batch_embeddings = embeddings[i:end_i]
        remaining_embeddings = embeddings[i:]

        # Compute similarities: (batch_size x remaining_size)
        similarities = batch_embeddings @ remaining_embeddings.T

        # Find pairs above threshold
        for bi, row in enumerate(similarities):
            global_i = i + bi
            for rj, sim in enumerate(row):
                global_j = i + rj
                if global_j > global_i and sim >= threshold:
                    union(global_i, global_j)

    # Group images by their root parent
    groups_dict = {}
    for idx in range(n):
        root = find(idx)
        if root not in groups_dict:
            groups_dict[root] = []
        groups_dict[root].append(idx)

    # Filter to only groups with 2+ images (actual duplicates)
    duplicate_groups = []
    group_id = 1

    for root, indices in groups_dict.items():
        if len(indices) < 2:
            continue

        # Get metadata for each image in the group
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

        # Sort by size descending (largest first = best quality)
        images.sort(key=lambda x: x["size"], reverse=True)

        # Calculate similarity to the first (reference) image
        ref_index = images[0]["index"]
        ref_embedding = embeddings[ref_index]
        for img in images:
            if img["index"] == ref_index:
                img["similarity"] = 1.0
            else:
                img["similarity"] = float(embeddings[img["index"]] @ ref_embedding)
            del img["index"]  # Remove internal index from response

        duplicate_groups.append({
            "id": group_id,
            "images": images
        })
        group_id += 1

    elapsed = time.time() - start_time
    logger.info(f"Found {len(duplicate_groups)} duplicate groups in {elapsed:.2f}s")

    return duplicate_groups


@app.post("/duplicates")
def find_duplicates(request: DuplicatesRequest):
    """
    Find duplicate images based on embedding similarity.
    Returns groups of similar images with metadata.
    """
    try:
        logger.info(f"Finding duplicates with threshold {request.threshold}")

        filename = os.path.join(request.data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"groups": [], "total_duplicates": 0, "total_groups": 0}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'embeddings' not in data or 'image_paths' not in data:
            return {"groups": [], "total_duplicates": 0, "total_groups": 0}

        embeddings = data['embeddings']
        image_paths = data['image_paths']

        # Filter to only existing, non-hidden, non-system files
        valid_indices = [i for i, p in enumerate(image_paths) if is_user_image(p)]
        if len(valid_indices) < len(image_paths):
            embeddings = embeddings[valid_indices]
            image_paths = [image_paths[i] for i in valid_indices]

        groups = find_duplicate_groups(embeddings, image_paths, request.threshold)

        total_duplicates = sum(len(g["images"]) - 1 for g in groups)  # Exclude one "original" per group

        return {
            "groups": groups,
            "total_duplicates": total_duplicates,
            "total_groups": len(groups)
        }
    except Exception as e:
        logger.error(f"Error finding duplicates: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/search")
def search(request: SearchRequest):
    """
    Perform a hybrid search combining semantic similarity and OCR text matching.
    """
    try:
        logger.info(f"Received search request: {request}")
        searcher = get_searcher()
        results = searcher.search(request.query, request.data_dir, request.top_k, request.ocr_weight)

        # Filter and enrich results with file metadata
        if results and "results" in results:
            filtered_results = []
            for result in results["results"]:
                # Skip system/package files
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


class TextSearchRequest(BaseModel):
    query: str
    top_k: int = 20
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"


class SimilarRequest(BaseModel):
    image_path: str
    top_k: int = 20
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"


@app.post("/text-search")
def text_search(request: TextSearchRequest):
    """
    Search images by OCR text only (no semantic search).
    Useful for finding images with specific text content.
    """
    try:
        logger.info(f"Received text search request: {request.query}")
        start_time = time.time()

        filename = os.path.join(request.data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0}}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'image_paths' not in data:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0}}

        image_paths = data['image_paths']
        ocr_texts = data.get('ocr_texts', [''] * len(image_paths))

        # Find images with matching OCR text
        query_lower = request.query.lower()
        results = []

        for i, (path, ocr_text) in enumerate(zip(image_paths, ocr_texts)):
            if not ocr_text:
                continue

            ocr_lower = ocr_text.lower()
            if query_lower in ocr_lower:
                # Exact match - highest priority
                score = 1.0
            else:
                # Word-level matching
                query_words = set(query_lower.split())
                ocr_words = set(ocr_lower.split())
                matches = len(query_words & ocr_words)
                if matches > 0:
                    score = matches / len(query_words)
                else:
                    continue  # No match

            if is_user_image(path):
                metadata = get_file_metadata(path)
                results.append({
                    "path": path,
                    "similarity": score,
                    "ocr_text": ocr_text[:300],  # Include found text
                    "size": metadata["size"],
                    "date": metadata["date"],
                    "type": metadata["type"]
                })

        # Sort by score descending
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


@app.post("/similar")
def find_similar_images(request: SimilarRequest):
    """
    Find images similar to a given image using CLIP embeddings.
    """
    try:
        logger.info(f"Finding images similar to: {request.image_path}")
        searcher = get_searcher()
        results = searcher.find_similar(request.image_path, request.data_dir, request.top_k)

        if "error" in results:
            raise HTTPException(status_code=400, detail=results["error"])

        # Filter and enrich results with file metadata
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


@app.get("/status")
def get_status():
    return {"status": "Server is running"}

@app.get("/recent")
def get_recent(top_k: int = 8, data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """
    Get recent indexed images sorted by modification date (newest first).
    """
    try:
        filename = os.path.join(data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'image_paths' not in data:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        image_paths = data['image_paths']

        if len(image_paths) == 0:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        # Get creation/added times for all indexed images (filter system files)
        images_with_time = []
        for path in image_paths:
            if is_user_image(path):
                try:
                    # Use birthtime (actual creation time on macOS) or fallback to ctime
                    stat_info = os.stat(path)
                    # On macOS, st_birthtime is the actual creation time
                    creation_time = getattr(stat_info, 'st_birthtime', stat_info.st_ctime)
                    images_with_time.append((path, creation_time))
                except:
                    continue

        # Sort by creation time (newest first)
        images_with_time.sort(key=lambda x: x[1], reverse=True)

        # Take top_k newest
        recent_images = images_with_time[:top_k]

        # Create results with dummy similarity scores
        results = [{"path": path, "similarity": 1.0} for path, _ in recent_images]

        return {
            "results": results,
            "stats": {
                "total_time": "0.00s",
                "images_searched": len(image_paths),
                "images_per_second": "0"
            }
        }
    except Exception as e:
        logger.error(f"Error fetching recent images: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/index-count")
def get_index_count(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """
    Get total count of indexed images.
    """
    try:
        filename = os.path.join(data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"count": 0}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'image_paths' not in data:
            return {"count": 0}

        return {"count": len(data['image_paths'])}
    except Exception as e:
        logger.error(f"Error getting index count: {e}")
        return {"count": 0}

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on")
    args = parser.parse_args()

    
    port = args.port
    logger.info(f"Starting server on port {port}")

    
    uvicorn.run(app, host="0.0.0.0", port=port)
