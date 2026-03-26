"""Indexing & sync routes: /index, /index-status, /notify-new-image, /cleanup, /sync, /sync-status."""

import os
import logging
import pickle
import time
from typing import Optional, List
from threading import Thread
from fastapi import APIRouter
from pydantic import BaseModel

from constants import DEFAULT_DATA_DIR, SKIP_DIRS, IMAGE_EXTENSIONS
from generate_embeddings import index_images_with_clip
from atomic_write import atomic_pickle_dump
from utils import matches_filter, is_user_image, load_image_index

router = APIRouter()
logger = logging.getLogger(__name__)


class WatchedDirectoryRequest(BaseModel):
    path: str
    filter_type: str = "all"
    filter_value: str = ""


class SyncRequest(BaseModel):
    data_dir: str = DEFAULT_DATA_DIR
    directories: List[WatchedDirectoryRequest]
    fast_indexing: bool = True
    max_dimension: int = 384
    batch_size: int = 64


class IndexFilesRequest(BaseModel):
    """Request to index specific files (used by image watcher)."""
    data_dir: str = DEFAULT_DATA_DIR
    files: List[str]
    fast_indexing: bool = True
    max_dimension: int = 384
    batch_size: int = 64


class NotifyNewImageRequest(BaseModel):
    file_path: str
    detection_time: Optional[float] = None


@router.post("/notify-new-image")
def notify_new_image(request: NotifyNewImageRequest):
    """Notify that a new image was detected (before indexing)."""
    from server import pending_images

    file_path = request.file_path

    if not os.path.exists(file_path):
        return {"status": "error", "message": "File does not exist"}

    if not is_user_image(file_path):
        return {"status": "skipped", "message": "Not a user image"}

    detection_time = request.detection_time or time.time()
    pending_images[file_path] = detection_time

    logger.info(f"New image detected (pending): {os.path.basename(file_path)}")
    return {"status": "ok", "pending_count": len(pending_images)}


@router.post("/index")
def index_files(request: IndexFilesRequest):
    """Index specific image files."""
    from server import indexing_status, pending_images

    if indexing_status["is_indexing"]:
        return {"status": "already_indexing", "message": "Indexing already in progress"}

    valid_files = [f for f in request.files if os.path.exists(f)]

    if not valid_files:
        return {"status": "no_files", "message": "No valid files to index"}

    def remove_from_pending(file_paths):
        for path in file_paths:
            pending_images.pop(path, None)

    def run_indexing():
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
            remove_from_pending(valid_files)
        except Exception as e:
            indexing_status["error"] = str(e)
            logger.error(f"Indexing error: {e}")
            remove_from_pending(valid_files)
        finally:
            indexing_status["is_indexing"] = False

    thread = Thread(target=run_indexing, daemon=True)
    thread.start()

    return {"status": "started", "files_to_index": len(valid_files)}


@router.get("/index-status")
def get_indexing_status():
    """Get current indexing status."""
    from server import indexing_status
    return indexing_status


def cleanup_deleted_images(data_dir: str) -> dict:
    """Remove deleted images from the index."""
    data = load_image_index(data_dir)

    if data is None:
        return {"removed": 0, "remaining": 0, "status": "no_index"}

    try:
        embeddings = data['embeddings']
        image_paths = data['image_paths']
        ocr_texts = data.get('ocr_texts', [''] * len(image_paths))

        valid_indices = []
        removed_count = 0
        for i, path in enumerate(image_paths):
            if os.path.exists(path):
                valid_indices.append(i)
            else:
                removed_count += 1
                logger.info(f"Removing deleted image from index: {path}")

        if removed_count == 0:
            return {"removed": 0, "remaining": len(image_paths), "status": "no_changes"}

        new_embeddings = embeddings[valid_indices]
        new_paths = [image_paths[i] for i in valid_indices]
        new_ocr_texts = [ocr_texts[i] for i in valid_indices] if ocr_texts else []

        cleaned_data = {
            'embeddings': new_embeddings,
            'image_paths': new_paths,
            'ocr_texts': new_ocr_texts
        }

        atomic_pickle_dump(cleaned_data, os.path.join(data_dir, 'image_index.bin'))

        logger.info(f"Cleanup complete: removed {removed_count} deleted images, {len(new_paths)} remaining")
        return {"removed": removed_count, "remaining": len(new_paths), "status": "cleaned"}

    except Exception as e:
        logger.error(f"Error during cleanup: {e}")
        return {"removed": 0, "remaining": 0, "status": "error", "error": str(e)}


@router.post("/cleanup")
def cleanup_index(data_dir: str = DEFAULT_DATA_DIR):
    """Remove deleted images from the index."""
    return cleanup_deleted_images(data_dir)


@router.post("/sync")
def sync_directories(request: SyncRequest):
    """Scan watched directories for new images and index them."""
    from server import sync_status

    if sync_status["is_syncing"]:
        return {"status": "already_syncing", "message": "Sync already in progress"}

    try:
        logger.info("Cleaning up deleted images...")
        cleanup_result = cleanup_deleted_images(request.data_dir)
        cleaned_count = cleanup_result.get("removed", 0)
        if cleaned_count > 0:
            logger.info(f"Removed {cleaned_count} deleted images from index")

        filename = os.path.join(request.data_dir, 'image_index.bin')
        existing_paths = set()
        if os.path.exists(filename):
            with open(filename, 'rb') as f:
                data = pickle.load(f)
            existing_paths = set(data.get('image_paths', []))

        new_files = []
        for directory in request.directories:
            if not os.path.isdir(directory.path):
                logger.warning(f"Directory not found: {directory.path}")
                continue

            for root, dirs, files in os.walk(directory.path):
                dirs[:] = [d for d in dirs if not d.startswith('.') and d not in SKIP_DIRS]

                for file in files:
                    if file.startswith('.'):
                        continue

                    ext = os.path.splitext(file)[1].lower()
                    if ext not in IMAGE_EXTENSIONS:
                        continue

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

        def run_sync():
            sync_status["is_syncing"] = True
            sync_status["total_new"] = len(new_files)
            sync_status["processed"] = 0
            sync_status["error"] = None

            try:
                logger.info(f"Startup sync: indexing {len(new_files)} new images...")
                index_images_with_clip(
                    request.data_dir,
                    incremental=True,
                    new_files=new_files,
                    fast_indexing=request.fast_indexing,
                    max_dimension=request.max_dimension,
                    batch_size=request.batch_size
                )
                sync_status["processed"] = len(new_files)
                logger.info(f"Startup sync complete: indexed {len(new_files)} images")
            except Exception as e:
                sync_status["error"] = str(e)
                logger.error(f"Startup sync error: {e}")
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


@router.get("/sync-status")
def get_sync_status():
    """Get current sync status."""
    from server import sync_status
    return sync_status
