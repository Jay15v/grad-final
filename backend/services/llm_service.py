import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "phi3"

def call_phi3(prompt: str) -> str:
    """
    Calls Ollama (phi3) and returns the generated text.
    Always returns a string (never None).
    """
    payload = {
    "model": "phi3",
    "prompt": prompt,
    "stream": False,
    "options": {
        "temperature": 0.0,
        "top_p": 0.9,
        "num_predict": 180
    }
}


    try:
        response = requests.post(OLLAMA_URL, json=payload, timeout=120)
        response.raise_for_status()

        data = response.json()
        out = data.get("response", "")

        if out is None:
            return ""
        if not isinstance(out, str):
            return str(out)

        return out

    except requests.exceptions.RequestException as e:
        print("OLLAMA REQUEST ERROR:", str(e))
        return ""
    except ValueError as e:
        # JSON decode error
        print("OLLAMA JSON ERROR:", str(e))
        return ""
