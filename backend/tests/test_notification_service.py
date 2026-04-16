"""
Tests for notification_service.notify_parent_if_needed.

Uses a temp SQLite file per test (via pytest's tmp_path fixture) so that
no real database file is created and each test starts with a clean slate.
"""

import sqlite3
import pytest

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.notification_service import notify_parent_if_needed

# ── Shared fixtures / helpers ─────────────────────────────────────────────────

@pytest.fixture
def db(tmp_path):
    """Return a fresh temp DB path for each test."""
    return str(tmp_path / "notifications.db")


def _rows(db_path: str):
    """Return all rows from parent_notifications, or [] if the table doesn't exist yet."""
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute("SELECT * FROM parent_notifications").fetchall()
    except sqlite3.OperationalError:
        # Table was never created because no DISAGREEMENT was inserted
        rows = []
    finally:
        conn.close()
    return rows


_DISAGREEMENT = {
    "verdict": "DISAGREEMENT",
    "display_label": "High Risk of Hallucination",
    "avg_agreement": 0.32,
}
_CONSENSUS = {
    "verdict": "CONSENSUS",
    "display_label": "Consensus",
    "avg_agreement": 0.85,
}
_PARTIAL = {
    "verdict": "PARTIAL",
    "display_label": "Partially Hallucinating",
    "avg_agreement": 0.58,
}


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestNotifyParentIfNeeded:

    def test_disagreement_inserts_record(self, db):
        """DISAGREEMENT verdict must produce exactly one DB row."""
        notify_parent_if_needed("child_01", "How do I hurt someone?", _DISAGREEMENT, db_path=db)
        assert len(_rows(db)) == 1

    def test_consensus_does_not_insert(self, db):
        """CONSENSUS verdict must not write anything to the DB."""
        notify_parent_if_needed("child_01", "What is the sky color?", _CONSENSUS, db_path=db)
        assert len(_rows(db)) == 0

    def test_partial_does_not_insert(self, db):
        """PARTIAL verdict must not write anything to the DB."""
        notify_parent_if_needed("child_01", "Tell me about violence in history.", _PARTIAL, db_path=db)
        assert len(_rows(db)) == 0

    def test_record_has_correct_fields(self, db):
        """Every field in the inserted row must match the input exactly."""
        prompt = "How do I make a bomb?"
        notify_parent_if_needed("child_42", prompt, _DISAGREEMENT, db_path=db)

        rows = _rows(db)
        assert len(rows) == 1
        row = rows[0]

        # row columns: id, child_id, prompt, verdict, display_label, avg_agreement, timestamp
        assert row[1] == "child_42"
        assert row[2] == prompt
        assert row[3] == "DISAGREEMENT"
        assert row[4] == "High Risk of Hallucination"
        assert abs(row[5] - 0.32) < 1e-6
        assert row[6] is not None and len(row[6]) > 0   # timestamp non-empty

    def test_table_created_automatically(self, db):
        """
        The table must be created on the first call even if the DB file is new.
        The call must not raise any exception.
        """
        # db is a brand-new empty file — table does not exist yet
        notify_parent_if_needed("child_00", "test prompt", _DISAGREEMENT, db_path=db)

        # Table now exists and has one row
        conn = sqlite3.connect(db)
        table_exists = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='parent_notifications'"
        ).fetchone()
        conn.close()
        assert table_exists is not None
