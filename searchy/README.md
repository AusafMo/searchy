# Searchy

> Photo management on macOS sucks, so this is my attempt at making it better.

A lightweight, **Spotlight-style** semantic image search app for macOS. Search your images using natural language powered by CLIP AI.

**Entirely on-device** (except initial model download). Fast, private, and always accessible from your menu bar.

## Features

- **Semantic Search** - Search images using natural language ("sunset over mountains", "person wearing red", etc.)
- **Real-time Search** - Results update as you type with smart debouncing
- **Keyboard-First** - Spotlight-style interface with powerful keyboard shortcuts
- **Beautiful UI** - Transparent glassy design with instant navigation
- **Menu Bar App** - Always accessible via `⌘ + ⇧ + Space` global hotkey
- **100% Private** - All processing happens on your Mac
- **CLIP Powered** - Uses OpenAI's CLIP model for semantic understanding

## Keyboard Shortcuts

- **⌘ + ⇧ + Space** - Open Searchy from anywhere
- **⌘ + 1-9** - Copy image and paste instantly
- **Ctrl + 1-9** - Copy image to clipboard
- **Enter** - Copy and paste selected image
- **⌘ + Enter** - Reveal in Finder
- **↑ ↓** - Navigate results
- **Esc** - Close window

## Demo
https://github.com/user-attachments/assets/ec7f203c-3e59-49d9-9aa8-a0b171eaaae7

## Installation

1. Clone the repository
2. Install Python dependencies: `pip install -r searchy/requirements.txt`
3. Open `searchy.xcodeproj` in Xcode
4. Build and run

On first launch, Searchy will download the CLIP model (~350MB) and index your images.

## To-Do

### New Features (not in order)
- [ ] Duplicate deleter for better image management
- [ ] Custom models (smaller/lighter or domain-specific like fashion, art)
- [ ] Custom user scripts for indexing/querying with plug-and-play frontend
- [ ] Model offloading after configurable idle time
- [ ] More filters (date, size, file type)
- [ ] Hybrid search over captions (API-based or manual)
- [ ] Tags/classification based on user-provided categories

### Completed
- [x] Spotlight-style widget
- [x] Global hotkey (⌘ + ⇧ + Space)
- [x] Clean, transparent glassy UI
- [x] Real-time search with debouncing
- [x] Instant arrow navigation (no lag)
- [x] Fixed duplicate window bug
- [x] Menu bar-only app (no Dock icon)

### Ongoing Improvements
- [ ] Bundle app for distribution
- [ ] Better indexing progress UI (persistent notifications)
- [ ] Support for more image formats
- [ ] Performance optimizations for large libraries (>50k images)
