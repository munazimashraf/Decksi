#!/bin/bash
set -e

APP_NAME="Decksi"
BUILD_DIR="build"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${BUNDLE_DIR}/Contents/MacOS"
RESOURCES_DIR="${BUNDLE_DIR}/Contents/Resources"

echo "🔨 Building Decksi for Mac..."

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp resources/Info.plist "${BUNDLE_DIR}/Contents/Info.plist"
if [ -f "resources/AppIcon.icns" ]; then
    cp resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

clang -O3 -fobjc-arc \
    -framework Cocoa \
    -framework QuartzCore \
    -framework ScreenCaptureKit \
    -framework CoreMedia \
    -framework Accelerate \
    -framework AVFoundation \
    -Isrc \
    src/main.m \
    src/AppDelegate.m \
    src/Settings.m \
    src/MusicDetector.m \
    src/AudioEngine.m \
    src/BorderGlowView.m \
    src/BorderOverlayController.m \
    src/MenuBarController.m \
    src/ParticleEngine.m \
    src/NowPlayingHUD.m \
    src/LyricsManager.m \
    -o "${MACOS_DIR}/${APP_NAME}"

# Consistent ad-hoc code sign for macOS Gatekeeper and TCC permissions
codesign --force --deep --sign - --identifier "in.decksi.mac" "${BUNDLE_DIR}" 2>/dev/null || true

echo "✅ Build completed successfully!"
echo "📦 Application located at: ${BUNDLE_DIR}"
