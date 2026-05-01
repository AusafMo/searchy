"""
Centralized Vision-Language Model Manager

Supports multiple model families:
- OpenAI CLIP (CLIPModel / CLIPProcessor)
- Google SigLIP 2 (Siglip2Model / Siglip2Processor)  — better retrieval quality
- Meta PE-Core (via open_clip)                         — SOTA retrieval

Provides a singleton model manager that handles:
- Loading models from HuggingFace
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
    model_manager.load_model("google/siglip2-base-patch16-224")
"""

import os
import sys
import json
import time
import torch
import numpy as np
import threading
from typing import Optional, List
from PIL import Image


def _extract_features(output):
    """Extract tensor from model output, handling both transformers 4.x (tensor) and 5.x (BaseModelOutputWithPooling)."""
    if isinstance(output, torch.Tensor):
        return output
    # transformers 5.x returns BaseModelOutputWithPooling
    return output.pooler_output


# ── Model family detection ───────────────────────────────

def _detect_model_family(model_name: str) -> str:
    """Detect which model family a HuggingFace model ID belongs to."""
    name_lower = model_name.lower()
    if "siglip2" in name_lower:
        return "siglip2"
    if "siglip" in name_lower:
        return "siglip"
    if "pe-core" in name_lower or "perception" in name_lower:
        return "pe-core"
    # Default to CLIP (works for openai/clip-*, laion/CLIP-*, etc.)
    return "clip"


# Lazy imports to avoid loading transformers until needed
_model_classes = {}


def _ensure_transformers(family: str = "clip"):
    """Lazy load the right model/processor classes for a model family."""
    global _model_classes
    if family in _model_classes:
        return _model_classes[family]

    if family == "siglip2":
        from transformers import Siglip2Model, Siglip2Processor
        _model_classes[family] = (Siglip2Model, Siglip2Processor)
    elif family == "siglip":
        from transformers import SiglipModel, SiglipProcessor
        _model_classes[family] = (SiglipModel, SiglipProcessor)
    elif family == "pe-core":
        # PE-Core uses open_clip; fall back to CLIP if unavailable
        try:
            import open_clip
            _model_classes[family] = ("open_clip", open_clip)
        except ImportError:
            print("Warning: open_clip not installed, PE-Core unavailable. Install with: pip install open_clip_torch", file=sys.stderr)
            from transformers import CLIPModel, CLIPProcessor
            _model_classes[family] = (CLIPModel, CLIPProcessor)
    else:  # "clip"
        from transformers import CLIPModel, CLIPProcessor
        _model_classes[family] = (CLIPModel, CLIPProcessor)

    return _model_classes[family]


# Available models across all supported families
AVAILABLE_MODELS = {
    # ── SigLIP 2 (Google, 2025) — best quality/size ratio ──────
    "google/siglip2-base-patch16-224": {
        "name": "SigLIP 2 B/16",
        "family": "siglip2",
        "description": "Recommended — better retrieval than CLIP, same speed",
        "embedding_dim": 768,
        "size_mb": 850
    },
    "google/siglip2-large-patch16-256": {
        "name": "SigLIP 2 L/16",
        "family": "siglip2",
        "description": "High accuracy SigLIP 2, 256px input",
        "embedding_dim": 1024,
        "size_mb": 1800
    },
    "google/siglip2-so400m-patch14-384": {
        "name": "SigLIP 2 SO400M/14",
        "family": "siglip2",
        "description": "Largest SigLIP 2, 384px, best quality",
        "embedding_dim": 1152,
        "size_mb": 3600
    },
    # ── Meta PE-Core (2025) — SOTA retrieval ───────────────────
    "facebook/PE-Core-B16-224": {
        "name": "PE-Core B/16",
        "family": "pe-core",
        "description": "Meta SOTA — best zero-shot retrieval (requires open_clip)",
        "embedding_dim": 512,
        "size_mb": 600
    },
    "facebook/PE-Core-L14-336": {
        "name": "PE-Core L/14",
        "family": "pe-core",
        "description": "Meta SOTA large — highest retrieval accuracy (requires open_clip)",
        "embedding_dim": 768,
        "size_mb": 1700
    },
    # ── OpenAI CLIP (2021) — baseline ─────────────────────────
    "openai/clip-vit-base-patch32": {
        "name": "CLIP ViT-B/32",
        "family": "clip",
        "description": "Fast, good balance of speed and accuracy",
        "embedding_dim": 512,
        "size_mb": 605
    },
    "openai/clip-vit-base-patch16": {
        "name": "CLIP ViT-B/16",
        "family": "clip",
        "description": "More accurate than B/32, slower",
        "embedding_dim": 512,
        "size_mb": 605
    },
    "openai/clip-vit-large-patch14": {
        "name": "CLIP ViT-L/14",
        "family": "clip",
        "description": "High accuracy, requires more memory",
        "embedding_dim": 768,
        "size_mb": 1710
    },
    "openai/clip-vit-large-patch14-336": {
        "name": "CLIP ViT-L/14@336px",
        "family": "clip",
        "description": "Highest CLIP accuracy, processes 336px images",
        "embedding_dim": 768,
        "size_mb": 1710
    },
    # ── LAION OpenCLIP ────────────────────────────────────────
    "laion/CLIP-ViT-B-32-laion2B-s34B-b79K": {
        "name": "LAION CLIP ViT-B/32",
        "family": "clip",
        "description": "Trained on LAION-2B dataset, good general purpose",
        "embedding_dim": 512,
        "size_mb": 605
    },
    "laion/CLIP-ViT-H-14-laion2B-s32B-b79K": {
        "name": "LAION CLIP ViT-H/14",
        "family": "clip",
        "description": "Large model trained on LAION-2B, very accurate",
        "embedding_dim": 1024,
        "size_mb": 3940
    },
}

DEFAULT_MODEL = "google/siglip2-base-patch16-224"


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
        self._tokenizer = None  # For PE-Core (open_clip uses separate tokenizer)
        self._device = None
        self._current_model_name = None
        self._current_family = None  # "clip", "siglip", "siglip2", "pe-core"
        self._config_path = None
        self._model_lock = threading.Lock()  # Prevent concurrent model changes
        self._last_used_at = None  # Timestamp of last model usage
        self._ttl_minutes = 0  # 0 = never unload
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
                    self._preferred_model = config.get("model_name", DEFAULT_MODEL)
                    self._ttl_minutes = config.get("ttl_minutes", 0)
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
                    "model_name": self._current_model_name,
                    "ttl_minutes": self._ttl_minutes
                }, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save model config: {e}", file=sys.stderr)

    def get_device(self) -> torch.device:
        """Get the best available device (MPS > CUDA > CPU)."""
        if self._device is not None:
            return self._device

        if torch.backends.mps.is_available():
            self._device = torch.device("mps")
            print("🚀 Using Apple Silicon GPU (MPS)", file=sys.stderr)
        elif torch.cuda.is_available():
            self._device = torch.device("cuda")
            print("🚀 Using CUDA GPU", file=sys.stderr)
        else:
            self._device = torch.device("cpu")
            print("💻 Using CPU (no GPU acceleration)", file=sys.stderr)

        return self._device

    def load_model(self, model_name: Optional[str] = None, force_reload: bool = False) -> bool:
        """
        Load a vision-language model from HuggingFace.

        Supports CLIP, SigLIP 2, and PE-Core model families.
        The correct loader is auto-detected from the model name.

        Args:
            model_name: HuggingFace model identifier.
                       If None, loads the configured/default model.
            force_reload: If True, reload even if same model is already loaded.

        Returns:
            True if model was loaded successfully, False otherwise.
        """
        if model_name is None:
            model_name = getattr(self, '_preferred_model', DEFAULT_MODEL)

        family = _detect_model_family(model_name)

        # Skip if same model already loaded
        if not force_reload and self._model is not None and self._current_model_name == model_name:
            return True

        # Use lock to prevent concurrent model changes
        with self._model_lock:
            # Check again inside lock
            if not force_reload and self._model is not None and self._current_model_name == model_name:
                return True

            try:
                print(f"Loading model: {model_name} (family: {family})...", file=sys.stderr)

                # Unload existing model to free memory
                self._unload_internal()

                device = self.get_device()

                if family == "pe-core":
                    self._load_pe_core(model_name, device)
                else:
                    self._load_hf_model(model_name, family, device)

                self._current_model_name = model_name
                self._current_family = family
                self._save_config()

                model_info = AVAILABLE_MODELS.get(model_name, {})
                model_display = model_info.get("name", model_name)
                print(f"Loaded {model_display} on {device} (family: {family})", file=sys.stderr)
                return True

            except Exception as e:
                print(f"Error loading model {model_name}: {e}", file=sys.stderr)
                return False

    def _load_hf_model(self, model_name: str, family: str, device: torch.device):
        """Load a HuggingFace transformers model (CLIP, SigLIP, SigLIP 2)."""
        classes = _ensure_transformers(family)
        ModelClass, ProcessorClass = classes

        self._model = ModelClass.from_pretrained(model_name, token=False)
        self._processor = ProcessorClass.from_pretrained(model_name, token=False)
        self._model = self._model.to(device)
        self._model.eval()
        self._tokenizer = None  # Not used for HF models

    def _load_pe_core(self, model_name: str, device: torch.device):
        """Load a Meta PE-Core model via open_clip."""
        classes = _ensure_transformers("pe-core")
        if classes[0] == "open_clip":
            open_clip = classes[1]
            # PE-Core models use open_clip's create_model_from_pretrained
            model, preprocess = open_clip.create_model_from_pretrained(
                f"hf-hub:{model_name}"
            )
            tokenizer = open_clip.get_tokenizer(f"hf-hub:{model_name}")
            self._model = model.to(device)
            self._model.eval()
            self._processor = preprocess
            self._tokenizer = tokenizer
        else:
            # Fallback to CLIP-style loading if open_clip unavailable
            self._load_hf_model(model_name, "clip", device)

    def _unload_internal(self):
        """Free model memory without acquiring the lock (caller must hold lock)."""
        if self._model is not None:
            del self._model
            del self._processor
            if self._tokenizer is not None:
                del self._tokenizer
            self._model = None
            self._processor = None
            self._tokenizer = None
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            print("Model unloaded", file=sys.stderr)

    def unload_model(self):
        """Unload the current model to free memory."""
        with self._model_lock:
            if self._model is not None:
                self._unload_internal()
                self._current_model_name = None
                self._current_family = None

                # Clear GPU cache
                if torch.backends.mps.is_available():
                    torch.mps.empty_cache()
                print("Model unloaded -- GPU/RAM freed, disk cache retained", file=sys.stderr)

    def _touch(self):
        """Update last-used timestamp."""
        self._last_used_at = time.time()

    @property
    def ttl_minutes(self) -> int:
        return self._ttl_minutes

    @ttl_minutes.setter
    def ttl_minutes(self, value: int):
        self._ttl_minutes = value
        self._save_config()

    @property
    def last_used_at(self) -> Optional[float]:
        return self._last_used_at

    def check_ttl(self) -> bool:
        """Check if model should be unloaded due to TTL expiry.
        Returns True if model was unloaded.
        Negative ttl_minutes values are treated as seconds (for testing)."""
        if self._ttl_minutes == 0 or self._model is None or self._last_used_at is None:
            return False
        idle_seconds = time.time() - self._last_used_at
        if self._ttl_minutes < 0:
            ttl_seconds = abs(self._ttl_minutes)
        else:
            ttl_seconds = self._ttl_minutes * 60
        if idle_seconds >= ttl_seconds:
            print(f"Model idle for {idle_seconds:.0f}s (TTL: {ttl_seconds}s), unloading...", file=sys.stderr)
            self.unload_model()
            return True
        return False

    def ensure_loaded(self):
        """Ensure a model is loaded, loading the default if necessary."""
        self._touch()
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
        """Generate normalized embedding for text query."""
        self.ensure_loaded()

        try:
            if self._current_family == "pe-core" and self._tokenizer is not None:
                return self._get_text_embedding_open_clip(text)
            return self._get_text_embedding_hf(text)
        except Exception as e:
            print(f"Error generating text embedding: {e}", file=sys.stderr)
            return None

    def _get_text_embedding_hf(self, text: str) -> np.ndarray:
        """Text embedding via HuggingFace transformers (CLIP, SigLIP, SigLIP 2)."""
        inputs = self._processor(text=text, return_tensors="pt", padding=True, truncation=True)
        inputs = {k: v.to(self._device) for k, v in inputs.items()}

        with torch.no_grad():
            text_features = _extract_features(self._model.get_text_features(**inputs))
            text_features = text_features / text_features.norm(dim=-1, keepdim=True)

        return text_features.cpu().numpy().flatten()

    def _get_text_embedding_open_clip(self, text: str) -> np.ndarray:
        """Text embedding via open_clip (PE-Core)."""
        tokens = self._tokenizer(text).to(self._device)

        with torch.no_grad():
            text_features = self._model.encode_text(tokens)
            text_features = text_features / text_features.norm(dim=-1, keepdim=True)

        return text_features.cpu().numpy().flatten()

    def get_image_embedding(self, image: Image.Image) -> Optional[np.ndarray]:
        """Generate normalized embedding for a single image."""
        self.ensure_loaded()

        try:
            if self._current_family == "pe-core" and self._tokenizer is not None:
                return self._get_image_embedding_open_clip(image)
            return self._get_image_embedding_hf(image)
        except Exception as e:
            print(f"Error generating image embedding: {e}", file=sys.stderr)
            return None

    def _get_image_embedding_hf(self, image: Image.Image) -> np.ndarray:
        """Image embedding via HuggingFace transformers."""
        inputs = self._processor(images=image, return_tensors="pt")
        inputs = {k: v.to(self._device) for k, v in inputs.items()}

        with torch.no_grad():
            image_features = _extract_features(self._model.get_image_features(**inputs))
            image_features = image_features / image_features.norm(dim=-1, keepdim=True)

        return image_features.cpu().numpy().flatten()

    def _get_image_embedding_open_clip(self, image: Image.Image) -> np.ndarray:
        """Image embedding via open_clip (PE-Core)."""
        # self._processor is the preprocess transform for open_clip
        image_tensor = self._processor(image).unsqueeze(0).to(self._device)

        with torch.no_grad():
            image_features = self._model.encode_image(image_tensor)
            image_features = image_features / image_features.norm(dim=-1, keepdim=True)

        return image_features.cpu().numpy().flatten()

    def get_image_embeddings_batch(self, images: List[Image.Image], batch_size: int = 32) -> List[np.ndarray]:
        """Generate embeddings for multiple images in batches."""
        self.ensure_loaded()

        all_embeddings = []

        for i in range(0, len(images), batch_size):
            batch = images[i:i + batch_size]

            try:
                if self._current_family == "pe-core" and self._tokenizer is not None:
                    batch_embeddings = self._get_image_batch_open_clip(batch)
                else:
                    batch_embeddings = self._get_image_batch_hf(batch)
                all_embeddings.extend(batch_embeddings)

            except Exception as e:
                print(f"Error processing batch {i//batch_size}: {e}", file=sys.stderr)
                all_embeddings.extend([None] * len(batch))

        return all_embeddings

    def _get_image_batch_hf(self, images: List[Image.Image]) -> List[np.ndarray]:
        """Batch image embeddings via HuggingFace transformers."""
        inputs = self._processor(images=images, return_tensors="pt", padding=True)
        inputs = {k: v.to(self._device) for k, v in inputs.items()}

        with torch.no_grad():
            image_features = _extract_features(self._model.get_image_features(**inputs))
            image_features = image_features / image_features.norm(dim=-1, keepdim=True)

        return list(image_features.cpu().numpy())

    def _get_image_batch_open_clip(self, images: List[Image.Image]) -> List[np.ndarray]:
        """Batch image embeddings via open_clip (PE-Core)."""
        tensors = torch.stack([self._processor(img) for img in images]).to(self._device)

        with torch.no_grad():
            image_features = self._model.encode_image(tensors)
            image_features = image_features / image_features.norm(dim=-1, keepdim=True)

        return list(image_features.cpu().numpy())

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
