# Distribution Guide

## Quick Start - Create Distribution Package

Run the packaging script (recommended):
```bash
./package_distribution.sh
```

This will automatically:
- Build an optimized release executable
- Copy all required assets
- Create a ready-to-distribute folder: `junction25_distribution/`

## Manual Build

### Build Release Executable
```bash
odin build . -out:junction25_release -o:speed
```

Or use the build script:
```bash
./build_release.sh
```

## Distribution Package Contents

The `junction25_distribution/` folder contains:

1. **Executable**: `junction25_release` (1.7MB, optimized for speed)
2. **Assets folder**: All game assets (images, music, sprites)
3. **Python bridge**: `gemini_api_bridge.py` (for Gemini API)
4. **README**: Instructions for users

### Required Files Structure:
```
junction25_distribution/
├── junction25_release          (executable)
├── assets/                      (all game assets)
│   ├── background_music.mp3
│   ├── cheese_merchant.png
│   ├── dungeon_bg1.png
│   ├── dungeon_bg2.png
│   ├── dungeon_bg3.png
│   ├── enemy_sheet.png
│   ├── gpt_test1.png
│   ├── machine_gun.png
│   ├── pistol.png
│   ├── pixelanton.jpg
│   ├── player_sheet.png
│   ├── rifle.png
│   ├── shotgun.png
│   └── sniper.png
├── gemini_api_bridge.py        (for Gemini API)
└── README.txt                  (user instructions)
```

## Distributing the Game

1. **Zip the distribution folder**:
   ```bash
   zip -r junction25_game.zip junction25_distribution/
   ```

2. **Share the zip file** with testers

3. **Users extract and run**:
   - Extract the zip
   - Navigate to `junction25_distribution/`
   - Run `./junction25_release` (macOS/Linux) or `junction25_release.exe` (Windows)

## Platform-Specific Builds

### macOS (Current)
- Executable: `junction25_release` (Mach-O binary)
- Build: `odin build . -out:junction25_release -o:speed`
- Users may need to right-click and "Open" the first time (macOS security)

### Windows
- **Note**: Cross-compilation from macOS/Linux to Windows is not supported by Odin
- To build Windows .exe, you must build on a Windows machine:
  ```bash
  odin build . -out:junction25_release.exe -target:windows_amd64 -o:speed
  ```
- See `BUILD_WINDOWS.md` for detailed instructions and alternatives
- Executable: `junction25_release.exe`
- Python 3 required for Gemini API

### Linux
- Build: `odin build . -out:junction25_release -target:linux_amd64 -o:speed`
- Make executable: `chmod +x junction25_release`
- Python 3 required for Gemini API

## Requirements for Users

- **macOS/Linux/Windows** compatible executable
- **Python 3** (for Gemini API features - optional)
- All files must stay in the same folder structure

## Notes

- The game works without the Gemini API (merchant uses fallback dialogue)
- Assets must be in the `assets/` folder relative to the executable
- The executable is optimized for speed (`-o:speed`)
- Package size: ~12MB (includes all assets)
