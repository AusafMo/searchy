SCHEME       = searchy
PROJECT      = searchy.xcodeproj
CONFIG       = Release
BUILD_DIR    = build
ARCHIVE_PATH = $(BUILD_DIR)/Searchy.xcarchive
EXPORT_DIR   = $(BUILD_DIR)/export
APP_NAME     = searchy.app
DMG_NAME     = Searchy.dmg
DMG_DIR      = $(BUILD_DIR)/dmg
EXPORT_PLIST = ExportOptions.plist

# ─── Default ──────────────────────────────────────────────
.PHONY: help build build-release archive export dmg sha release clean lint setup run version

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ─── Build ────────────────────────────────────────────────
build: ## Build debug app
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

build-release: ## Build release app
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) build

# ─── Archive & Export ─────────────────────────────────────
archive: ## Archive for distribution
	@echo "→ Archiving $(SCHEME)..."
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-archivePath $(ARCHIVE_PATH) \
		archive
	@echo "✓ Archive at $(ARCHIVE_PATH)"

export: archive ## Export .app from archive
	@echo "→ Exporting app..."
	@mkdir -p $(EXPORT_DIR)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist $(EXPORT_PLIST) \
		-exportPath $(EXPORT_DIR)
	@echo "✓ App exported to $(EXPORT_DIR)/$(APP_NAME)"

# ─── DMG ──────────────────────────────────────────────────
dmg: export ## Create DMG installer
	@echo "→ Creating DMG..."
	@rm -rf $(DMG_DIR) && mkdir -p $(DMG_DIR)
	@cp -R $(EXPORT_DIR)/$(APP_NAME) $(DMG_DIR)/
	@rm -f $(BUILD_DIR)/$(DMG_NAME)
	create-dmg \
		--volname "Searchy" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 100 \
		--icon "$(APP_NAME)" 180 190 \
		--hide-extension "$(APP_NAME)" \
		--app-drop-link 480 190 \
		$(BUILD_DIR)/$(DMG_NAME) \
		$(DMG_DIR)
	@echo "✓ DMG at $(BUILD_DIR)/$(DMG_NAME)"

# ─── SHA (for Homebrew cask) ──────────────────────────────
sha: ## Print SHA256 of DMG (for Homebrew cask)
	@test -f $(BUILD_DIR)/$(DMG_NAME) || (echo "✘ No DMG found. Run 'make dmg' first." && exit 1)
	@echo "sha256: $$(shasum -a 256 $(BUILD_DIR)/$(DMG_NAME) | cut -d' ' -f1)"

# ─── Release (full pipeline) ─────────────────────────────
release: dmg sha ## Full release: archive → export → DMG → SHA
	@echo ""
	@echo "════════════════════════════════════════"
	@echo "  Release ready"
	@echo "════════════════════════════════════════"
	@echo "  DMG:  $(BUILD_DIR)/$(DMG_NAME)"
	@echo "  SHA:  $$(shasum -a 256 $(BUILD_DIR)/$(DMG_NAME) | cut -d' ' -f1)"
	@echo "════════════════════════════════════════"
	@echo ""
	@echo "Next steps:"
	@echo "  1. gh release upload v<version> $(BUILD_DIR)/$(DMG_NAME)"
	@echo "  2. Update Homebrew cask SHA"

# ─── Python env ───────────────────────────────────────────
setup: ## Set up Python venv with dependencies
	python3 -m venv .venv
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install -r searchy/backend/requirements.txt
	@echo "✓ Python env ready. Activate with: source .venv/bin/activate"

# ─── Lint ─────────────────────────────────────────────────
lint: ## Run linters (ruff for Python)
	@command -v ruff >/dev/null 2>&1 || (echo "Installing ruff..." && pip install ruff)
	ruff check searchy/backend/*.py searchy/backend/routes/*.py
	@echo "✓ Lint passed"

# ─── Test ─────────────────────────────────────────────────
test: ## Run Python unit tests
	@test -f .venv/bin/pytest || (python3 -m venv .venv && .venv/bin/pip install -q pytest)
	.venv/bin/pytest searchy/backend/tests/ -x -q

# ─── Check (all pre-push checks) ─────────────────────────
check: lint test ## Run lint + tests

# ─── Git hooks ────────────────────────────────────────────
hooks: ## Install git pre-push hook
	@mkdir -p .git/hooks
	@ln -sf ../../scripts/pre-push-checks.sh .git/hooks/pre-push
	@chmod +x .git/hooks/pre-push
	@echo "✓ Pre-push hook installed"

# ─── Run (dev) ────────────────────────────────────────────
run: build ## Build debug and open app
	@open "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$3}')/$(APP_NAME)"

# ─── Clean ────────────────────────────────────────────────
clean: ## Remove build artifacts
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf $(BUILD_DIR)/Searchy.xcarchive $(BUILD_DIR)/export $(BUILD_DIR)/dmg
	@echo "✓ Clean"

# ─── Version info ─────────────────────────────────────────
version: ## Show current version
	@echo "v$$(grep -m1 'MARKETING_VERSION' $(PROJECT)/project.pbxproj | tr -cd '0-9.')"
