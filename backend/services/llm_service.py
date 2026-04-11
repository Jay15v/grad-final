import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_CHAT_URL = "http://localhost:11434/api/chat"
MODEL_NAME = "phi3"


def call_ollama_chat(message: str, history: list = None) -> str:
    """
    Calls Ollama phi3 in chat mode with conversation history.
    Returns the assistant reply as a string.
    """
    messages = [
        {
            "role": "system",
            "content": (
                "You are a helpful, knowledgeable AI assistant. "
                "Provide clear, accurate, and concise responses."
            ),
        }
    ]
    if history:
        for h in history:
            role = h.get("role", "user")
            content = h.get("content", "")
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})

    messages.append({"role": "user", "content": message})

    payload = {
        "model": MODEL_NAME,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": 0.7,
            "top_p": 0.9,
            "num_predict": 512,
        },
    }

    try:
        print(f"[OLLAMA] Sending request to {OLLAMA_CHAT_URL} with model={MODEL_NAME}")
        resp = requests.post(OLLAMA_CHAT_URL, json=payload, timeout=120)
        print(f"[OLLAMA] Response status: {resp.status_code}")
        print(f"[OLLAMA] Response body: {resp.text[:500]}")
        resp.raise_for_status()
        data = resp.json()
        content = data.get("message", {}).get("content", "")
        return content if isinstance(content, str) else str(content)
    except requests.exceptions.RequestException as e:
        print(f"[OLLAMA] REQUEST ERROR: {type(e).__name__}: {e}")
        return "I'm unable to respond right now."
    except ValueError as e:
        print(f"[OLLAMA] JSON ERROR: {e}")
        return "I'm unable to respond right now."


def call_phi3(prompt: str) -> str:
    """
    Calls Ollama (phi3) and returns the generated text.
    Always returns a string (never None).
    """
    payload = {
    "model": MODEL_NAME,
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
