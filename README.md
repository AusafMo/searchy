<h1 align="center">Searchy</h1>

<p align="center">A hybrid image search tool for macOS that uses CLIP + OCR to find images through natural language queries and text content.</p>

<p align="center"><b>On-device processing</b> · <b>Spotlight-style interface</b> · <b>GPU accelerated</b> · <b>Face recognition</b></p>

<p align="center"><a href="https://ausafmo.com/searchy.html">ausafmo.com/searchy</a></p>

<p align="center"><b>Main App</b></p>

https://github.com/user-attachments/assets/214c1421-0893-4fac-9b18-dd4074eeb68f

<p align="center"><b>Spotlight Widget</b></p>

https://github.com/user-attachments/assets/d9753770-6b62-40f5-be5a-e625a81e5a1d

---

<p align="center">Photo management on macOS sucks. Searchy indexes your images locally and lets you search them using descriptive phrases like <i>"sunset over mountains"</i>, <i>"person wearing red"</i>, or text visible in images like <i>"invoice 2024"</i>. Find photos by face, detect duplicates, and access it instantly from the menu bar with a global hotkey.</p>

---

## Installation

### Homebrew (Recommended)

```bash
brew install --cask ausafmo/searchy/searchy
```

### Manual Download

1. Download `Searchy-v4.0.dmg` from [Releases](https://github.com/AusafMo/searchy/releases)
2. Drag to Applications
3. Right-click → Open (first time only, macOS security)
4. Click **Start Setup** — Python & CLIP models install automatically (3-5 min)

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

## Features

| Feature | Description |
|---------|-------------|
| **Hybrid Search** | Natural language + OCR text search with adjustable weighting |
| **Face Recognition** | Auto-detect, cluster, name, pin, hide, merge, group faces |
| **Duplicate Detection** | Find visually similar images, bulk cleanup |
| **Similar Image Search** | Find images similar to any selected photo |
| **Auto-Indexing** | Watch directories with filters, incremental indexing |
| **External Volumes** | Index and search images on external drives |
| **Model Selection** | Multiple CLIP models, switch without re-indexing |
| **Model TTL** | Auto-unload CLIP model after idle period to free RAM/GPU, reloads from disk cache on next search |
| **Update Checker** | Notifies when a new version is available via Homebrew |
| **Privacy** | Fully local, no cloud, no telemetry, GPU accelerated via Metal |

---

## For Developers

### Architecture

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

### Data Storage

All data stored in `~/Library/Application Support/searchy/`:

```
image_index.bin        # Embeddings + paths (pickle)
face_index.pkl         # Face embeddings + clusters
venv/                  # Isolated Python environment
```

### Embedding Format

```python
# image_index.bin structure
{
    'embeddings': np.ndarray,  # Shape: (N, 512), float32, L2-normalized
    'image_paths': list[str]   # Absolute paths
}
```

### Key API Endpoints

The FastAPI server runs on `localhost:7860` (or next available port).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/search` | POST | Semantic + OCR hybrid search |
| `/text-search` | POST | Pure OCR text search |
| `/similar` | POST | Find similar images |
| `/duplicates` | POST | Find duplicate images |
| `/recent` | GET | Recent images |
| `/face-scan` | POST | Start face detection |
| `/face-clusters` | GET | Get face groups |
| `/status` | GET | Server + model loading state |
| `/model/ttl` | GET/POST | Get/set model TTL |

### Custom Backend

Want to replace CLIP with your own model or rewrite the backend? Just respect these contracts:

**1. Embedding Index File** — `~/Library/Application Support/searchy/image_index.bin`

```python
import pickle, numpy as np

data = {
    'embeddings': np.ndarray,  # Shape: (N, embedding_dim), float32, L2-normalized
    'image_paths': list[str]   # Length N, absolute paths
}

with open('image_index.bin', 'wb') as f:
    pickle.dump(data, f)
```

**2. Server API Contract** — FastAPI/HTTP server implementing the endpoints above.

**3. Script Interface** — The app calls scripts via `Process()`:

```bash
# generate_embeddings.py — indexing
python generate_embeddings.py /path/to/folder [--fast] [--max-dimension INT] [--batch-size INT]

# Must output JSON to stdout:
{"type": "start", "total_images": N, "total_batches": N}
{"type": "progress", "batch": N, "total_batches": N, "images_processed": N, ...}
{"type": "complete", "total_images": N, "new_images": N, "total_time": float, ...}

# server.py — API server
python server.py --port PORT

# image_watcher.py — file system monitor
python image_watcher.py
```

**4. Example: Custom Model**

```python
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

### CLI Usage

```bash
cd ~/Library/Application\ Support/searchy
source venv/bin/activate
python generate_embeddings.py /path/to/images --batch-size 64 --fast
```

---

## Roadmap

- [x] Spotlight-style floating widget
- [x] Global hotkey (`⌘⇧Space`)
- [x] Auto-indexing with file watchers
- [x] GPU acceleration (Metal)
- [x] Bundled .app with auto-setup
- [x] Duplicate detection
- [x] Face recognition & clustering
- [x] Similar image search
- [x] External volume indexing
- [x] OCR text extraction & hybrid search
- [x] Model TTL & memory management
- [x] Homebrew tap distribution
- [x] In-app update notifications
- [ ] Alternative/smaller models
- [ ] Albums, tags, smart collections
- [ ] Timeline and map views
- [ ] Metadata panel (EXIF, IPTC, XMP)

---

## Vision

macOS photo management is surprisingly lacking. Apple Photos is bloated and locks you into iCloud. Lightroom is a subscription editor. There's no lightweight, native gallery app for Mac.

Searchy aims to become the **native macOS media manager** that doesn't exist — with semantic search superpowers.

- **Proxy-based** — Your files stay where they are. We're a lens, not a file manager.
- **Non-destructive** — Albums, tags, ratings are metadata. Original files never touched.
- **Smart search** — Semantic search, face grouping, OCR, smart collections. No manual tagging.

---

## Security & Privacy

Fully local. No cloud, no telemetry, no external requests after initial model download.

- CORS restricted to localhost
- Server binds to 127.0.0.1 only
- Dependencies pinned

📄 **[Full Security Audit](security-audit/AUDIT_v1.2.md)**

---

## Requirements

- macOS 13+
- Apple Silicon
- Internet connection (first-time setup only)
- ~2GB disk space for models

**Supported formats:** jpg, jpeg, png, gif, bmp, tiff, webp, heic

---

MIT License
