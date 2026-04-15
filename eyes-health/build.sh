#!/bin/bash
# Build and package EyesHealth as a macOS .app bundle
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/arm64-apple-macosx/debug"
APP_DIR="$SCRIPT_DIR/.build/EyesHealth.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Building EyesHealth ==="
cd "$SCRIPT_DIR"
swift build 2>&1

echo "=== Packaging as .app bundle ==="
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/EyesHealth" "$MACOS_DIR/EyesHealth"

# Copy Info.plist
cp "$SCRIPT_DIR/EyesHealth/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "=== Build complete ==="
echo "App bundle: $APP_DIR"
echo ""
echo "To run: open $APP_DIR"
echo "To kill: pkill -f EyesHealth.app"
