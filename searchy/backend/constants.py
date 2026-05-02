"""Centralized constants for the Searchy project."""

import os

# ─── Paths ────────────────────────────────────────────────
DEFAULT_DATA_DIR = os.path.join(
    os.path.expanduser("~/Library/Application Support"), "searchy"
)

# ─── Image Formats ────────────────────────────────────────
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.heic'}

# ─── Directories to Skip During Indexing ──────────────────
SKIP_DIRS = {
    'site-packages', 'node_modules', 'vendor', '__pycache__',
    'env', 'venv', '.venv', 'virtualenv',
    'Library', 'Caches', 'cache', '.cache',
    'build', 'dist', 'target', '.git', '.svn',
    'DerivedData', 'xcuserdata', 'Pods',
    '__MACOSX', '.Trash', '.Spotlight-V100', '.fseventsd',
}

# ─── Indexing Defaults ────────────────────────────────────
DEFAULT_BATCH_SIZE = 64
DEFAULT_MAX_DIMENSION = 384
LARGE_BATCH_SIZE = 500  # For bulk operations (duplicates, face clustering)

# ─── Search Defaults ──────────────────────────────────────
DEFAULT_TOP_K = 20
DEFAULT_OCR_WEIGHT = 0.3
DEFAULT_SIMILARITY_THRESHOLD = 0.95  # For duplicate detection

# ─── Reciprocal Rank Fusion (Cormack et al., SIGIR 2009) ─
RRF_K = 60  # Smoothing constant; standard value from the original paper

# ─── BM25 Parameters (Robertson et al.) ─────────────────
BM25_K1 = 1.2   # Term-frequency saturation
BM25_B = 0.75   # Document-length normalization

# ─── Prompt Ensembling (Radford et al., 2021) ───────────
PROMPT_TEMPLATES = [
    "{}",
    "a photo of {}",
    "a picture of {}",
    "an image of {}",
]

# ─── Query Expansion ────────────────────────────────────
# Kept minimal — only synonyms that are genuinely interchangeable.
# Aggressive expansion (sunset→sunrise, car→sedan) dilutes multi-word queries.
VISUAL_DESCRIPTORS = {
    "cat": ["kitten", "feline"],
    "dog": ["puppy", "canine"],
    "person": ["human", "people"],
    "flower": ["blossom", "bloom"],
}

# ─── Model ────────────────────────────────────────────────
DEFAULT_EMBEDDING_DIM = 512  # CLIP ViT-B/32
DEFAULT_MODEL_NAME = "google/siglip2-base-patch16-224"

# ─── TTL ──────────────────────────────────────────────────
TTL_CHECK_INTERVAL = 30  # Seconds between TTL checks

# ─── OCR ──────────────────────────────────────────────────
OCR_TEXT_PREVIEW_LENGTH = 300

# ─── Image Watcher ────────────────────────────────────────
WATCHER_DEBOUNCE_DELAY = 0.5  # Seconds
WATCHER_NOTIFY_TIMEOUT = 5    # Seconds
WATCHER_INDEX_TIMEOUT = 30    # Seconds

# ─── Face Recognition ────────────────────────────────────
FACE_CLUSTER_THRESHOLD = 0.65        # Cosine similarity for clustering (OpenCV+ArcFace)
FACE_REASSIGN_THRESHOLD = 0.60       # Cosine similarity for re-assignment / best-match
FACE_CONFIDENCE_MIN = 0.9            # Minimum detection confidence
FACE_AREA_RATIO_MAX = 0.8            # Skip if face covers more than this fraction of image
FACE_MIN_SIZE = 40                   # Minimum face bbox dimension (px)
FACE_IMAGE_MAX_DIM = 1920            # Resize large images before detection
FACE_EMBEDDING_SIZE = 112            # ArcFace input size (px)
FACE_BRIGHTNESS_MIN = 30             # Skip dark faces below this mean brightness
FACE_BRIGHTNESS_STD_MIN = 20         # Skip low-contrast faces below this std
