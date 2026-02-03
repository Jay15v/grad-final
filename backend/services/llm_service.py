import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "phi3"

def call_phi3(prompt: str) -> str:
    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "stream": False
    }

    response = requests.post(OLLAMA_URL, json=payload, timeout=120)
    response.raise_for_status()

    return response.json()["response"]
