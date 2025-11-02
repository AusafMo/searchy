# Searchy

> Photo management on macOS sucks, so this is my attempt at making it better.

A lightweight, **Spotlight-style** semantic image search app for macOS. Search your images using natural language powered by CLIP AI.

**Entirely on-device** (except initial model download). Fast, private, and always accessible from your menu bar.

## Demo
https://github.com/user-attachments/assets/ec7f203c-3e59-49d9-9aa8-a0b171eaaae7

## Features

### Semantic Search
- **Natural Language Queries** - Search with phrases like "sunset over mountains", "person wearing red", "cat on couch"
- **Real-time Results** - Results update as you type with 400ms debounce
- **Similarity Scoring** - Color-coded match percentages (green 80%+, blue 60-80%, yellow <60%)
- **Configurable Threshold** - Filter results by minimum similarity

### Spotlight-Style Interface
- **Global Hotkey** - `⌘ + ⇧ + Space` opens Searchy from anywhere
- **Floating Window** - Borderless, glass-effect overlay
- **Instant Actions** - Copy, paste, or reveal images with keyboard shortcuts
- **Recent Images** - Shows your 8 most recent images on startup

### Auto-Indexing
- **Watches Directories** - Automatically indexes new images in watched folders
- **Default Watchers** - ~/Downloads (all images) and ~/Desktop (screenshots only)
- **Incremental Updates** - Only processes new files, preserves existing index
- **Configurable Filters** - Filter by prefix, suffix, or custom regex

### Beautiful UI
- **Theme Toggle** - Switch between System, Light, and Dark themes
- **Glass-Morphism Design** - Modern transparent materials and gradients
- **Hover Effects** - 3D rotation and glow effects on image cards
- **Responsive Grid** - 2-6 columns with adjustable image sizes

### 100% Private
- **On-Device Processing** - All AI runs locally on your Mac
- **No Cloud Required** - Works offline after initial model download
- **GPU Accelerated** - Uses Metal (Apple Silicon) or CUDA when available

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ + ⇧ + Space` | Open Searchy from anywhere |
| `⌘ + 1-9` | Copy image and paste instantly |
| `Ctrl + 1-9` | Copy image to clipboard |
| `Enter` | Copy and paste selected image |
| `⌘ + Enter` | Reveal in Finder |
| `↑ ↓` | Navigate results |
| `Esc` | Close window |

## Installation

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/searchy.git
   cd searchy
   ```

2. Create a Python virtual environment and install dependencies
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r searchy/requirements.txt
   ```

3. Open `searchy.xcodeproj` in Xcode

4. Build and run (`⌘ + R`)

On first launch, Searchy will:
- Download the CLIP model (~350MB one-time download)
- Start the FastAPI backend server
- Begin watching ~/Downloads and ~/Desktop for new images

## Settings

Access settings via the gear icon in the header:

### Display
- **Grid Columns** - 2 to 6 columns
- **Image Size** - 100px to 400px thumbnails
- **Show Statistics** - Display search performance stats

### Search
- **Max Results** - 10, 20, 50, or 100 results
- **Similarity Threshold** - Minimum match percentage (0-100%)

### Indexing
- **Fast Indexing** - Resize images before processing (recommended)
- **Max Dimension** - 256, 384, 512, or 768px
- **Batch Size** - 32, 64, 128, or 256 images per batch

### Watched Directories
- Add folders to automatically index new images
- Set filters: All Files, Starts With, Ends With, or Custom Regex
- Re-index all watched directories with one click

### Paths
- Configure Python executable, server script, and data directory paths

## Architecture

```
searchy/
├── searchy.xcodeproj     # Xcode project
├── searchy/
│   ├── ContentView.swift # Main UI (SwiftUI)
│   ├── searchyApp.swift  # App lifecycle, server management
│   ├── server.py         # FastAPI backend
│   ├── generate_embeddings.py  # CLIP indexing
│   ├── image_watcher.py  # Auto-indexing daemon
│   └── requirements.txt  # Python dependencies
└── README.md
```

**Tech Stack:**
- **Frontend:** SwiftUI, AppKit
- **Backend:** FastAPI, Uvicorn
- **AI Model:** OpenAI CLIP (ViT-B/32)
- **Storage:** Pickle binary index with numpy embeddings

## To-Do

### Planned Features
- [ ] Duplicate image detection and cleanup
- [ ] Custom/smaller models (domain-specific for fashion, art, etc.)
- [ ] Date, size, and file type filters
- [ ] Hybrid search with image captions
- [ ] User-defined tags and categories
- [ ] Model offloading after idle timeout
- [ ] Bundled app for easy distribution

### Completed
- [x] Spotlight-style floating widget
- [x] Global hotkey (`⌘ + ⇧ + Space`)
- [x] Transparent glass UI with theme toggle
- [x] Real-time search with debouncing
- [x] Auto-indexing with file watchers
- [x] Watched directories with filters
- [x] Configurable settings panel
- [x] Menu bar-only app (no Dock icon)
- [x] GPU acceleration (Metal/CUDA)
- [x] Recent images display
- [x] Fast indexing with image resizing

## Supported Formats

`.jpg` `.jpeg` `.png` `.gif` `.bmp` `.tiff` `.webp` `.heic`

## Requirements

- macOS 13.0+
- Python 3.9+
- ~1.1GB RAM (when model is loaded)
- Disk space for index (varies by library size)

## License

MIT
