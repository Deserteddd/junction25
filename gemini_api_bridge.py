#!/usr/bin/env python3
"""
Bridge script to call Gemini API from Odin.
This script handles the HTTP request and returns the response.
"""
import sys
import os
import json
import urllib.request
import urllib.error

def call_gemini_api(api_key: str, message: str) -> str:
    """Call Gemini API and return the response text."""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key={api_key}"
    
    payload = {
        "contents": [{
            "parts": [{
                "text": message
            }]
        }]
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with urllib.request.urlopen(req) as response:
            response_data = json.loads(response.read().decode('utf-8'))
            
            # Extract text from response
            if 'candidates' in response_data and len(response_data['candidates']) > 0:
                candidate = response_data['candidates'][0]
                if 'content' in candidate and 'parts' in candidate['content']:
                    if len(candidate['content']['parts']) > 0:
                        return candidate['content']['parts'][0].get('text', '')
            
            # If we get here, something went wrong
            return json.dumps(response_data)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        return f"HTTP Error {e.code}: {error_body}"
    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == "__main__":
    # Try environment variables first (safer, avoids shell escaping issues)
    api_key = os.environ.get("GEMINI_API_KEY")
    message = os.environ.get("GEMINI_MESSAGE")
    
    # Fall back to command-line arguments if env vars not set
    if not api_key or not message:
        if len(sys.argv) != 3:
            print("Usage: gemini_api_bridge.py <api_key> <message>", file=sys.stderr)
            print("Or set GEMINI_API_KEY and GEMINI_MESSAGE environment variables", file=sys.stderr)
            sys.exit(1)
        api_key = sys.argv[1]
        message = sys.argv[2]
    
    response = call_gemini_api(api_key, message)
    print(response)

