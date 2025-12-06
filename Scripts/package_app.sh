#!/bin/bash

# Exit on error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="Searchy.app"
DMG_NAME="Searchy.dmg"

# Create build directory
mkdir -p "$BUILD_DIR"

# Build app using xcodebuild
xcodebuild -scheme Searchy -configuration Release -archivePath "$BUILD_DIR/Searchy.xcarchive" archive

# Create DMG
create-dmg \
  --volname "Searchy Installer" \
  --volicon "$PROJECT_ROOT/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "$APP_NAME" 200 190 \
  --hide-extension "$APP_NAME" \
  --app-drop-link 600 185 \
  "$BUILD_DIR/$DMG_NAME" \
  "$BUILD_DIR/$APP_NAME"

echo "Package creation complete"
