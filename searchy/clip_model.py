"""
Centralized CLIP Model Manager

Provides a singleton model manager that handles:
- Loading CLIP models from HuggingFace
- GPU/MPS/CPU device management
- Text and image embedding generation
- Model switching at runtime
- Configuration persistence

Usage:
    from clip_model import model_manager

    # Get embeddings
    text_emb = model_manager.get_text_embedding("a photo of a cat")
    image_emb = model_manager.get_image_embedding(pil_image)

    # Switch models
    model_manager.load_model("openai/clip-vit-large-patch14")
"""

import os
import sys
import json
import torch
import numpy as np
import threading
from typing import Optional, List, Tuple
from PIL import Image

# Lazy imports to avoid loading transformers until needed
_CLIPModel = None
_CLIPProcessor = None


def _ensure_transformers():
    """Lazy load transformers to speed up import time."""
    global _CLIPModel, _CLIPProcessor
    if _CLIPModel is None:
        from transformers import CLIPModel, CLIPProcessor
        _CLIPModel = CLIPModel
        _CLIPProcessor = CLIPProcessor


# Common CLIP models available on HuggingFace
AVAILABLE_MODELS = {
    "openai/clip-vit-base-patch32": {
        "name": "CLIP ViT-B/32",
        "description": "Fast, good balance of speed and accuracy",
        "embedding_dim": 512,
        "size_mb": 605
    },
    "openai/clip-vit-base-patch16": {
        "name": "CLIP ViT-B/16",
        "description": "More accurate than B/32, slower",
        "embedding_dim": 512,
        "size_mb": 605
    },
    "openai/clip-vit-large-patch14": {
        "name": "CLIP ViT-L/14",
        "description": "High accuracy, requires more memory",
        "embedding_dim": 768,
        "size_mb": 1710
    },
    "openai/clip-vit-large-patch14-336": {
        "name": "CLIP ViT-L/14@336px",
        "description": "Highest accuracy, processes 336px images",
        "embedding_dim": 768,
        "size_mb": 1710
    },
    "laion/CLIP-ViT-B-32-laion2B-s34B-b79K": {
        "name": "LAION CLIP ViT-B/32",
        "description": "Trained on LAION-2B dataset, good general purpose",
        "embedding_dim": 512,
        "size_mb": 605
    },
    "laion/CLIP-ViT-H-14-laion2B-s32B-b79K": {
        "name": "LAION CLIP ViT-H/14",
        "description": "Large model trained on LAION-2B, very accurate",
        "embedding_dim": 1024,
        "size_mb": 3940
    }
}

DEFAULT_MODEL = "openai/clip-vit-base-patch32"


class ModelManager:
    """
    Singleton manager for CLIP model loading and inference.

    Handles device selection, model loading, and embedding generation
    with a single shared model instance across the application.
    """

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        self._model = None
        self._processor = None
        self._device = None
        self._current_model_name = None
        self._config_path = None
        self._model_lock = threading.Lock()  # Prevent concurrent model changes
        self._initialized = True

    def set_config_path(self, path: str):
        """Set the path for configuration persistence."""
        self._config_path = path
        self._load_config()

    def _load_config(self):
        """Load model configuration from file."""
        if not self._config_path:
            return

        config_file = os.path.join(self._config_path, "model_config.json")
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    config = json.load(f)
                    # Don't load the model yet, just store the preference
                    self._preferred_model = config.get("model_name", DEFAULT_MODEL)
            except Exception as e:
                print(f"Warning: Could not load model config: {e}", file=sys.stderr)
                self._preferred_model = DEFAULT_MODEL
        else:
            self._preferred_model = DEFAULT_MODEL

    def _save_config(self):
        """Save model configuration to file."""
        if not self._config_path:
            return

        config_file = os.path.join(self._config_path, "model_config.json")
        try:
            os.makedirs(self._config_path, exist_ok=True)
            with open(config_file, 'w') as f:
                json.dump({
                    "model_name": self._current_model_name
                }, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save model config: {e}", file=sys.stderr)

    def get_device(self) -> torch.device:
        """Get the best available device (MPS > CUDA > CPU)."""
        if self._device is not None:
            return self._device

        if torch.backends.mps.is_available():
            self._device = torch.device("mps")
            print(f"🚀 Using Apple Silicon GPU (MPS)", file=sys.stderr)
        elif torch.cuda.is_available():
            self._device = torch.device("cuda")
            print(f"🚀 Using CUDA GPU", file=sys.stderr)
        else:
            self._device = torch.device("cpu")
            print(f"💻 Using CPU (no GPU acceleration)", file=sys.stderr)

        return self._device

    def load_model(self, model_name: Optional[str] = None, force_reload: bool = False) -> bool:
        """
        Load a CLIP model from HuggingFace.

        Args:
            model_name: HuggingFace model identifier (e.g., "openai/clip-vit-base-patch32")
                       If None, loads the configured/default model.
            force_reload: If True, reload even if same model is already loaded.

        Returns:
            True if model was loaded successfully, False otherwise.
        """
        _ensure_transformers()

        if model_name is None:
            model_name = getattr(self, '_preferred_model', DEFAULT_MODEL)

        # Skip if same model already loaded
        if not force_reload and self._model is not None and self._current_model_name == model_name:
            return True

        # Use lock to prevent concurrent model changes
        with self._model_lock:
            # Check again inside lock
            if not force_reload and self._model is not None and self._current_model_name == model_name:
                return True

            try:
                print(f"Loading model: {model_name}...", file=sys.stderr)

                # Unload existing model to free memory
                if self._model is not None:
                    del self._model
                    del self._processor
                    self._model = None
                    self._processor = None
                    if torch.cuda.is_available():
                        torch.cuda.empty_cache()
                    print("Model unloaded", file=sys.stderr)

                # Load new model
                self._model = _CLIPModel.from_pretrained(model_name, token=False)
                self._processor = _CLIPProcessor.from_pretrained(model_name, token=False)

                # Move to best device
                device = self.get_device()
                self._model = self._model.to(device)
                self._model.eval()  # Set to evaluation mode

                self._current_model_name = model_name
                self._save_config()

                # Get model info
                model_info = AVAILABLE_MODELS.get(model_name, {})
                model_display = model_info.get("name", model_name)

                print(f"✅ Loaded {model_display} on {device}", file=sys.stderr)
                return True

            except Exception as e:
                print(f"❌ Error loading model {model_name}: {e}", file=sys.stderr)
                return False

    def unload_model(self):
        """Unload the current model to free memory."""
        if self._model is not None:
            del self._model
            del self._processor
            self._model = None
            self._processor = None
            self._current_model_name = None

            # Clear GPU cache
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            print("Model unloaded", file=sys.stderr)

    def ensure_loaded(self):
        """Ensure a model is loaded, loading the default if necessary."""
        if self._model is None:
            self.load_model()

    @property
    def is_loaded(self) -> bool:
        """Check if a model is currently loaded."""
        return self._model is not None

    @property
    def current_model(self) -> Optional[str]:
        """Get the name of the currently loaded model."""
        return self._current_model_name

    @property
    def embedding_dim(self) -> int:
        """Get the embedding dimension of the current model."""
        if self._current_model_name in AVAILABLE_MODELS:
            return AVAILABLE_MODELS[self._current_model_name]["embedding_dim"]
        return 512  # Default fallback

    def get_text_embedding(self, text: str) -> Optional[np.ndarray]:
        """
        Generate embedding for text query.

        Args:
            text: The text to embed.

        Returns:
            Normalized embedding as numpy array, or None on error.
        """
        self.ensure_loaded()

        try:
            inputs = self._processor(text=text, return_tensors="pt", padding=True, truncation=True)
            inputs = {k: v.to(self._device) for k, v in inputs.items()}

            with torch.no_grad():
                text_features = self._model.get_text_features(**inputs)
                # Normalize
                text_features = text_features / text_features.norm(dim=-1, keepdim=True)

            return text_features.cpu().numpy().flatten()

        except Exception as e:
            print(f"Error generating text embedding: {e}", file=sys.stderr)
            return None

    def get_image_embedding(self, image: Image.Image) -> Optional[np.ndarray]:
        """
        Generate embedding for a single image.

        Args:
            image: PIL Image to embed.

        Returns:
            Normalized embedding as numpy array, or None on error.
        """
        self.ensure_loaded()

        try:
            inputs = self._processor(images=image, return_tensors="pt")
            inputs = {k: v.to(self._device) for k, v in inputs.items()}

            with torch.no_grad():
                image_features = self._model.get_image_features(**inputs)
                # Normalize
                image_features = image_features / image_features.norm(dim=-1, keepdim=True)

            return image_features.cpu().numpy().flatten()

        except Exception as e:
            print(f"Error generating image embedding: {e}", file=sys.stderr)
            return None

    def get_image_embeddings_batch(self, images: List[Image.Image], batch_size: int = 32) -> List[np.ndarray]:
        """
        Generate embeddings for multiple images in batches.

        Args:
            images: List of PIL Images to embed.
            batch_size: Number of images to process at once.

        Returns:
            List of normalized embeddings as numpy arrays.
        """
        self.ensure_loaded()

        all_embeddings = []

        for i in range(0, len(images), batch_size):
            batch = images[i:i + batch_size]

            try:
                inputs = self._processor(images=batch, return_tensors="pt", padding=True)
                inputs = {k: v.to(self._device) for k, v in inputs.items()}

                with torch.no_grad():
                    image_features = self._model.get_image_features(**inputs)
                    # Normalize
                    image_features = image_features / image_features.norm(dim=-1, keepdim=True)

                batch_embeddings = image_features.cpu().numpy()
                all_embeddings.extend(batch_embeddings)

            except Exception as e:
                print(f"Error processing batch {i//batch_size}: {e}", file=sys.stderr)
                # Add None for failed images
                all_embeddings.extend([None] * len(batch))

        return all_embeddings

    def get_model_info(self) -> dict:
        """Get information about the currently loaded model."""
        if not self.is_loaded:
            return {"status": "not_loaded"}

        info = {
            "model_name": self._current_model_name,
            "device": str(self._device),
            "embedding_dim": self.embedding_dim
        }

        if self._current_model_name in AVAILABLE_MODELS:
            info.update(AVAILABLE_MODELS[self._current_model_name])

        return info

    @staticmethod
    def list_available_models() -> dict:
        """Get list of known/recommended models."""
        return AVAILABLE_MODELS.copy()


# Global singleton instance
model_manager = ModelManager()


# Convenience functions for backward compatibility
def get_model_and_processor():
    """Legacy function - returns (model, processor) tuple."""
    model_manager.ensure_loaded()
    return model_manager._model, model_manager._processor


def get_device():
    """Legacy function - returns the current device."""
    return model_manager.get_device()


def generate_image_embedding(image):
    """Legacy function - generates image embedding."""
    return model_manager.get_image_embedding(image)


def generate_text_embedding(text):
    """Legacy function - generates text embedding."""
    return model_manager.get_text_embedding(text)
