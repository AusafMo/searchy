import os
import re
import argparse
import logging
import pickle
import time
from datetime import datetime
from typing import Optional, List
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from similarity_search import CLIPSearcher
from generate_embeddings import index_images_with_clip
from clip_model import model_manager, AVAILABLE_MODELS
import uvicorn
import numpy as np
from threading import Thread


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


app = FastAPI()

# Enable CORS for local clients only (security: restrict to localhost)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:*",
        "http://127.0.0.1:*",
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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


# ============== Model Configuration Endpoints ==============

@app.get("/model")
def get_current_model():
    """Get information about the currently loaded model."""
    return model_manager.get_model_info()


@app.get("/models")
def list_models():
    """List all available/recommended CLIP models."""
    return {
        "models": AVAILABLE_MODELS,
        "current": model_manager.current_model
    }


class ModelChangeRequest(BaseModel):
    model_name: str


@app.post("/model")
def change_model(request: ModelChangeRequest):
    """
    Change the CLIP model.
    Note: This will clear the GPU memory and load a new model.
    If the new model has different embedding dimensions, you'll need to re-index.
    """
    old_model = model_manager.current_model
    old_dim = model_manager.embedding_dim

    success = model_manager.load_model(request.model_name, force_reload=True)

    if not success:
        return {
            "status": "error",
            "message": f"Failed to load model: {request.model_name}"
        }

    new_dim = model_manager.embedding_dim

    return {
        "status": "success",
        "old_model": old_model,
        "new_model": model_manager.current_model,
        "old_embedding_dim": old_dim,
        "new_embedding_dim": new_dim,
        "reindex_required": old_dim != new_dim
    }


@app.post("/model/unload")
def unload_model():
    """Unload the current model to free GPU memory."""
    model_manager.unload_model()
    return {"status": "unloaded"}


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

@app.get("/indexed-paths")
def get_indexed_paths(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """
    Get all indexed image paths for face scanning.
    """
    try:
        filename = os.path.join(data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"paths": []}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'image_paths' not in data:
            return {"paths": []}

        # Filter to only existing user images
        valid_paths = [p for p in data['image_paths'] if is_user_image(p)]
        return {"paths": valid_paths}
    except Exception as e:
        logger.error(f"Error getting indexed paths: {e}")
        return {"paths": []}


# ============== Startup Sync Endpoints ==============

# Image extensions supported
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.heic'}

def matches_filter(filename: str, filter_type: str, filter_value: str) -> bool:
    """Check if filename matches the filter criteria."""
    if not filter_value or filter_type == "all":
        return True

    filename_lower = filename.lower()
    filter_lower = filter_value.lower()

    if filter_type == "starts-with":
        return filename_lower.startswith(filter_lower)
    elif filter_type == "ends-with":
        return filename_lower.endswith(filter_lower)
    elif filter_type == "contains":
        return filter_lower in filename_lower
    elif filter_type == "regex":
        try:
            return bool(re.search(filter_value, filename, re.IGNORECASE))
        except re.error:
            return False
    return True


class WatchedDirectoryRequest(BaseModel):
    path: str
    filter_type: str = "all"
    filter_value: str = ""


class SyncRequest(BaseModel):
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"
    directories: List[WatchedDirectoryRequest]
    fast_indexing: bool = True
    max_dimension: int = 384
    batch_size: int = 64


class IndexFilesRequest(BaseModel):
    """Request to index specific files (used by image watcher)."""
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"
    files: List[str]
    fast_indexing: bool = True
    max_dimension: int = 384
    batch_size: int = 64


# Track indexing status
indexing_status = {
    "is_indexing": False,
    "total_files": 0,
    "processed": 0,
    "error": None
}


@app.post("/index")
def index_files(request: IndexFilesRequest):
    """
    Index specific image files.
    Used by the image watcher to index new files through the server
    (avoiding loading a separate model instance).
    """
    global indexing_status

    if indexing_status["is_indexing"]:
        return {"status": "already_indexing", "message": "Indexing already in progress"}

    # Filter to only existing files
    valid_files = [f for f in request.files if os.path.exists(f)]

    if not valid_files:
        return {"status": "no_files", "message": "No valid files to index"}

    def run_indexing():
        global indexing_status
        indexing_status["is_indexing"] = True
        indexing_status["total_files"] = len(valid_files)
        indexing_status["processed"] = 0
        indexing_status["error"] = None

        try:
            logger.info(f"Indexing {len(valid_files)} files via /index endpoint...")
            index_images_with_clip(
                request.data_dir,
                incremental=True,
                new_files=valid_files,
                fast_indexing=request.fast_indexing,
                max_dimension=request.max_dimension,
                batch_size=request.batch_size
            )
            indexing_status["processed"] = len(valid_files)
            logger.info(f"Indexing complete: {len(valid_files)} files")
        except Exception as e:
            indexing_status["error"] = str(e)
            logger.error(f"Indexing error: {e}")
        finally:
            indexing_status["is_indexing"] = False

    thread = Thread(target=run_indexing, daemon=True)
    thread.start()

    return {
        "status": "started",
        "files_to_index": len(valid_files)
    }


@app.get("/index-status")
def get_indexing_status():
    """Get current indexing status."""
    return indexing_status


def cleanup_deleted_images(data_dir: str) -> dict:
    """
    Remove deleted images from the index.
    Returns stats about what was cleaned up.
    """
    filename = os.path.join(data_dir, 'image_index.bin')

    if not os.path.exists(filename):
        return {"removed": 0, "remaining": 0, "status": "no_index"}

    try:
        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'image_paths' not in data:
            return {"removed": 0, "remaining": 0, "status": "invalid_index"}

        embeddings = data['embeddings']
        image_paths = data['image_paths']
        ocr_texts = data.get('ocr_texts', [''] * len(image_paths))

        # Find indices of images that still exist
        valid_indices = []
        removed_count = 0
        for i, path in enumerate(image_paths):
            if os.path.exists(path):
                valid_indices.append(i)
            else:
                removed_count += 1
                logger.info(f"🗑️ Removing deleted image from index: {path}")

        if removed_count == 0:
            return {"removed": 0, "remaining": len(image_paths), "status": "no_changes"}

        # Filter to only valid entries
        new_embeddings = embeddings[valid_indices]
        new_paths = [image_paths[i] for i in valid_indices]
        new_ocr_texts = [ocr_texts[i] for i in valid_indices] if ocr_texts else []

        # Save cleaned index
        cleaned_data = {
            'embeddings': new_embeddings,
            'image_paths': new_paths,
            'ocr_texts': new_ocr_texts
        }

        with open(filename, 'wb') as f:
            pickle.dump(cleaned_data, f)

        logger.info(f"✅ Cleanup complete: removed {removed_count} deleted images, {len(new_paths)} remaining")
        return {"removed": removed_count, "remaining": len(new_paths), "status": "cleaned"}

    except Exception as e:
        logger.error(f"Error during cleanup: {e}")
        return {"removed": 0, "remaining": 0, "status": "error", "error": str(e)}


@app.post("/cleanup")
def cleanup_index(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """
    Remove deleted images from the index.
    Call this to free up space and improve search performance.
    """
    result = cleanup_deleted_images(data_dir)
    return result


# Track sync status
sync_status = {
    "is_syncing": False,
    "total_new": 0,
    "processed": 0,
    "current_directory": "",
    "error": None,
    "cleaned_up": 0
}


@app.post("/sync")
def sync_directories(request: SyncRequest):
    """
    Scan watched directories for new images and index them.
    Called on app startup to catch images added while app was closed.
    Also cleans up deleted images from the index.
    """
    global sync_status

    if sync_status["is_syncing"]:
        return {"status": "already_syncing", "message": "Sync already in progress"}

    try:
        # Step 1: Clean up deleted images first
        logger.info("🧹 Cleaning up deleted images...")
        cleanup_result = cleanup_deleted_images(request.data_dir)
        cleaned_count = cleanup_result.get("removed", 0)
        if cleaned_count > 0:
            logger.info(f"🗑️ Removed {cleaned_count} deleted images from index")

        # Step 2: Load existing indexed paths (after cleanup)
        filename = os.path.join(request.data_dir, 'image_index.bin')
        existing_paths = set()
        if os.path.exists(filename):
            with open(filename, 'rb') as f:
                data = pickle.load(f)
            existing_paths = set(data.get('image_paths', []))

        # Scan all directories for new images
        new_files = []
        for directory in request.directories:
            if not os.path.isdir(directory.path):
                logger.warning(f"Directory not found: {directory.path}")
                continue

            for root, dirs, files in os.walk(directory.path):
                # Skip hidden and system directories
                dirs[:] = [d for d in dirs if not d.startswith('.') and d not in SKIP_DIRS]

                for file in files:
                    if file.startswith('.'):
                        continue

                    ext = os.path.splitext(file)[1].lower()
                    if ext not in IMAGE_EXTENSIONS:
                        continue

                    # Apply filter
                    if not matches_filter(file, directory.filter_type, directory.filter_value):
                        continue

                    full_path = os.path.join(root, file)
                    if full_path not in existing_paths and is_user_image(full_path):
                        new_files.append(full_path)

        if not new_files:
            return {
                "status": "no_new_images",
                "message": "All images already indexed",
                "scanned_directories": len(request.directories),
                "new_images": 0,
                "cleaned_up": cleaned_count
            }

        # Start indexing in background
        def run_sync():
            global sync_status
            sync_status["is_syncing"] = True
            sync_status["total_new"] = len(new_files)
            sync_status["processed"] = 0
            sync_status["error"] = None

            try:
                logger.info(f"🔄 Startup sync: indexing {len(new_files)} new images...")
                index_images_with_clip(
                    request.data_dir,
                    incremental=True,
                    new_files=new_files,
                    fast_indexing=request.fast_indexing,
                    max_dimension=request.max_dimension,
                    batch_size=request.batch_size
                )
                sync_status["processed"] = len(new_files)
                logger.info(f"✅ Startup sync complete: indexed {len(new_files)} images")
            except Exception as e:
                sync_status["error"] = str(e)
                logger.error(f"❌ Startup sync error: {e}")
            finally:
                sync_status["is_syncing"] = False

        thread = Thread(target=run_sync, daemon=True)
        thread.start()

        return {
            "status": "started",
            "message": f"Syncing {len(new_files)} new images",
            "scanned_directories": len(request.directories),
            "new_images": len(new_files),
            "cleaned_up": cleaned_count
        }

    except Exception as e:
        logger.error(f"Error starting sync: {e}")
        return {"status": "error", "message": str(e)}


@app.get("/sync-status")
def get_sync_status():
    """Get current sync status."""
    return sync_status


# ============== Face Recognition Endpoints ==============

from face_recognition_service import get_face_service

class FaceScanRequest(BaseModel):
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"
    incremental: bool = True  # Only scan new images
    limit: int = 0  # 0 = no limit, otherwise scan only this many images


@app.post("/face-scan")
def start_face_scan(request: FaceScanRequest):
    """
    Start face scanning on indexed images.
    Runs in background and returns immediately.
    """
    try:
        face_service = get_face_service(request.data_dir)

        if face_service.is_scanning:
            return {"status": "already_scanning", "message": "Face scan already in progress"}

        # Get indexed image paths
        filename = os.path.join(request.data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"status": "error", "message": "No images indexed yet"}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        image_paths = [p for p in data.get('image_paths', []) if is_user_image(p)]

        if not image_paths:
            return {"status": "error", "message": "No images to scan"}

        # Start scanning in background thread
        def run_scan():
            face_service.scan_images(image_paths, incremental=request.incremental, limit=request.limit)

        thread = Thread(target=run_scan, daemon=True)
        thread.start()

        new_count = face_service.get_new_images_count(image_paths) if request.incremental else len(image_paths)
        scan_count = min(new_count, request.limit) if request.limit > 0 else new_count

        return {
            "status": "started",
            "total_images": len(image_paths),
            "new_images": new_count,
            "will_scan": scan_count
        }
    except Exception as e:
        logger.error(f"Error starting face scan: {e}")
        return {"status": "error", "message": str(e)}


@app.get("/face-scan-status")
def get_face_scan_status(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """Get current face scan status."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.get_scan_status()
    except Exception as e:
        logger.error(f"Error getting face scan status: {e}")
        return {"error": str(e)}


@app.get("/face-clusters")
def get_face_clusters(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """Get all face clusters (people)."""
    try:
        face_service = get_face_service(data_dir)
        clusters = face_service.get_clusters()
        return {
            "clusters": clusters,
            "total_clusters": len(clusters),
            "total_faces": len(face_service.faces)
        }
    except Exception as e:
        logger.error(f"Error getting face clusters: {e}")
        return {"error": str(e)}


@app.post("/face-rename")
def rename_face_cluster(
    cluster_id: str,
    name: str,
    data_dir: str = "/Users/ausaf/Library/Application Support/searchy"
):
    """Rename a face cluster with a custom name."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.rename_cluster(cluster_id, name)
    except Exception as e:
        logger.error(f"Error renaming cluster: {e}")
        return {"error": str(e)}


@app.get("/face-new-count")
def get_new_face_count(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """Get count of images not yet scanned for faces."""
    try:
        face_service = get_face_service(data_dir)

        # Get indexed image paths
        filename = os.path.join(data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"new_count": 0, "total_indexed": 0}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        image_paths = [p for p in data.get('image_paths', []) if is_user_image(p)]
        new_count = face_service.get_new_images_count(image_paths)

        return {
            "new_count": new_count,
            "total_indexed": len(image_paths),
            "already_scanned": len(image_paths) - new_count
        }
    except Exception as e:
        logger.error(f"Error getting new face count: {e}")
        return {"error": str(e)}


@app.post("/face-clear")
def clear_face_data(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """Clear all face data."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.clear_all()
    except Exception as e:
        logger.error(f"Error clearing face data: {e}")
        return {"error": str(e)}


@app.post("/face-stop")
def stop_face_scan(data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """Stop the current face scan."""
    try:
        face_service = get_face_service(data_dir)
        face_service.stop_scan = True
        return {"status": "stopping"}
    except Exception as e:
        logger.error(f"Error stopping face scan: {e}")
        return {"error": str(e)}


@app.post("/face-recluster")
def recluster_faces(data_dir: str = "/Users/ausaf/Library/Application Support/searchy", threshold: float = 0.55):
    """Re-cluster faces with a new threshold without rescanning."""
    try:
        face_service = get_face_service(data_dir)
        clusters = face_service.cluster_faces(similarity_threshold=threshold)
        return {
            "status": "success",
            "threshold": threshold,
            "total_clusters": len(clusters),
            "total_faces": len(face_service.faces)
        }
    except Exception as e:
        logger.error(f"Error re-clustering faces: {e}")
        return {"error": str(e)}


if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on")
    args = parser.parse_args()

    
    port = args.port
    logger.info(f"Starting server on port {port}")

    
    # Bind to localhost only - prevents network exposure (security)
    uvicorn.run(app, host="127.0.0.1", port=port)
