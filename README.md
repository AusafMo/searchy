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

**Spotlight-Style Interface**
- Global hotkey `⌘⇧Space` summons a floating search window
- Displays recent images on launch
- Fully keyboard-navigable

**Auto-Indexing**
- Monitors configured directories automatically
- Supports custom directories with prefix, suffix, or regex filters
- Incremental indexing — only processes new files

**Zero-Config Setup**
- Automatic Python installation (via Homebrew or standalone)
- Isolated virtual environment in Application Support
- All dependencies installed on first launch

**Privacy**
- All processing runs locally on your machine
- No network requests after initial setup
- GPU acceleration via Metal (Apple Silicon)

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
- [ ] Duplicate image detection
- [ ] Alternative/smaller models
- [ ] Date, size, and file type filters

---

## Requirements

- macOS 13+
- Apple Silicon
- Internet connection (first-time setup only)
- ~2GB disk space for AI models

**Supported formats:** jpg, jpeg, png, gif, bmp, tiff, webp, heic

---

MIT License
