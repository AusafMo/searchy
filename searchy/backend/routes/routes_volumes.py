"""Volume management routes: /volume/*."""

import os
import logging
import pickle
from typing import List
from threading import Thread
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from constants import DEFAULT_TOP_K, DEFAULT_OCR_WEIGHT, SKIP_DIRS, IMAGE_EXTENSIONS
from utils import matches_filter, is_user_image
from routes_search import get_file_metadata

router = APIRouter()
logger = logging.getLogger(__name__)


class VolumeIndexRequest(BaseModel):
    """Request to index a specific volume."""
    volume_path: str
    index_path: str
    fast_indexing: bool = True
    max_dimension: int = 384
    batch_size: int = 64
    filter_type: str = "all"
    filter_value: str = ""


class MultiVolumeSearchRequest(BaseModel):
    """Search across multiple volume indexes."""
    query: str
    top_k: int = DEFAULT_TOP_K
    index_paths: List[str]
    ocr_weight: float = DEFAULT_OCR_WEIGHT


@router.post("/volume/index")
def index_volume(request: VolumeIndexRequest):
    """Index images on a specific volume."""
    from server import indexing_status

    if indexing_status["is_indexing"]:
        return {"error": "Indexing already in progress", "status": "busy"}

    try:
        if not os.path.exists(request.volume_path):
            return {"error": f"Volume path not found: {request.volume_path}", "status": "error"}

        index_dir = os.path.dirname(request.index_path)
        if index_dir:
            os.makedirs(index_dir, exist_ok=True)

        images = []
        for root, dirs, files in os.walk(request.volume_path):
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in SKIP_DIRS]

            for f in files:
                if not f.startswith('.') and os.path.splitext(f)[1].lower() in IMAGE_EXTENSIONS:
                    if matches_filter(f, request.filter_type, request.filter_value):
                        images.append(os.path.join(root, f))

        if not images:
            return {"status": "complete", "images_indexed": 0, "message": "No images found"}

        indexing_status["is_indexing"] = True
        indexing_status["total_files"] = len(images)
        indexing_status["processed"] = 0
        indexing_status["error"] = None

        def do_index():
            try:
                from generate_embeddings import index_images_with_clip

                index_images_with_clip(
                    images,
                    request.index_path,
                    batch_size=request.batch_size,
                    fast_mode=request.fast_indexing,
                    max_dim=request.max_dimension
                )

                indexing_status["is_indexing"] = False
                indexing_status["processed"] = len(images)
            except Exception as e:
                indexing_status["is_indexing"] = False
                indexing_status["error"] = str(e)
                logger.error(f"Volume indexing error: {e}")

        thread = Thread(target=do_index)
        thread.start()

        return {
            "status": "started",
            "total_images": len(images),
            "volume_path": request.volume_path,
            "index_path": request.index_path
        }
    except Exception as e:
        logger.error(f"Error starting volume index: {e}")
        return {"error": str(e), "status": "error"}


@router.post("/volume/search")
def search_volumes(request: MultiVolumeSearchRequest):
    """Search across multiple volume indexes."""
    try:
        from server import get_searcher
        all_results = []
        searcher = get_searcher()

        for index_path in request.index_paths:
            if not os.path.exists(index_path):
                logger.warning(f"Index not found: {index_path}")
                continue

            index_dir = os.path.dirname(index_path)
            results = searcher.search(request.query, index_dir, request.top_k, request.ocr_weight)

            if results and "results" in results:
                for result in results["results"]:
                    if is_user_image(result["path"]):
                        result["index_path"] = index_path
                        metadata = get_file_metadata(result["path"])
                        result.update(metadata)
                        all_results.append(result)

        all_results.sort(key=lambda x: x.get("similarity", 0), reverse=True)
        all_results = all_results[:request.top_k]

        return {"results": all_results}
    except Exception as e:
        logger.error(f"Error searching volumes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/volume/stats")
def get_volume_stats(index_path: str):
    """Get statistics for a specific volume index."""
    try:
        if not os.path.exists(index_path):
            return {"exists": False, "count": 0, "size_bytes": 0}

        with open(index_path, 'rb') as f:
            data = pickle.load(f)

        count = len(data.get('image_paths', []))
        size_bytes = os.path.getsize(index_path)

        return {
            "exists": True,
            "count": count,
            "size_bytes": size_bytes,
            "has_ocr": 'ocr_texts' in data
        }
    except Exception as e:
        logger.error(f"Error getting volume stats: {e}")
        return {"exists": False, "count": 0, "size_bytes": 0, "error": str(e)}


@router.delete("/volume/index")
def delete_volume_index(index_path: str):
    """Delete a volume's index file."""
    try:
        if os.path.exists(index_path):
            os.remove(index_path)
            thumbnails_path = os.path.join(os.path.dirname(index_path), 'thumbnails')
            if os.path.exists(thumbnails_path):
                import shutil
                shutil.rmtree(thumbnails_path, ignore_errors=True)
            return {"status": "deleted", "index_path": index_path}
        return {"status": "not_found", "index_path": index_path}
    except Exception as e:
        logger.error(f"Error deleting volume index: {e}")
        return {"error": str(e), "status": "error"}
