"""Searchy FastAPI server — app setup, shared state, and router registration."""

import os
import argparse
import logging
import logging.handlers
import time
from contextlib import asynccontextmanager
from threading import Thread

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from similarity_search import CLIPSearcher
from clip_model import model_manager
from constants import DEFAULT_DATA_DIR, TTL_CHECK_INTERVAL
import uvicorn


# ── Logging ──────────────────────────────────────────────

log_dir = os.path.join(DEFAULT_DATA_DIR, "logs")
os.makedirs(log_dir, exist_ok=True)

log_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")

console_handler = logging.StreamHandler()
console_handler.setFormatter(log_formatter)

file_handler = logging.handlers.RotatingFileHandler(
    os.path.join(log_dir, "server.log"),
    maxBytes=5 * 1024 * 1024,
    backupCount=3,
)
file_handler.setFormatter(log_formatter)

logging.basicConfig(level=logging.INFO, handlers=[console_handler, file_handler])
logger = logging.getLogger(__name__)


# ── Shared state (imported by route modules) ─────────────

_searcher = None


def get_searcher():
    global _searcher
    if _searcher is None:
        _searcher = CLIPSearcher()
    return _searcher


_model_loading_status = {
    "state": "pending",
    "message": "",
    "started_at": None,
    "elapsed_seconds": 0
}

indexing_status = {
    "is_indexing": False,
    "total_files": 0,
    "processed": 0,
    "error": None
}

pending_images = {}  # file path -> detection timestamp

sync_status = {
    "is_syncing": False,
    "total_new": 0,
    "processed": 0,
    "current_directory": "",
    "error": None,
    "cleaned_up": 0
}


# ── Background threads ───────────────────────────────────

def _load_model_background():
    """Load CLIP model in background thread after server starts."""
    global _model_loading_status
    _model_loading_status["state"] = "loading"
    _model_loading_status["message"] = "Loading CLIP model..."
    _model_loading_status["started_at"] = time.time()
    try:
        model_manager.set_config_path(DEFAULT_DATA_DIR)
        model_manager.ensure_loaded()
        elapsed = time.time() - _model_loading_status["started_at"]
        _model_loading_status["state"] = "ready"
        _model_loading_status["message"] = f"Model loaded in {elapsed:.1f}s"
        _model_loading_status["elapsed_seconds"] = elapsed
        logger.info(f"CLIP model loaded in {elapsed:.1f}s")
    except Exception as e:
        elapsed = time.time() - _model_loading_status["started_at"]
        _model_loading_status["state"] = "error"
        _model_loading_status["message"] = str(e)
        _model_loading_status["elapsed_seconds"] = elapsed
        logger.error(f"Failed to load CLIP model: {e}")


def _ttl_checker():
    """Background thread that periodically checks if the model should be unloaded."""
    global _model_loading_status
    while True:
        time.sleep(TTL_CHECK_INTERVAL)
        if model_manager.check_ttl():
            _model_loading_status["state"] = "unloaded"
            _model_loading_status["message"] = f"Model unloaded after {model_manager.ttl_minutes}min idle"
            _model_loading_status["elapsed_seconds"] = 0


# ── App setup ────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app):
    Thread(target=_load_model_background, daemon=True).start()
    Thread(target=_ttl_checker, daemon=True).start()
    yield


app = FastAPI(lifespan=lifespan)

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


# ── Register routers ────────────────────────────────────

from routes_search import router as search_router
from routes_model import router as model_router
from routes_status import router as status_router
from routes_indexing import router as indexing_router
from routes_face import router as face_router
from routes_volumes import router as volumes_router

app.include_router(search_router)
app.include_router(model_router)
app.include_router(status_router)
app.include_router(indexing_router)
app.include_router(face_router)
app.include_router(volumes_router)


# ── Main ─────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on")
    args = parser.parse_args()

    port = args.port
    logger.info(f"Starting server on port {port}")

    # Bind to localhost only - prevents network exposure (security)
    uvicorn.run(app, host="127.0.0.1", port=port)
