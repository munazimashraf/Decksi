#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="${DIR}/build/Decksi.app"
BIN_PATH="${APP_PATH}/Contents/MacOS/Decksi"

if [ ! -f "${BIN_PATH}" ]; then
    echo "🔨 Building Decksi first..."
    "${DIR}/build.sh"
fi

# Kill any existing instance
killall Decksi 2>/dev/null || true

echo "🚀 Launching Decksi for Mac..."
if ! open "${APP_PATH}" 2>/dev/null; then
    nohup "${BIN_PATH}" > /tmp/decksi.log 2>&1 &
fi

echo "✨ Decksi is running in your Menu Bar!"
