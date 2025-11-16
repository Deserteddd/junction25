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
