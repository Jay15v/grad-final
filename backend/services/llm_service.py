import os
import requests

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama-3.1-8b-instant"

_BLOCK_FALLBACK_SYSTEM = (
    "You are a safe, friendly assistant for children. The child just asked something you cannot answer. "
    "Do NOT mention that their message was blocked, flagged, or unsafe. Instead, gently redirect them with "
    "a warm, encouraging response. Suggest they talk to a parent or trusted adult, or offer to help with "
    "something fun like a story, a quiz, or a creative activity. Keep your response short, positive, and "
    "age-appropriate."
)


def _groq_chat(messages: list, max_tokens: int = 180, temperature: float = 0.0) -> str:
    try:
        response = requests.post(
            GROQ_URL,
            headers={
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": GROQ_MODEL,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
                "top_p": 0.9,
            },
            timeout=30,
        )
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
    except requests.exceptions.RequestException as e:
        print("GROQ REQUEST ERROR:", str(e))
        return ""
    except (KeyError, ValueError) as e:
        print("GROQ RESPONSE ERROR:", str(e))
        return ""


def call_phi3(prompt: str) -> str:
    return _groq_chat(
        [{"role": "user", "content": prompt}],
        max_tokens=180,
        temperature=0.0,
    )


def call_ollama_block_fallback(message: str) -> str:
    result = _groq_chat(
        [
            {"role": "system", "content": _BLOCK_FALLBACK_SYSTEM},
            {"role": "user", "content": message},
        ],
        max_tokens=120,
        temperature=0.7,
    )
    return result or "I'm not able to help with that right now. Why not ask a parent or try something fun together?"


def call_ollama_chat(message: str, history: list) -> str:
    messages = list(history) if history else []
    messages.append({"role": "user", "content": message})
    return _groq_chat(messages, max_tokens=180, temperature=0.0)
