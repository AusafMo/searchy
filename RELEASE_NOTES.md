## What's New

### Bug Fixes
- **Fix broken indexing** — `transformers` 5.x changed `get_image_features()` / `get_text_features()` to return `BaseModelOutputWithPooling` instead of a tensor. Every batch silently failed, resulting in 0 images indexed.
- **Fix fresh install failures** — Setup verification only checked `torch` + `transformers`, missing `pyobjc`, `deepface`, and `Vision`. Users with stale venvs passed setup but crashed on text search.
- **Fix Python 3.13+ incompatibility** — TensorFlow has no build for 3.13+. Venv creation now caps at Python 3.12.
- **Fix generic error on pip failure** — Now shows last 5 lines of actual pip output instead of "check your internet connection".

### Reliability
- **Atomic index writes** — All pickle writes now use temp file + `fsync` + `os.replace`. Index files can no longer be corrupted by crashes or power loss.
- **Persistent logging** — Rotating `server.log`, `setup.log`, and `server_stdout.log` in `~/Library/Application Support/searchy/logs/`.

### UI
- **Setup redesign** — Clean minimal aesthetic, per-package install progress, scrollable error output on failure.

### DevOps
- **Pre-push git hook** — `py_compile` + `ruff` + `pytest` + `xcodebuild` (~5s).
- **20 unit tests** — Atomic writes, filename filters, text matching.
- **CI pipeline** — Build + lint + test on every PR. Automated DMG release on tags.
- **Makefile** — `make build`, `make lint`, `make test`, `make check`, `make hooks`, `make release`.

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
