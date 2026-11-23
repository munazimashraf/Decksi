#!/bin/bash
# Rebuild if needed
if [ ! -d "build/Decksi.app" ]; then
    ./build.sh
fi

echo "🚀 Launching Decksi for Mac..."
open build/Decksi.app
echo "✨ Decksi is running in your Menu Bar!"
