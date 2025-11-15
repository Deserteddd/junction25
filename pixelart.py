import urllib.request
import json
import base64
import os
from dotenv import load_dotenv
from urllib.error import HTTPError, URLError

load_dotenv()

API_KEY = os.getenv("API_KEY")

url = "https://api.retrodiffusion.ai/v1/inferences"


headers = {
    "X-RD-Token": API_KEY,
    "Content-Type": "application/json",
}

payload = {
    "width": 256,
    "height": 256,
    "prompt": "angry pickle enemy, 8bit",
    "num_images": 1,
    "prompt_style": "rd_fast__simple"
}

# Convert payload to bytes
data = json.dumps(payload).encode("utf-8")

# Make request
req = urllib.request.Request(url, data=data, headers=headers, method="POST")

try:
    with urllib.request.urlopen(req) as resp:
        resp_text = resp.read().decode("utf-8")
        response_data = json.loads(resp_text)

    # Debug: print entire JSON
    print("Response Data:", json.dumps(response_data, indent=4))

    # --------------------------
    # UNIVERSAL BASE64 EXTRACTOR
    # --------------------------
    base64_images = None

    # Case 1: {"images": [...]}
    if isinstance(response_data, dict) and "images" in response_data:
        img_obj = response_data["images"][0]

        if isinstance(img_obj, dict):
            # Search for possible fields
            for key in ["image_b64", "image", "base64", "data", "base64_images"]:
                if key in img_obj:
                    base64_images = img_obj[key]
                    break
        elif isinstance(img_obj, str):
            base64_images = [img_obj]  # raw string

    # Case 2: ["AAAA...."]
    elif isinstance(response_data, list) and len(response_data) > 0:
        base64_images = response_data

    # Case 3: "AAAA...."
    elif isinstance(response_data, str):
        base64_images = response_data

    # Failure
    if not base64_images:
        raise ValueError("No base64 image found in API response!")

    # Decode base64
    try:
        image_data = base64.b64decode(base64_images)
        print("Base64 decode: OK")
    except Exception as e:
        raise ValueError("Base64 decode failed: " + str(e))

    # Ensure folder exists
    assets_folder = "./assets"
    os.makedirs(assets_folder, exist_ok=True)

    # Save image
    output_file = os.path.join(assets_folder, "output1.png")
    with open(output_file, "wb") as f:
        f.write(image_data)

    print(f"Image saved to {output_file}")

except HTTPError as e:
    print(f"HTTPError: {e.code} - {e.reason}")
    try:
        print(e.read().decode("utf-8"))
    except:
        pass
except URLError as e:
    print("URLError:", e.reason)
except Exception as e:
    print("Unexpected error:", e)
