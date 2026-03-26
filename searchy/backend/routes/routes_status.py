"""Status routes: /status, /recent, /index-count, /indexed-paths."""

import os
import logging
import time
from fastapi import APIRouter, HTTPException

from clip_model import model_manager
from constants import DEFAULT_DATA_DIR
from utils import is_user_image, load_image_index

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/status")
def get_status():
    from server import _model_loading_status
    if model_manager.is_loaded and _model_loading_status["state"] in ("unloaded", "pending"):
        _model_loading_status["state"] = "ready"
        _model_loading_status["message"] = "Model reloaded"

    elapsed = 0
    if _model_loading_status["started_at"] and _model_loading_status["state"] == "loading":
        elapsed = time.time() - _model_loading_status["started_at"]
    else:
        elapsed = _model_loading_status["elapsed_seconds"]
    idle_seconds = 0
    if model_manager.last_used_at and model_manager.is_loaded:
        idle_seconds = round(time.time() - model_manager.last_used_at, 1)
    return {
        "status": "Server is running",
        "model": {
            "state": _model_loading_status["state"],
            "message": _model_loading_status["message"],
            "elapsed_seconds": round(elapsed, 1),
            "ttl_minutes": model_manager.ttl_minutes,
            "idle_seconds": idle_seconds
        }
    }


@router.get("/recent")
def get_recent(top_k: int = 8, data_dir: str = DEFAULT_DATA_DIR):
    """Get recent images sorted by modification date (newest first)."""
    from server import pending_images

    try:
        all_images = []

        indexed_paths = set()
        data = load_image_index(data_dir)
        if data is not None:
            for path in data['image_paths']:
                if is_user_image(path):
                    try:
                        stat_info = os.stat(path)
                        creation_time = getattr(stat_info, 'st_birthtime', stat_info.st_ctime)
                        all_images.append((path, creation_time, False))
                        indexed_paths.add(path)
                    except Exception:
                        continue

        for path, detection_time in list(pending_images.items()):
            if path in indexed_paths:
                continue
            if os.path.exists(path) and is_user_image(path):
                all_images.append((path, detection_time, True))

        if not all_images:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        all_images.sort(key=lambda x: x[1], reverse=True)
        recent_images = all_images[:top_k]

        results = [
            {"path": path, "similarity": 1.0, "is_pending": is_pending}
            for path, _, is_pending in recent_images
        ]

        return {
            "results": results,
            "stats": {
                "total_time": "0.00s",
                "images_searched": len(indexed_paths),
                "pending_count": len(pending_images),
                "images_per_second": "0"
            }
        }
    except Exception as e:
        logger.error(f"Error fetching recent images: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/index-count")
def get_index_count(data_dir: str = DEFAULT_DATA_DIR):
    """Get total count of indexed images."""
    try:
        data = load_image_index(data_dir)
        if data is None:
            return {"count": 0}
        return {"count": len(data['image_paths'])}
    except Exception as e:
        logger.error(f"Error getting index count: {e}")
        return {"count": 0}


@router.get("/indexed-paths")
def get_indexed_paths(data_dir: str = DEFAULT_DATA_DIR):
    """Get all indexed image paths for face scanning."""
    try:
        data = load_image_index(data_dir)
        if data is None:
            return {"paths": []}
        valid_paths = [p for p in data['image_paths'] if is_user_image(p)]
        return {"paths": valid_paths}
    except Exception as e:
        logger.error(f"Error getting indexed paths: {e}")
        return {"paths": []}
