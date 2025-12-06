<h1 align="center">Searchy</h1>

<p align="center">Semantic image search for macOS. Find images using natural language, powered by CLIP.</p>

<p align="center"><b>100% on-device</b> · <b>Spotlight-style</b> · <b>GPU accelerated</b></p>

https://github.com/user-attachments/assets/ec7f203c-3e59-49d9-9aa8-a0b171eaaae7

---

<p align="center">Photo management on macOS sucks. Searchy lets you search your images with phrases like <i>"sunset over mountains"</i>, <i>"person wearing red"</i>, or <i>"cat on couch"</i> — instantly from your menu bar.</p>

---

## Installation

```bash
git clone https://github.com/AusafMo/searchy.git
cd searchy
python3 -m venv .venv
source .venv/bin/activate
pip install -r searchy/requirements.txt
```

Open `searchy.xcodeproj` → Build & Run (`⌘R`)

On first launch:
- Downloads CLIP model (~1GB)
- Starts FastAPI backend
- Begins watching directories

---

## Keyboard Shortcuts

```
⌘⇧Space      Open Searchy
↑ ↓          Navigate results
Enter        Copy & paste image
⌘Enter       Reveal in Finder
⌘1-9         Copy & paste by number
Ctrl+1-9     Copy only
Esc          Close
```

---

## Settings

**Display** — Grid columns (2-6), image size (100-400px), show statistics

**Search** — Max results (10/20/50/100), similarity threshold (0-100%)

**Indexing** — Fast indexing toggle, max dimension (256-768px), batch size (32-256)

**Watched Directories** — Add/remove folders, set filters, re-index all

**Paths** — Python executable, server script, data directory

---

<h2 align="center">Features</h2>

**Semantic Search**
- Natural language queries with real-time results (400ms debounce)
- Color-coded similarity scores: green (80%+), blue (60-80%), yellow (<60%)
- Configurable threshold filtering

**Spotlight-Style Interface**
- Global hotkey `⌘⇧Space` opens a floating, borderless window
- Shows 8 most recent images on startup
- Keyboard-driven workflow

**Auto-Indexing**
- Watches ~/Downloads and ~/Desktop automatically
- Add custom directories with prefix, suffix, or regex filters
- Incremental updates — only new files get processed

**UI**
- Theme toggle (System/Light/Dark)
- Glass-morphism design with hover effects
- Responsive grid with 2-6 columns and adjustable image sizes

**Privacy First**
- All processing happens locally
- Works offline after initial model download
- GPU accelerated via Metal (Apple Silicon) or CUDA

---

## Architecture

```
searchy/
├── ContentView.swift       # SwiftUI interface
├── searchyApp.swift        # App lifecycle, server management
├── server.py               # FastAPI backend
├── generate_embeddings.py  # CLIP indexing
├── image_watcher.py        # Auto-indexing daemon
└── requirements.txt
```

**Stack:** SwiftUI + AppKit → FastAPI + Uvicorn → CLIP ViT-B/32 → NumPy embeddings

---

## Roadmap

- [x] Spotlight-style floating widget
- [x] Global hotkey (`⌘⇧Space`)
- [x] Transparent glass UI with theme toggle
- [x] Real-time search with debouncing
- [x] Auto-indexing with file watchers
- [x] Watched directories with filters
- [x] Configurable settings panel
- [x] Menu bar-only app (no Dock icon)
- [x] GPU acceleration (Metal/CUDA)
- [x] Recent images display
- [x] Fast indexing with image resizing
- [ ] Duplicate detection
- [ ] Custom/smaller models
- [ ] Date, size, file type filters
- [ ] Hybrid search with captions
- [ ] Bundled .app distribution

---

## Requirements

macOS 13+ · Python 3.9+ · ~1.1GB RAM

**Formats:** jpg, jpeg, png, gif, bmp, tiff, webp, heic

---

MIT License
