#!/bin/bash
# Build script for creating a release executable

echo "Building release executable..."
odin build . -out:junction25_release -o:speed

if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    echo "Executable: junction25_release"
    echo ""
    echo "To distribute:"
    echo "1. Copy junction25_release to your distribution folder"
    echo "2. Copy the 'assets' folder to the same location"
    echo "3. Copy gemini_api_bridge.py if using Gemini API"
    echo "4. Create a .env file with API_KEY if using Gemini API"
    echo ""
    echo "The game expects these files in the same directory:"
    echo "  - assets/ (folder with all game assets)"
    echo "  - gemini_api_bridge.py (for Gemini API)"
    echo "  - .env (optional, for API key)"
else
    echo "✗ Build failed!"
    exit 1
fi

