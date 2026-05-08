import sqlite3
import os
import time
import logging

logger = logging.getLogger(__name__)

_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'session_feedback.db')


def init_feedback_db():
    try:
        conn = sqlite3.connect(_DB_PATH)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS session_feedback (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id  TEXT    NOT NULL,
                user_id     TEXT,
                rating      TEXT    NOT NULL,
                verdict     TEXT,
                pipeline_id TEXT,
                created_at  REAL    NOT NULL
            )
        """)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_sf_session ON session_feedback(session_id)"
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_sf_user    ON session_feedback(user_id)"
        )
        conn.commit()
        conn.close()
    except Exception as e:
        logger.error("feedback_store: init failed: %s", e)


def save_session_feedback(session_id, user_id, rating, verdict, pipeline_id):
    try:
        conn = sqlite3.connect(_DB_PATH)
        conn.execute(
            """INSERT INTO session_feedback
               (session_id, user_id, rating, verdict, pipeline_id, created_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (session_id, user_id, rating, verdict, pipeline_id, time.time()),
        )
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        logger.error("feedback_store: save failed: %s", e)
        return False
