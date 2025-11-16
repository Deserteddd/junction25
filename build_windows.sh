#!/bin/bash
# Build script for Windows executable
# NOTE: This requires building on Windows or using a Windows VM/container
# Odin does not support cross-compilation to Windows from macOS/Linux

echo "⚠ WARNING: Cross-compilation to Windows is not supported by Odin."
echo ""
echo "To build a Windows .exe, you need to:"
echo "1. Build on a Windows machine, OR"
echo "2. Use a Windows VM/container, OR"
echo "3. Use GitHub Actions or similar CI/CD"
echo ""
echo "Build command for Windows:"
echo "  odin build . -out:junction25_release.exe -target:windows_amd64 -o:speed"
echo ""
echo "Alternatively, you can:"
echo "- Share the source code and let Windows users build it themselves"
echo "- Use a CI/CD service like GitHub Actions to build for multiple platforms"

