"""
Cross-Model Router: sends a prompt to multiple Ollama models concurrently
and returns all responses in a single dict.
"""

from __future__ import annotations

import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

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
            timeout=60,
        )
        response.raise_for_status()
        data = response.json()
        return model, data.get("response", "")
    except requests.Timeout:
        return model, f"error: timeout querying model '{model}'"
    except requests.RequestException as exc:
        return model, f"error: {exc}"


def query_all_models(prompt: str) -> dict[str, str]:
    """
    Query all configured Ollama models concurrently with the given prompt.

    Sends the prompt to every model in MODELS at the same time using a
    ThreadPoolExecutor.  If a model times out or raises any requests error,
    its error message is stored as the value instead of crashing the caller.

    Args:
        prompt: The text prompt to send to every model.

    Returns:
        A dict mapping each model name to its response text, or to an error
        string (prefixed with "error:") if the request failed.
    """
    results: dict[str, str] = {}

    with ThreadPoolExecutor(max_workers=len(MODELS)) as executor:
        futures = {
            executor.submit(_query_single_model, model, prompt): model
            for model in MODELS
        }
        for future in as_completed(futures):
            model_name, response = future.result()
            results[model_name] = response

    return results
