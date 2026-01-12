<h1 align="center">Searchy</h1>

<p align="center">A semantic image search tool for macOS that uses CLIP to find images through natural language queries.</p>

<p align="center"><b>On-device processing</b> · <b>Spotlight-style interface</b> · <b>GPU accelerated</b></p>

https://github.com/user-attachments/assets/ec7f203c-3e59-49d9-9aa8-a0b171eaaae7

---

<p align="center">Photo management on macOS sucks. Searchy indexes your images locally and lets you search them using descriptive phrases like <i>"sunset over mountains"</i>, <i>"person wearing red"</i>, or <i>"cat sleeping on couch"</i>. Access it instantly from the menu bar with a global hotkey.</p>

---

## Installation

### Download (Recommended)

1. Download `Searchy.dmg` from [Releases](https://github.com/AusafMo/searchy/releases)
2. Drag to Applications
3. Right-click → Open (first time only, macOS security)
4. Click **Start Setup** — Python & AI models install automatically (3-5 min)

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
- Download AI dependencies (~2GB)
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

**Semantic Search**
- Query images using natural language descriptions
- Real-time results with 400ms debounce
- Similarity scores displayed as color-coded percentages
- Adjustable threshold to filter weak matches
- Filter results by file type, date range, and size

**Duplicate Detection**
- Find visually similar images across your library
- Adjustable similarity threshold (85-99%)
- Auto-select smaller duplicates for cleanup
- Preview images before deleting
- Move or trash duplicates in bulk

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

**Privacy**
- All processing runs locally on your machine
- No network requests after initial setup
- GPU acceleration via Metal (Apple Silicon)
- See [Security Audit](security-audit/) for detailed privacy analysis

---

## Architecture

```
searchy/
├── ContentView.swift       # SwiftUI interface
├── searchyApp.swift        # App lifecycle, setup manager, server management
├── server.py               # FastAPI backend
├── generate_embeddings.py  # CLIP model and embedding generation
├── image_watcher.py        # File system monitor for auto-indexing
└── requirements.txt
```

**Stack:** SwiftUI + AppKit → FastAPI + Uvicorn → CLIP ViT-B/32 → NumPy embeddings

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
| `/search` | POST | `{"query": str, "n_results": int, "threshold": float}` | `{"results": [{"path": str, "similarity": float}, ...]}` |
| `/recent` | GET | `?n=int` | `{"results": [{"path": str, "similarity": float}, ...]}` |
| `/index-count` | GET | — | `{"count": int}` |
| `/duplicates` | POST | `{"threshold": float, "data_dir": str}` | `{"groups": [...], "total_duplicates": int}` |

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
- [ ] Alternative/smaller models

---

## Security & Privacy

Searchy is designed with privacy in mind - all processing happens locally on your device. We maintain a security audit report to ensure transparency about data handling practices.

**What the audit covers:**
- Data collection and storage practices
- Network communications security
- Permissions and entitlements
- Third-party dependency analysis
- Privacy compliance considerations

**Key privacy facts:**
- Images are never uploaded to external servers
- Embeddings and indexes are stored locally in `~/Library/Application Support/searchy/`
- Face recognition data (if enabled) is stored locally only
- The API server only accepts connections from localhost

📄 **[View Full Security Audit](security-audit/AUDIT_v1.1.md)**

---

## Requirements

- macOS 13+
- Apple Silicon
- Internet connection (first-time setup only)
- ~2GB disk space for AI models

**Supported formats:** jpg, jpeg, png, gif, bmp, tiff, webp, heic

---

MIT License
