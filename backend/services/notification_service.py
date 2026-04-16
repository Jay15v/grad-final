"""
Parent Notification Service.

Persists a record to SQLite whenever a cross-model consensus check returns
a DISAGREEMENT verdict, flagging the interaction for parental review.
"""

from __future__ import annotations

import logging
import os
import sqlite3
from datetime import datetime, timezone

# Default DB path: <backend_root>/parent_notifications.db
DB_PATH = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "parent_notifications.db")
)

_CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS parent_notifications (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    child_id      TEXT,
    prompt        TEXT,
    verdict       TEXT,
    display_label TEXT,
    avg_agreement REAL,
    timestamp     TEXT
)
"""


def _ensure_table(conn: sqlite3.Connection) -> None:
    """
    Create the parent_notifications table if it does not already exist.

    Args:
        conn: An open SQLite connection.
    """
    conn.execute(_CREATE_TABLE_SQL)
    conn.commit()


def notify_parent_if_needed(
    child_id: str,
    prompt: str,
    result: dict,
    db_path: str = None,
) -> None:
    """
    Insert a parent notification record when the consensus verdict is DISAGREEMENT.

    Only DISAGREEMENT triggers a write; CONSENSUS and PARTIAL are silently ignored.
    The table is created automatically if it does not yet exist.

    Args:
        child_id: Firebase UID of the child who sent the prompt.
        prompt:   The original user message.
        result:   Dict returned by cross_model_validate() — must contain
                  'verdict', 'display_label', and 'avg_agreement' keys.
        db_path:  Optional override for the SQLite file path.  Useful for
                  tests that pass ':memory:' or a temp-file path.
    """
    if result.get("verdict") != "DISAGREEMENT":
        return

    path = db_path if db_path is not None else DB_PATH
    conn = sqlite3.connect(path)
    try:
        _ensure_table(conn)
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
        conn.execute(
            """
            INSERT INTO parent_notifications
                (child_id, prompt, verdict, display_label, avg_agreement, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                child_id,
                prompt,
                result["verdict"],
                result.get("display_label", ""),
                result.get("avg_agreement", 0.0),
                timestamp,
            ),
        )
        conn.commit()
        logging.info(
            "[NOTIFICATION] DISAGREEMENT logged — child_id=%s, avg_agreement=%.2f",
            child_id,
            result.get("avg_agreement", 0.0),
        )
    finally:
        conn.close()
