"""
Cross-Model Router: sends a prompt to multiple Groq-hosted models concurrently
and returns all responses in a single dict.
"""

from __future__ import annotations

import os
import requests

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

MODELS = ["llama-3.1-8b-instant", "llama-3.3-70b-versatile", "meta-llama/llama-4-scout-17b-16e-instruct"]
_MODEL_TIMEOUT = 30


def _query_single_model(model: str, prompt: str) -> tuple[str, str]:
    try:
        response = requests.post(
            GROQ_URL,
            headers={
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 300,
                "temperature": 0.0,
            },
            timeout=_MODEL_TIMEOUT,
        )
        response.raise_for_status()
        text = response.json()["choices"][0]["message"]["content"]
        print(f"[CROSS-MODEL] {model}: ok ({len(text)} chars)", flush=True)
        return model, text
    except Exception as exc:
        print(f"[CROSS-MODEL] {model}: FAILED — {type(exc).__name__}: {exc}", flush=True)
        return model, f"error: {exc}"


def query_all_models(prompt: str) -> dict[str, str]:
    """
    Query all three models. Groq handles each independently so we run them
    sequentially to stay within rate limits on the free tier.
    """
    results: dict[str, str] = {}
    for model in MODELS:
        model_name, response = _query_single_model(model, prompt)
        results[model_name] = response
    return results
