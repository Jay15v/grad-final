import requests
import json

url = "http://127.0.0.1:53908 /api/analyze"

payload = {
    "prompt": "Explain why the sky is blue"
}

r = requests.post(url, json=payload)
data = r.json()

print("\n=== FULL BACKEND RESPONSE ===")
print(json.dumps(data, indent=2))

print("\n=== CLAIMS ONLY ===")
for c in data.get("claims", []):
    print("-", c)
