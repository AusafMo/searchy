"""Model configuration routes: /model, /models, /model/unload, /model/ttl."""

import logging
import time
from fastapi import APIRouter
from pydantic import BaseModel

from clip_model import model_manager, AVAILABLE_MODELS

router = APIRouter()
logger = logging.getLogger(__name__)


class ModelChangeRequest(BaseModel):
    model_name: str


class TTLRequest(BaseModel):
    ttl_minutes: int  # 0 = never unload


@router.get("/model")
def get_current_model():
    """Get information about the currently loaded model."""
    return model_manager.get_model_info()


@router.get("/models")
def list_models():
    """List all available/recommended CLIP models."""
    return {
        "models": AVAILABLE_MODELS,
        "current": model_manager.current_model
    }


@router.post("/model")
def change_model(request: ModelChangeRequest):
    """Change the CLIP model."""
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


@router.post("/model/unload")
def unload_model():
    """Unload the current model to free GPU memory."""
    from server import _model_loading_status
    model_manager.unload_model()
    _model_loading_status["state"] = "unloaded"
    _model_loading_status["message"] = "Model manually unloaded"
    _model_loading_status["elapsed_seconds"] = 0
    return {"status": "unloaded"}


@router.get("/model/ttl")
def get_model_ttl():
    """Get current model TTL setting."""
    idle_seconds = 0
    if model_manager.last_used_at and model_manager.is_loaded:
        idle_seconds = round(time.time() - model_manager.last_used_at, 1)
    return {
        "ttl_minutes": model_manager.ttl_minutes,
        "idle_seconds": idle_seconds
    }


@router.post("/model/ttl")
def set_model_ttl(request: TTLRequest):
    """Set model TTL (minutes of idle before unloading). 0 = never."""
    model_manager.ttl_minutes = request.ttl_minutes
    return {"ttl_minutes": model_manager.ttl_minutes}
