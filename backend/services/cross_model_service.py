"""
Cross-Model Router: sends a prompt to multiple Ollama models concurrently
and returns all responses in a single dict.
"""

from __future__ import annotations

import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
MODELS = ["phi3", "llama3", "mistral"]


def _query_single_model(model: str, prompt: str) -> tuple[str, str]:
    """
    Send a prompt to a single Ollama model and return a (model_name, response) tuple.

    Args:
        model: The Ollama model name to query.
        prompt: The text prompt to send.

    Returns:
        A tuple of (model_name, response_text_or_error_string).
    """
    try:
        response = requests.post(
            OLLAMA_URL,
            json={"model": model, "prompt": prompt, "stream": False},
            timeout=None,  # no timeout — Ollama queues requests serially, let it finish
        )
        response.raise_for_status()
        data = response.json()
        return model, data.get("response", "")
    except requests.RequestException as exc:
        return model, f"error: {exc}"


def query_all_models(prompt: str) -> dict[str, str]:
    """
    Query all configured Ollama models sequentially with the given prompt.

    Calls each model one at a time so Ollama can fully unload the previous
    model before loading the next, avoiding out-of-memory failures on
    machines that cannot hold all models in RAM simultaneously.

    Args:
        prompt: The text prompt to send to every model.

    Returns:
        A dict mapping each model name to its response text, or to an error
        string (prefixed with "error:") if the request failed.
    """
    results: dict[str, str] = {}

    for model in MODELS:
        model_name, response = _query_single_model(model, prompt)
        results[model_name] = response

    return results
