# Gemini API Setup for Odin

## Overview
Odin doesn't have a built-in HTTP client, so we need to use external tools to make HTTPS requests to the Gemini API.

## Current Implementation
The code currently has a placeholder that uses keyword-based responses when the API key is not set. To enable actual Gemini API calls, you have several options:

## Option 1: Use curl via Shell (Recommended for Quick Setup)
This is the simplest approach but requires curl to be installed.

The implementation uses `os.exec_process` to call curl. However, the exact API may vary depending on your Odin version.

## Option 2: Use FFI with libcurl (Most Robust)
Create FFI bindings for libcurl to make HTTP requests directly from Odin.

Example FFI binding:
```odin
foreign import libcurl "system:curl"

foreign libcurl {
    curl_easy_init :: proc() -> rawptr ---
    curl_easy_setopt :: proc(curl: rawptr, option: i32, parameter: rawptr) -> i32 ---
    curl_easy_perform :: proc(curl: rawptr) -> i32 ---
    curl_easy_cleanup :: proc(curl: rawptr) ---
    // ... more bindings
}
```

## Option 3: Use a Python/Node.js Bridge
Create a small Python script that handles the HTTP request, and call it from Odin using `os.exec_process`.

## Option 4: Use core:net with TLS Library
Implement TLS support using a C library via FFI, then use `core:net` for the TCP connection.

## Current Status
- ✅ API key loading from .env file works
- ✅ JSON payload construction works
- ✅ Response parsing logic is ready
- ⚠️ HTTP client implementation needs to be completed

## Testing the API Key
You can test if your API key works using curl directly:

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'
```

## Next Steps
1. Choose one of the options above
2. Implement the HTTP client
3. Test with your API key from .env file
4. The NPC will then use real Gemini AI responses!

