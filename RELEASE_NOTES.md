## What's New

### Searchy 4.3
- **New gallery UI** — Adds the redesigned library, gallery, duplicates, people, volumes, setup, and settings surfaces.
- **Large-library readiness** — Verified indexing against a 1,200-image COCO subset plus the showcase pack.
- **Better retrieval path** — Includes multi-signal search, OCR tokenization improvements, SigLIP/PE-Core model options, and weighted RRF ranking.
- **Indexing reliability fix** — CLI/manual indexing now honors the saved model config instead of falling back to the default model.
- **Clearer model status** — The indexing completion card refreshes the active model state when a run finishes.

### Verification
- Indexed 1,200 COCO images in 47.9s on CLIP ViT-B/32 with MPS.
- `make test`: 22 backend tests passing.

---

### Install
```
brew install --cask ausafmo/searchy/searchy
```

### Uninstall
```
brew uninstall --cask searchy
rm -rf ~/Library/Application\ Support/searchy
```
