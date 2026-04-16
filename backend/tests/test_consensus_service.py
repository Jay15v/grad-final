"""
Tests for consensus_service.cross_model_validate.

All ML model loading and HTTP calls are mocked — Ollama and SBERT
do NOT need to be running.

The sys.modules stubs must be installed before the module under test is
imported so that 'from services.semantic_services import sbert' and
'from sentence_transformers import util' never touch the real packages.
"""

import sys
import contextlib
import pytest
from unittest.mock import MagicMock, patch

# ── Intercept heavy imports before consensus_service is loaded ────────────────

# 1. Stub sentence_transformers so 'from sentence_transformers import util' works
_mock_util          = MagicMock()
_mock_st_module     = MagicMock()
_mock_st_module.util = _mock_util
sys.modules.setdefault("sentence_transformers", _mock_st_module)

# 2. Stub semantic_services so 'from services.semantic_services import sbert' works
_mock_sbert              = MagicMock()
_mock_semantic_module    = MagicMock()
_mock_semantic_module.sbert = _mock_sbert
sys.modules["services.semantic_services"] = _mock_semantic_module

# ── Now safe to import the module under test ──────────────────────────────────
import services.consensus_service as cs   # noqa: E402 (module-level stub required first)


# ── Helpers ───────────────────────────────────────────────────────────────────

_ALL_MODELS_OK = {
    "phi3":    "Paris is the capital of France.",
    "llama3":  "The capital of France is Paris.",
    "mistral": "France's capital city is Paris.",
}

_REQUIRED_KEYS = {"verdict", "display_label", "avg_agreement", "pairs", "responses"}


def _make_cos_sim_mock(fixed_score: float) -> MagicMock:
    """Return a mock that mimics util.cos_sim(a, b).item() == fixed_score."""
    inner = MagicMock()
    inner.item.return_value = fixed_score
    m = MagicMock(return_value=inner)
    return m


def _run(mock_responses: dict, cos_score: float) -> dict:
    """
    Helper: patch query_all_models + sbert.encode + util.cos_sim, then call
    cross_model_validate and return the result.
    """
    # sbert.encode returns a distinct numpy vector per call so identity checks pass
    call_count = {"n": 0}

    def fake_encode(text, normalize_embeddings=True):
        call_count["n"] += 1
        return [float(call_count["n"]), 0.0]  # plain list; cos_sim is also mocked

    with contextlib.ExitStack() as stack:
        stack.enter_context(patch.object(cs, "query_all_models", return_value=mock_responses))
        stack.enter_context(patch.object(cs, "sbert", new=MagicMock(encode=fake_encode)))
        stack.enter_context(patch.object(cs, "util",  new=MagicMock(cos_sim=_make_cos_sim_mock(cos_score))))
        return cs.cross_model_validate("What is the capital of France?")


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestConsensusVerdict:
    """Verdict mapping tests."""

    def test_consensus_verdict(self):
        """avg ≥ 0.75 → CONSENSUS / 'Consensus'."""
        result = _run(_ALL_MODELS_OK, cos_score=0.82)
        assert result["verdict"] == "CONSENSUS"
        assert result["display_label"] == "Consensus"

    def test_partial_verdict(self):
        """0.50 ≤ avg < 0.75 → PARTIAL / 'Partially Hallucinating'."""
        result = _run(_ALL_MODELS_OK, cos_score=0.61)
        assert result["verdict"] == "PARTIAL"
        assert result["display_label"] == "Partially Hallucinating"

    def test_disagreement_verdict(self):
        """avg < 0.50 → DISAGREEMENT / 'High Risk of Hallucination'."""
        result = _run(_ALL_MODELS_OK, cos_score=0.34)
        assert result["verdict"] == "DISAGREEMENT"
        assert result["display_label"] == "High Risk of Hallucination"

    def test_threshold_boundary_consensus(self):
        """Exactly 0.75 must map to CONSENSUS (>= threshold)."""
        result = _run(_ALL_MODELS_OK, cos_score=0.75)
        assert result["verdict"] == "CONSENSUS"

    def test_threshold_boundary_disagreement(self):
        """Exactly 0.49 must map to DISAGREEMENT (< THRESHOLD_PARTIAL = 0.50)."""
        result = _run(_ALL_MODELS_OK, cos_score=0.49)
        assert result["verdict"] == "DISAGREEMENT"


class TestReturnShape:
    """Shape / type guarantees on the returned dict."""

    def test_return_dict_has_all_keys(self):
        """The returned dict must always contain all 5 required keys."""
        result = _run(_ALL_MODELS_OK, cos_score=0.80)
        assert _REQUIRED_KEYS.issubset(result.keys())

    def test_avg_agreement_is_float(self):
        """avg_agreement must be a Python float."""
        result = _run(_ALL_MODELS_OK, cos_score=0.70)
        assert isinstance(result["avg_agreement"], float)

    def test_pairs_contains_three_entries(self):
        """When all three models respond, pairs must contain exactly 3 tuples."""
        result = _run(_ALL_MODELS_OK, cos_score=0.80)
        assert len(result["pairs"]) == 3

    def test_responses_key_matches_model_output(self):
        """responses must be the exact dict returned by query_all_models."""
        result = _run(_ALL_MODELS_OK, cos_score=0.80)
        assert result["responses"] == _ALL_MODELS_OK


class TestDegradedMode:
    """Graceful handling when one model returns an error."""

    def test_degraded_two_models_only(self):
        """
        When one model returns an error string the function must not crash.
        All 5 keys must still be present in the returned dict.
        """
        degraded_responses = {
            "phi3":    "Paris is the capital of France.",
            "llama3":  "Error: connection refused",   # capital-E error string
            "mistral": "France's capital city is Paris.",
        }
        result = _run(degraded_responses, cos_score=0.80)
        assert _REQUIRED_KEYS.issubset(result.keys())
        # Only 1 valid pair (phi3 ↔ mistral)
        assert len(result["pairs"]) == 1

    def test_degraded_all_keys_present(self):
        """
        Even when one model errors, all 5 keys are present and
        avg_agreement is still a float.
        """
        degraded_responses = {
            "phi3":    "Paris is the capital of France.",
            "llama3":  "error: timeout",
            "mistral": "France's capital city is Paris.",
        }
        result = _run(degraded_responses, cos_score=0.78)
        assert _REQUIRED_KEYS.issubset(result.keys())
        assert isinstance(result["avg_agreement"], float)
