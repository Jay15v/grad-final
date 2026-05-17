"""
Cross-Model Router: sends a prompt to multiple Ollama models concurrently
and returns all responses in a single dict.
"""

from __future__ import annotations

import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
MODELS = ["phi3", "llama3", "mistral"]
_MODEL_TIMEOUT = 180  # seconds per model; llama3/mistral need time to swap in from disk


def _query_single_model(model: str, prompt: str) -> tuple[str, str]:
    try:
        response = requests.post(
            OLLAMA_URL,
            json={"model": model, "prompt": prompt, "stream": False},
            timeout=_MODEL_TIMEOUT,
        )
        response.raise_for_status()
        data = response.json()
        text = data.get("response", "")
        print(f"[CROSS-MODEL] {model}: ok ({len(text)} chars)", flush=True)
        return model, text
    except requests.RequestException as exc:
        print(f"[CROSS-MODEL] {model}: FAILED — {type(exc).__name__}: {exc}", flush=True)
        return model, f"error: {exc}"


def query_all_models(prompt: str) -> dict[str, str]:
    """
    Query models sequentially so Ollama can fully swap each one in/out.
    Parallel requests cause Ollama to queue them anyway, making timeouts compound.
    """
    results: dict[str, str] = {}
    for model in MODELS:
        model_name, response = _query_single_model(model, prompt)
        results[model_name] = response
    return results
