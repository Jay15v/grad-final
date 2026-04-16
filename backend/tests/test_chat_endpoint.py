"""
Tests for the /api/chat endpoint.

All ML models, Ollama calls, Firebase, and consensus validation are mocked.
The sys.modules stubs must be installed *before* app2 is imported so that
none of the heavy service initialisation code runs.
"""

import sys
import json
import contextlib
import os
import pytest
from unittest.mock import MagicMock, patch

# ─── Pre-mock every heavy/external module before app2 is imported ─────────────

# Helper: install a MagicMock for a module name if not already present.
def _stub(name, **attrs):
    m = sys.modules.get(name)
    if m is None or not isinstance(m, MagicMock):
        m = MagicMock(**attrs)
        sys.modules[name] = m
    return m

for _name in [
    "dotenv",
    "firebase_admin",
    "firebase_admin.credentials",
    "firebase_admin.auth",
    "services.fusion_services",
    "services.model_services",
    "services.semantic_services",
    "services.llm_service",
    "services.decomposition_service",
    "services.reasoning_service",
    "services.rag_service",
    "services.consensus_service",
    "services.notification_service",
    "sentence_transformers",
]:
    _stub(_name)

# adaptive_store — needs specific callable return values used at import time
_adaptive = _stub("services.adaptive_store")
_adaptive.init_db = MagicMock()
_adaptive.start_background_jobs = MagicMock()
_adaptive.get_firebase_uid = MagicMock(return_value=("uid123", "child", None))
_adaptive.log_case = MagicMock(return_value=42)
_adaptive.get_pending_cases = MagicMock(return_value=[])
_adaptive.get_buffer_stats = MagicMock(return_value={})
_adaptive.update_rlhf_label = MagicMock(return_value=True)

# retrain_bert — retrain_state must be a subscriptable dict
_retrain = _stub("services.retrain_bert")
_retrain.retrain_state = {
    "status": "idle", "message": "",
    "last_f1_before": None, "last_f1_after": None,
}
_retrain.check_trigger_conditions = MagicMock(return_value=(False, ""))
_retrain.run_retraining = MagicMock()

# ─── Now safe to import the Flask app ─────────────────────────────────────────
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import app2  # noqa: E402

# ─── Shared test data ─────────────────────────────────────────────────────────

_ALLOW_DEFENSE = {
    "decision": "ALLOW",
    "bert_risk": 0.05,
    "semantic_domain": None,
    "semantic_similarity": 0.0,
    "final_risk": 0.05,
}

_CONSENSUS_RESULT = {
    "verdict": "CONSENSUS",
    "display_label": "Consensus",
    "avg_agreement": 0.82,
    "pairs": [],
    "responses": {},
}

_DISAGREEMENT_RESULT = {
    "verdict": "DISAGREEMENT",
    "display_label": "High Risk of Hallucination",
    "avg_agreement": 0.32,
    "pairs": [],
    "responses": {},
}

# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def client():
    app2.app.config["TESTING"] = True
    with app2.app.test_client() as c:
        yield c


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _post_chat(client, message="What is the capital of France?"):
    """Send a POST to /api/chat and return the response."""
    return client.post(
        "/api/chat",
        data=json.dumps({"message": message, "history": []}),
        content_type="application/json",
    )


def _route_patches(validate_result, notify_mock=None):
    """
    Return an ExitStack that patches all functions called by the /api/chat route.

    This prevents real Ollama calls, real BERT inference, and real thread creation.
    """
    stack = contextlib.ExitStack()
    stack.enter_context(patch("app2._defense_check", return_value=_ALLOW_DEFENSE))
    stack.enter_context(patch("app2.call_ollama_chat", return_value="Paris is the capital."))
    stack.enter_context(patch("app2.cross_model_validate", return_value=validate_result))
    stack.enter_context(
        patch("app2.notify_parent_if_needed", new=notify_mock or MagicMock())
    )
    stack.enter_context(patch("app2.threading.Thread"))  # prevent background pipeline
    return stack


# ─── Tests ────────────────────────────────────────────────────────────────────

class TestChatEndpointVerdict:
    """Verify that the /api/chat endpoint exposes the verdict from consensus."""

    def test_verdict_key_in_response(self, client):
        """Response JSON must contain a 'verdict' key."""
        with _route_patches(_CONSENSUS_RESULT):
            resp = _post_chat(client)
        assert "verdict" in resp.get_json()

    def test_display_label_in_response(self, client):
        """Response JSON must contain a 'display_label' key."""
        with _route_patches(_CONSENSUS_RESULT):
            resp = _post_chat(client)
        assert "display_label" in resp.get_json()

    def test_avg_agreement_in_response(self, client):
        """Response JSON must contain an 'avg_agreement' key."""
        with _route_patches(_CONSENSUS_RESULT):
            resp = _post_chat(client)
        assert "avg_agreement" in resp.get_json()

    def test_disagreement_triggers_notification(self, client):
        """notify_parent_if_needed must be called exactly once on DISAGREEMENT."""
        mock_notify = MagicMock()
        with _route_patches(_DISAGREEMENT_RESULT, notify_mock=mock_notify):
            _post_chat(client)
        mock_notify.assert_called_once()

    def test_consensus_does_not_trigger_notification(self, client):
        """notify_parent_if_needed must NOT be called when verdict is CONSENSUS."""
        mock_notify = MagicMock()
        with _route_patches(_CONSENSUS_RESULT, notify_mock=mock_notify):
            _post_chat(client)
        mock_notify.assert_not_called()
