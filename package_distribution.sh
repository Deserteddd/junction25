#!/bin/bash
# Package the game for distribution

DIST_DIR="junction25_distribution"

echo "Creating distribution package..."

# Clean previous distribution
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/assets"

# Build macOS release executable
echo "Building macOS release executable..."
odin build . -out:"$DIST_DIR/junction25_release" -o:speed

if [ $? -ne 0 ]; then
    echo "✗ macOS build failed!"
    exit 1
fi

# Build Windows release executable
echo "Building Windows release executable..."
echo "⚠ Note: Cross-compilation to Windows is not supported by Odin."
echo "   To create a Windows .exe, build on a Windows machine or use CI/CD."
echo "   See BUILD_WINDOWS.md for instructions."
odin build . -out:"$DIST_DIR/junction25_release.exe" -target:windows_amd64 -o:speed 2>&1 | grep -v "Linking for cross compilation" || true

# Check if .exe was actually created (it won't be due to cross-compilation limitation)
if [ ! -f "$DIST_DIR/junction25_release.exe" ]; then
    echo "⚠ Windows .exe not created (cross-compilation not supported)"
    echo "   macOS executable is available: junction25_release"
fi

# Copy assets
echo "Copying assets..."
cp -r assets/* "$DIST_DIR/assets/"

# Copy Python bridge script
echo "Copying Python bridge script..."
cp gemini_api_bridge.py "$DIST_DIR/"

# Create README for distribution
cat > "$DIST_DIR/README.txt" << 'EOF'
Junction25 Game - Distribution Package
======================================

HOW TO RUN:
-----------
1. Make sure you have Python 3 installed (for Gemini API features)
2. Run the executable for your platform:
   macOS: ./junction25_release
   Windows: junction25_release.exe

REQUIRED FILES:
---------------
- junction25_release (executable)
- assets/ (folder with all game assets)
- gemini_api_bridge.py (for AI features)

OPTIONAL:
---------
- .env file with API_KEY=your_key (for Gemini API)

The game will work without the API key, but the merchant will use
fallback dialogue instead of AI-generated responses.

TROUBLESHOOTING:
----------------
- If the game doesn't start, make sure all files are in the same folder
- If assets don't load, check that the 'assets' folder is in the same
  directory as the executable
- For Gemini API: ensure Python 3 is installed and gemini_api_bridge.py
  is in the same directory as the executable
EOF

echo ""
echo "✓ Distribution package created in '$DIST_DIR' folder!"
echo ""
echo "Contents:"
ls -lh "$DIST_DIR" | grep -v "^total"
echo ""
echo "Package size:"
du -sh "$DIST_DIR"
echo ""
echo "To distribute: Zip the '$DIST_DIR' folder and share it!"

