<h1 align="center">Searchy</h1>

<p align="center">A hybrid image search tool for macOS that uses CLIP + OCR to find images through natural language queries and text content.</p>

<p align="center"><b>On-device processing</b> · <b>Spotlight-style interface</b> · <b>GPU accelerated</b> · <b>Face recognition</b></p>

<p align="center"><b>Main App</b></p>

https://storage.googleapis.com/ausaf-public/searchy-app.mp4

<p align="center"><b>Spotlight Widget</b></p>

https://storage.googleapis.com/ausaf-public/searchy-widget.mp4

---

<p align="center">Photo management on macOS sucks. Searchy indexes your images locally and lets you search them using descriptive phrases like <i>"sunset over mountains"</i>, <i>"person wearing red"</i>, or text visible in images like <i>"invoice 2024"</i>. Find photos by face, detect duplicates, and access it instantly from the menu bar with a global hotkey.</p>

---

## Installation

### Download (Recommended)

1. Download `Searchy.dmg` from [Releases](https://github.com/AusafMo/searchy/releases)
2. Drag to Applications
3. Right-click → Open (first time only, macOS security)
4. Click **Start Setup** — Python & CLIP models install automatically (3-5 min)

That's it. No manual Python installation required.

### Build from Source

```bash
git clone https://github.com/AusafMo/searchy.git
cd searchy
```

Open `searchy.xcodeproj` in Xcode and build (`⌘R`).

On first launch, Searchy will automatically:
- Install Python (if not found)
- Create an isolated virtual environment
- Download dependencies (~2GB)
- Download the CLIP model

---

## Keyboard Shortcuts

```
⌘⇧Space      Open Searchy
↑ ↓          Navigate results
Enter        Copy and paste selected image
⌘Enter       Reveal in Finder
⌘1-9         Copy and paste by position
Ctrl+1-9     Copy to clipboard only
Esc          Close window
```

---

## Settings

Access via the gear icon in the header.

**Display** — Grid columns (2-6), thumbnail size (100-400px), performance statistics toggle

**Search** — Maximum results (10/20/50/100), minimum similarity threshold (0-100%)

**Indexing** — Fast indexing mode, maximum image dimension (256-768px), batch size (32-256)

**Watched Directories** — Configure folders for automatic indexing with optional filename filters

---

<h2 align="center">Features</h2>

**Hybrid Search (Semantic + OCR)**
- Query images using natural language descriptions
- Automatically extracts and indexes text from images (signs, documents, screenshots)
- Hybrid mode combines visual understanding with text matching
- Adjustable OCR weight to tune semantic vs text relevance
- Pure text search mode for exact text matching
- Real-time results with 400ms debounce
- Similarity scores displayed as color-coded percentages
- Filter results by file type, date range, and size

**Duplicate Detection**
- Find visually similar images across your library
- Adjustable similarity threshold (85-99%)
- Auto-select smaller duplicates for cleanup
- Preview images before deleting
- Move or trash duplicates in bulk

**Face Recognition**
- Automatic face detection using DeepFace (SSD detector)
- Face clustering to group photos by person
- Name people and search by name
- Pin important faces, hide unwanted ones
- Merge duplicate person clusters
- Face verification to confirm matches
- Create custom face groups/albums
- Bulk operations for efficient management

**Similar Image Search**
- Find visually similar images to any selected photo
- Uses CLIP embeddings for semantic similarity
- Adjustable result count

**Spotlight-Style Interface**
- Global hotkey `⌘⇧Space` summons a floating search window
- Displays recent images on launch
- Fully keyboard-navigable
- Click images to preview full-size

**Auto-Indexing**
- Monitors configured directories automatically
- Supports custom directories with prefix, suffix, or regex filters
- Incremental indexing — only processes new files
- Search while indexing is in progress
- Cancel indexing anytime

**Smart Filtering**
- Automatically skips system directories (Library, node_modules, site-packages, etc.)
- Ignores hidden files and build artifacts
- Focuses only on your actual photos

**Zero-Config Setup**
- Automatic Python installation (via Homebrew or standalone)
- Isolated virtual environment in Application Support
- All dependencies installed on first launch

**External Volumes**
- Index images on external drives and USB devices
- Separate index per volume stored on the device
- Search across volumes independently
- Volume statistics and management

**Model Selection**
- Choose between multiple CLIP models
- Switch models without re-indexing
- Unload models to free memory
- Automatic model download on first use

**Privacy**
- All processing runs locally on your machine
- No network requests after initial setup
- GPU acceleration via Metal (Apple Silicon)
- See [Security & Privacy](#security--privacy) for our threat model and decisions

---

## Architecture

```
searchy/
├── ContentView.swift            # SwiftUI interface
├── searchyApp.swift             # App lifecycle, setup manager, server management
├── server.py                    # FastAPI backend
├── generate_embeddings.py       # CLIP model and embedding generation
├── face_recognition_service.py  # Face detection & clustering (DeepFace)
├── image_watcher.py             # File system monitor for auto-indexing
└── requirements.txt
```

**Stack:** SwiftUI + AppKit → FastAPI + Uvicorn → CLIP ViT-B/32 + DeepFace (ArcFace) → NumPy embeddings

---

## For Developers

### Data Storage

All data is stored in `~/Library/Application Support/searchy/`:

```
searchy/
├── venv/                  # Isolated Python environment
├── image_index.bin        # Embeddings + paths (pickle)
├── watched_directories.json
└── settings files...
```

### Embedding Format

The index file (`image_index.bin`) is a pickled Python dictionary:

```python
{
    'embeddings': np.ndarray,  # Shape: (num_images, 512) - normalized vectors
    'image_paths': list[str]   # Absolute paths to images
}
```

Load it in Python:
```python
import pickle
with open('image_index.bin', 'rb') as f:
    data = pickle.load(f)
    embeddings = data['embeddings']  # numpy array
    paths = data['image_paths']      # list of strings
```

### API Endpoints

The FastAPI server runs on `localhost:7860` (or next available port).

**Search images:**
```bash
curl -X POST http://localhost:7860/search \
  -H "Content-Type: application/json" \
  -d '{"query": "sunset over mountains", "n_results": 10}'
```

Response:
```json
{
  "results": [
    {"path": "/path/to/image.jpg", "similarity": 0.342},
    ...
  ]
}
```

**Get recent images:**
```bash
curl http://localhost:7860/recent?n=20
```

**Health check:**
```bash
curl http://localhost:7860/health
```

### Swapping CLIP Models

Edit `generate_embeddings.py` line 37:

```python
# Default: ViT-B/32 (512-dim embeddings, fastest)
model_name = "openai/clip-vit-base-patch32"

# Alternatives:
# "openai/clip-vit-base-patch16"   # 512-dim, more accurate
# "openai/clip-vit-large-patch14"  # 768-dim, most accurate, slower
```

> **Note:** Changing models requires re-indexing all images. Delete `image_index.bin` before switching.

### Custom Backend Implementation

Want to replace CLIP with your own model or rewrite the backend entirely? Just respect these contracts:

#### 1. Embedding Index File

The Swift app reads `~/Library/Application Support/searchy/image_index.bin`. Your indexer must produce a pickle file with this exact structure:

```python
import pickle
import numpy as np

data = {
    'embeddings': np.ndarray,  # Shape: (N, embedding_dim), float32, L2-normalized
    'image_paths': list[str]   # Length N, absolute paths
}

with open('image_index.bin', 'wb') as f:
    pickle.dump(data, f)
```

#### 2. Server API Contract

The app expects a FastAPI/HTTP server. Implement these endpoints:

| Endpoint | Method | Request | Response |
|----------|--------|---------|----------|
| `/health` | GET | — | `{"status": "ok"}` |
| `/search` | POST | `{"query": str, "n_results": int, "threshold": float, "ocr_weight": float}` | `{"results": [{"path": str, "similarity": float}, ...]}` |
| `/text-search` | POST | `{"query": str, "top_k": int}` | `{"results": [...]}` |
| `/recent` | GET | `?n=int` | `{"results": [{"path": str, "similarity": float}, ...]}` |
| `/index-count` | GET | — | `{"count": int}` |
| `/duplicates` | POST | `{"threshold": float, "data_dir": str}` | `{"groups": [...], "total_duplicates": int}` |
| `/similar` | POST | `{"image_path": str, "top_k": int}` | `{"results": [...]}` |
| `/face-scan` | POST | `{"data_dir": str}` | `{"status": "started"}` |
| `/face-clusters` | GET | — | `{"clusters": [...]}` |
| `/face-rename` | POST | `{"cluster_id": str, "name": str}` | `{"success": bool}` |
| `/face-merge` | POST | `{"source_id": str, "target_id": str}` | `{"success": bool}` |
| `/volume/index` | POST | `{"volume_path": str, "index_path": str}` | `{"status": str}` |
| `/volume/search` | POST | `{"query": str, "index_path": str}` | `{"results": [...]}` |

#### 3. Script Interface

The app calls your scripts via `Process()`. Replace these files in the app bundle's Resources:

**`generate_embeddings.py`** — Called for indexing:
```bash
python generate_embeddings.py /path/to/folder [options]

# Must accept:
--fast                    # Optional: fast mode flag
--max-dimension INT       # Optional: resize dimension
--batch-size INT          # Optional: batch size
--filter-type TYPE        # Optional: all|starts-with|ends-with|contains|regex
--filter VALUE            # Optional: filter value

# Must output to stdout (JSON, one per line):
{"type": "start", "total_images": N, "total_batches": N}
{"type": "progress", "batch": N, "total_batches": N, "images_processed": N, "total_images": N, "elapsed": float, "images_per_sec": float}
{"type": "complete", "total_images": N, "new_images": N, "total_time": float, "images_per_sec": float}
```

**`server.py`** — Called to start the API server:
```bash
python server.py --port PORT
# Must start HTTP server on given port
```

**`image_watcher.py`** — Called for auto-indexing:
```bash
python image_watcher.py
# Watches directories, triggers incremental indexing
```

#### 4. Example: Custom Backend

```python
# my_custom_indexer.py - Use any model you want
from sentence_transformers import SentenceTransformer
import pickle, numpy as np

model = SentenceTransformer('clip-ViT-L-14')  # Or any model

def index_images(paths):
    embeddings = model.encode([Image.open(p) for p in paths])
    embeddings = embeddings / np.linalg.norm(embeddings, axis=1, keepdims=True)

    with open('image_index.bin', 'wb') as f:
        pickle.dump({'embeddings': embeddings, 'image_paths': paths}, f)
```

As long as you output the right JSON progress messages and maintain the pickle format, the Swift UI will work with any backend.

---

### CLI Usage

Generate embeddings directly:
```bash
cd ~/Library/Application\ Support/searchy
source venv/bin/activate
python generate_embeddings.py /path/to/images --batch-size 64 --fast
```

Options:
- `--fast` / `--no-fast` — Resize images before processing
- `--max-dimension 384` — Max image size (256, 384, 512, 768)
- `--batch-size 64` — Images per batch (32, 64, 128, 256)
- `--filter-type starts-with` — Filter filenames
- `--filter "IMG_"` — Filter value

---

## Roadmap

- [x] Spotlight-style floating widget
- [x] Global hotkey (`⌘⇧Space`)
- [x] Theme toggle (System/Light/Dark)
- [x] Real-time search with debouncing
- [x] Auto-indexing with file watchers
- [x] Watched directories with filters
- [x] Configurable settings panel
- [x] Menu bar app (no Dock icon)
- [x] GPU acceleration (Metal)
- [x] Recent images display
- [x] Fast indexing with image resizing
- [x] Bundled .app distribution with auto-setup
- [x] Duplicate image detection
- [x] Date, size, and file type filters
- [x] Face recognition & clustering
- [x] Face naming, pinning, hiding, merging
- [x] Face groups/albums
- [x] Similar image search
- [x] External volume indexing
- [x] Model selection & management
- [x] OCR text extraction & hybrid search
- [ ] Alternative/smaller models

---

## Vision: A Proper Mac Photo Manager

macOS photo management is surprisingly lacking. Apple Photos is bloated and locks you into iCloud. Professional tools like Lightroom are subscription-based editors, not managers. There's no lightweight, native gallery app—the equivalent of a phone's gallery app—for Mac.

**The gap we're filling:**

| App | Problem |
|-----|---------|
| Apple Photos | Wants to own/import your files, pushes iCloud |
| Lightroom | $10/mo subscription, primarily an editor |
| Photo Mechanic | $139, dated UI, no semantic search |
| Finder | It's... Finder |

Searchy aims to become the **native macOS media manager** that doesn't exist—with semantic search superpowers.

**Design principles:**
- **Proxy-based** — Your files stay exactly where they are. We're a lens, not a file manager.
- **Non-destructive** — Albums, tags, ratings are metadata in our database. Original files never touched.
- **Symlink exports** — Want a physical folder for an album? We create symlinks. Delete the album? Originals are safe.
- **Smart search** — Semantic search, face grouping, OCR, smart collections. Find photos without manual tagging.

**Planned features:**

| Feature | Description |
|---------|-------------|
| Albums & Collections | Virtual organization, multiple albums per image |
| Tags & Ratings | Color tags, star ratings, flags |
| Smart Albums | Auto-populated based on rules (faces, dates, content) |
| Timeline View | Browse by date with EXIF data |
| Map View | Browse by location (GPS from EXIF) |
| Metadata Panel | View/edit EXIF, IPTC, XMP |
| Quick Look Integration | Spacebar preview like Finder |
| Import Workflow | Watch folders, camera import |
| Trash & Recovery | Safe deletion with undo |

**The pitch:** A native macOS photo browser with semantic search built-in. No subscription, no cloud lock-in, no importing. Point at your folders and go.

---

## Security & Privacy

Searchy runs entirely on your device. No cloud, no telemetry, no external requests after initial model download. This section explains our security decisions transparently—including what we deliberately chose *not* to implement.

### Threat Model

We consider two attack paths:

| Path | Scenario | Our Focus |
|------|----------|-----------|
| **Path 1** | Searchy is the attack vector (how an attacker gets in) | **Hardened** |
| **Path 2** | Attacker already has system access | Limited value in additional measures |

### What We Hardened (Path 1)

These protect against Searchy being used as an entry point:

| Measure | Why |
|---------|-----|
| **CORS restricted to localhost** | Prevents malicious websites from querying your local API to enumerate images |
| **Server binds to 127.0.0.1** | API not accessible from other machines on your network |
| **Dependencies pinned** | Reduces supply chain attack surface from malicious package updates |

### What We Didn't Do (and Why)

| Suggestion | Why We Skipped It |
|------------|-------------------|
| **Encrypt face embeddings** | If an attacker has access to read `~/Library/Application Support/searchy/`, they can already access your original images in `~/Pictures`. Encrypting the index while leaving source images unencrypted is security theater. |
| **API authentication tokens** | The API only accepts localhost connections. Any process that can call the API can also read the index files directly. Authentication adds complexity without security benefit. |
| **Encrypt the image index** | Same reasoning as biometrics—the original images aren't encrypted, so encrypting their embeddings doesn't protect anything meaningful. |
| **Sandbox the app** | Would break the core functionality (indexing user-selected directories). We use runtime permissions instead. |

### When Encryption *Would* Help

Encrypting index files would provide value if:
- Your `~/Library/Application Support/` syncs to iCloud (embeddings would be uploaded)
- Multiple users share the machine with separate accounts
- You want defense-in-depth regardless of practical threat model

We may add optional encryption in the future for these scenarios.

### What's Stored Locally

```
~/Library/Application Support/searchy/
├── image_index.bin      # Image embeddings + file paths (pickle)
├── face_index.pkl       # Face embeddings + clusters + person names
├── model_config.json    # Selected CLIP model
├── face_groups.json     # Custom face groups/albums
├── pinned_faces.json    # Pinned face IDs
├── hidden_faces.json    # Hidden face IDs
└── venv/                # Isolated Python environment
```

**Data collected:**
- File paths of indexed images
- CLIP embeddings (512-1024 dimensional vectors)
- OCR-extracted text from images (automatically during indexing)
- Face embeddings and cluster data (when face recognition is used)

**Not collected:**
- Search queries (in-memory only, not persisted)
- Usage analytics or telemetry
- Any data sent to external servers

### Known Limitations

1. **Pickle deserialization** — The index uses Python pickle format, which can execute arbitrary code if the file is tampered with. If an attacker can write to your Application Support folder, they could replace the index with a malicious one. We're evaluating safer serialization formats.

2. **HuggingFace model loading** — Models are downloaded from HuggingFace without checksum verification. A compromised model could execute code on load.

3. **No biometric consent flow** — Face recognition indexes faces without explicit opt-in consent. This may have legal implications in jurisdictions like Illinois (BIPA).

📄 **[Full Security Audit](security-audit/AUDIT_v1.2.md)** — Detailed findings with severity ratings

---

## Requirements

- macOS 13+
- Apple Silicon
- Internet connection (first-time setup only)
- ~2GB disk space for models

**Supported formats:** jpg, jpeg, png, gif, bmp, tiff, webp, heic

---

MIT License
