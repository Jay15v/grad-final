"""
Tests for cross_model_service.query_all_models.

All HTTP calls are mocked — Ollama does not need to be running.
"""

import json
import pytest
import requests
from unittest.mock import patch, MagicMock

import sys
import os

# Allow imports from the backend/services package when running from any cwd.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.cross_model_service import query_all_models, MODELS


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_ok_response(text: str) -> MagicMock:
    """Return a mock requests.Response that looks like a successful Ollama reply."""
    mock_resp = MagicMock()
    mock_resp.raise_for_status.return_value = None
    mock_resp.json.return_value = {"response": text}
    return mock_resp


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestQueryAllModels:
    """Unit tests for query_all_models()."""

    def test_returns_dict_with_all_three_models(self):
        """Result must contain exactly the three expected model keys."""
        with patch("services.cross_model_service.requests.post") as mock_post:
            mock_post.return_value = _make_ok_response("hello")
            result = query_all_models("test prompt")

        assert isinstance(result, dict)
        assert set(result.keys()) == {"phi3", "llama3", "mistral"}

    def test_response_values_are_strings(self):
        """Every value in the result dict must be a str."""
        with patch("services.cross_model_service.requests.post") as mock_post:
            mock_post.return_value = _make_ok_response("some response")
            result = query_all_models("test prompt")

        for key, value in result.items():
            assert isinstance(value, str), f"Value for '{key}' is not a str: {value!r}"

    def test_one_model_timeout(self):
        """A timed-out model must store an error string; other two must succeed."""
        def side_effect(url, json=None, timeout=None):
            if json and json.get("model") == "llama3":
                raise requests.Timeout("timed out")
            return _make_ok_response("ok")

        with patch("services.cross_model_service.requests.post", side_effect=side_effect):
            result = query_all_models("test prompt")

        # The failed model should have an error message
        assert "llama3" in result
        assert any(
            word in result["llama3"].lower() for word in ("error", "timeout")
        ), f"Expected error/timeout in: {result['llama3']!r}"

        # The other two should still be present
        assert "phi3" in result
        assert "mistral" in result

    def test_one_model_http_error(self):
        """A model raising RequestException must not crash; others must succeed."""
        def side_effect(url, json=None, timeout=None):
            if json and json.get("model") == "mistral":
                raise requests.RequestException("connection refused")
            return _make_ok_response("ok")

        with patch("services.cross_model_service.requests.post", side_effect=side_effect):
            result = query_all_models("test prompt")

        assert "mistral" in result
        assert "error" in result["mistral"].lower()
        assert "phi3" in result
        assert "llama3" in result

    def test_all_models_fail(self):
        """When every model raises an exception, all keys are still present with error strings."""
        with patch(
            "services.cross_model_service.requests.post",
            side_effect=requests.RequestException("network down"),
        ):
            result = query_all_models("test prompt")

        assert set(result.keys()) == {"phi3", "llama3", "mistral"}
        for key, value in result.items():
            assert "error" in value.lower(), (
                f"Expected an error string for '{key}', got: {value!r}"
            )

    def test_prompt_sent_to_all_models(self):
        """The exact prompt must appear in the POST body for all three models."""
        sent_bodies = []

        def capture(url, json=None, timeout=None):
            sent_bodies.append(json)
            return _make_ok_response("ok")

        test_prompt = "unique canary prompt 12345"

        with patch("services.cross_model_service.requests.post", side_effect=capture):
            query_all_models(test_prompt)

        assert len(sent_bodies) == 3, f"Expected 3 POST calls, got {len(sent_bodies)}"
        for body in sent_bodies:
            assert body is not None
            assert body.get("prompt") == test_prompt, (
                f"Prompt not found in body: {body!r}"
            )
