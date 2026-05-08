import sqlite3
import os
import time
import hashlib
import logging
import threading

try:
    import firebase_admin
    from firebase_admin import auth as fb_auth, firestore as fb_firestore
    _firebase_available = True
except ImportError:
    firebase_admin = None
    fb_auth = None
    fb_firestore = None
    _firebase_available = False

logger = logging.getLogger(__name__)

_default_db = os.path.join(os.path.dirname(__file__), '..', 'adaptive_cases.db')
DB_PATH = os.environ.get('ADAPTIVE_DB_PATH') or _default_db
_lock = threading.Lock()


# ---------------------------------------------------------------------------
# Firebase helper
# ---------------------------------------------------------------------------

def get_firebase_uid(request):
    """
    Extract and verify the Firebase ID token from the request Authorization header.
    Looks up the user's Firestore record to get role and parentId.

    Returns:
        (uid, role, parent_id) on success
        (None, None, None) on any error — never raises
    """
    if not _firebase_available:
        logger.debug("get_firebase_uid: firebase_admin not installed, returning None")
        return (None, None, None)

    try:
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            print(f"[AUTH] No Bearer header found (got: {auth_header[:30]!r})", flush=True)
            return (None, None, None)

        token = auth_header[len('Bearer '):]
        print(f"[AUTH] Verifying token (first 20 chars): {token[:20]}...", flush=True)
        decoded = fb_auth.verify_id_token(token)
        uid = decoded.get('uid')
        if not uid:
            print("[AUTH] Token verified but uid missing", flush=True)
            return (None, None, None)

        db = fb_firestore.client()
        doc = db.collection('users').document(uid).get()
        if not doc.exists:
            print(f"[AUTH] Firestore user doc not found for uid={uid}", flush=True)
            return (None, None, None)

        data = doc.to_dict()
        role = (data.get('role') or '').lower()
        parent_id = data.get('parentId')
        print(f"[AUTH] uid={uid}, role={role}, parent_id={parent_id}", flush=True)
        return (uid, role, parent_id)

    except Exception as e:
        logger.warning("get_firebase_uid error: %s", e)
        print(f"[AUTH] Exception during token verification: {e}", flush=True)
        return (None, None, None)


# ---------------------------------------------------------------------------
# Database initialisation
# ---------------------------------------------------------------------------

def init_db():
    """
    Create the cases table and indexes if they do not exist.
    On corruption, renames the broken file to .bak and starts fresh.
    Never raises.
    """
    def _create(path):
        conn = sqlite3.connect(path)
        cur = conn.cursor()
        cur.executescript("""
            CREATE TABLE IF NOT EXISTS cases (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                prompt        TEXT    NOT NULL,
                verdict       TEXT    NOT NULL,
                risk_score    REAL    NOT NULL,
                label         INTEGER NOT NULL DEFAULT 1,
                rlhf_label    INTEGER,
                rlhf_pending  INTEGER NOT NULL DEFAULT 0,
                created_at    REAL    NOT NULL,
                child_id      TEXT,
                parent_id     TEXT,
                prompt_hash   TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_prompt_hash  ON cases(prompt_hash);
            CREATE INDEX IF NOT EXISTS idx_parent_id    ON cases(parent_id);
            CREATE INDEX IF NOT EXISTS idx_rlhf_pending ON cases(rlhf_pending);
        """)
        conn.commit()
        conn.close()

    try:
        _create(DB_PATH)
    except sqlite3.DatabaseError as e:
        logger.warning("adaptive_store: DB corrupted (%s). Recreating fresh.", e)
        try:
            bak = DB_PATH + '.bak'
            if os.path.exists(bak):
                os.remove(bak)
            os.rename(DB_PATH, bak)
            _create(DB_PATH)
        except Exception as inner:
            logger.error("adaptive_store: Failed to recreate DB: %s", inner)
    except Exception as e:
        logger.error("adaptive_store: init_db unexpected error: %s", e)


# ---------------------------------------------------------------------------
# Logging cases
# ---------------------------------------------------------------------------

def log_case(prompt, verdict, risk_score, child_id=None, parent_id=None):
    """
    Persist a BLOCK or HESITATE case to the buffer.

    - ALLOW verdict → returns None silently (not stored)
    - Deduplicates within 24 h by prompt_hash
    - Evicts when buffer >= 500 rows
    - HESITATE sets rlhf_pending=1 for parent review
    - BLOCK sets rlhf_pending=0 (auto-labelled)

    Returns:
        int  case_id on success
        None if ALLOW or on error
    """
    try:
        if verdict == 'ALLOW':
            return None

        raw_hash = (prompt + (child_id or '')).encode('utf-8')
        prompt_hash = hashlib.sha256(raw_hash).hexdigest()
        now = time.time()
        cutoff_24h = now - 86400

        with _lock:
            conn = sqlite3.connect(DB_PATH, timeout=10)
            try:
                cur = conn.cursor()

                # Dedup within 24 h — only skip if still unreviewed
                cur.execute(
                    """SELECT id, parent_id FROM cases
                       WHERE prompt_hash=? AND created_at>=?
                         AND rlhf_label IS NULL AND rlhf_pending=1
                       LIMIT 1""",
                    (prompt_hash, cutoff_24h)
                )
                row = cur.fetchone()
                if row:
                    existing_id, existing_parent = row
                    if existing_parent is None and parent_id is not None:
                        cur.execute(
                            "UPDATE cases SET parent_id=? WHERE id=?",
                            (parent_id, existing_id)
                        )
                        conn.commit()
                        print(f"[LOG_CASE] Dedup — updated parent_id for case {existing_id}", flush=True)
                    else:
                        print(f"[LOG_CASE] Dedup — already pending, skipping insert (case {existing_id})", flush=True)
                    return existing_id

                # Evict if at capacity
                cur.execute("SELECT COUNT(*) FROM cases")
                total = cur.fetchone()[0]
                if total >= 500:
                    _evict_buffer_conn(cur)

                rlhf_pending = 1 if verdict == 'HESITATE' else 0

                cur.execute(
                    """INSERT INTO cases
                         (prompt, verdict, risk_score, label, rlhf_pending,
                          created_at, child_id, parent_id, prompt_hash)
                       VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?)""",
                    (prompt, verdict, risk_score, rlhf_pending,
                     now, child_id, parent_id, prompt_hash)
                )
                conn.commit()
                case_id = cur.lastrowid
                return case_id

            finally:
                conn.close()

    except Exception as e:
        logger.error("adaptive_store: log_case error: %s", e)
        return None


def _evict_buffer_conn(cur):
    """
    Delete the 50 oldest unlabelled BLOCK rows.
    Called with an open cursor inside the _lock context.
    Never deletes human-verified rows (rlhf_label IS NOT NULL).
    """
    try:
        cur.execute(
            """DELETE FROM cases WHERE id IN (
                 SELECT id FROM cases
                 WHERE rlhf_label IS NULL AND verdict='BLOCK'
                 ORDER BY created_at ASC
                 LIMIT 50
               )"""
        )
        deleted = cur.rowcount
        logger.info("adaptive_store: evicted %d old BLOCK rows", deleted)
    except Exception as e:
        logger.error("adaptive_store: _evict_buffer error: %s", e)


def _evict_buffer():
    """
    Public-facing eviction (opens its own connection).
    """
    try:
        with _lock:
            conn = sqlite3.connect(DB_PATH, timeout=10)
            try:
                cur = conn.cursor()
                _evict_buffer_conn(cur)
                conn.commit()
            finally:
                conn.close()
    except Exception as e:
        logger.error("adaptive_store: _evict_buffer (standalone) error: %s", e)


# ---------------------------------------------------------------------------
# RLHF labelling
# ---------------------------------------------------------------------------

def update_rlhf_label(case_id, label):
    """
    Apply a human feedback label (0 = safe / false positive, 1 = correctly flagged).

    Returns:
        True  if the row was updated
        False if case_id not found or label invalid
    """
    try:
        if label not in (0, 1):
            logger.warning("adaptive_store: invalid label %r for case %s", label, case_id)
            return False

        with _lock:
            conn = sqlite3.connect(DB_PATH, timeout=10)
            try:
                cur = conn.cursor()
                cur.execute(
                    "UPDATE cases SET rlhf_label=?, rlhf_pending=0 WHERE id=?",
                    (label, case_id)
                )
                conn.commit()
                updated = cur.rowcount > 0
                if not updated:
                    logger.warning("adaptive_store: case_id %s not found", case_id)
                return updated
            finally:
                conn.close()

    except Exception as e:
        logger.error("adaptive_store: update_rlhf_label error: %s", e)
        return False


# ---------------------------------------------------------------------------
# Training data export
# ---------------------------------------------------------------------------

def export_for_training():
    """
    Export cases as a training dataset.

    Label logic:
      - rlhf_label IS NOT NULL  → training_label=rlhf_label, is_human_verified=True,  weight=2
      - rlhf_label IS NULL, age > 48h → training_label=1,           is_human_verified=False, weight=1
      - rlhf_label IS NULL, age <= 48h → SKIP (too recent, may still get human review)

    Returns list of dicts.
    """
    try:
        cutoff_48h = time.time() - 172800
        records = []

        conn = sqlite3.connect(DB_PATH, timeout=10)
        try:
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute(
                """SELECT id, prompt, verdict, risk_score, rlhf_label, created_at
                   FROM cases
                   WHERE rlhf_label IS NOT NULL
                      OR created_at < ?""",
                (cutoff_48h,)
            )
            for row in cur.fetchall():
                if row['rlhf_label'] is not None:
                    training_label = row['rlhf_label']
                    is_human_verified = True
                    weight = 2
                else:
                    # Age > 48h, no human label yet
                    training_label = 1
                    is_human_verified = False
                    weight = 1

                records.append({
                    'case_id': row['id'],
                    'prompt': row['prompt'],
                    'verdict': row['verdict'],
                    'risk_score': row['risk_score'],
                    'training_label': training_label,
                    'is_human_verified': is_human_verified,
                    'weight': weight,
                })
        finally:
            conn.close()

        return records

    except Exception as e:
        logger.error("adaptive_store: export_for_training error: %s", e)
        return []


# ---------------------------------------------------------------------------
# Parent review queue
# ---------------------------------------------------------------------------

def get_pending_cases(parent_id=None):
    """
    Return HESITATE cases awaiting parent review (rlhf_pending=1).
    Optionally filter by parent_id.

    Returns list of {case_id, prompt, risk_score, created_at, child_id}.
    """
    try:
        conn = sqlite3.connect(DB_PATH, timeout=10)
        try:
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()

            if parent_id is not None:
                cur.execute(
                    """SELECT id, prompt, risk_score, created_at, child_id
                       FROM cases
                       WHERE rlhf_pending=1 AND verdict='HESITATE'
                         AND (parent_id=? OR parent_id IS NULL)
                       ORDER BY created_at DESC""",
                    (parent_id,)
                )
            else:
                cur.execute(
                    """SELECT id, prompt, risk_score, created_at, child_id
                       FROM cases
                       WHERE rlhf_pending=1 AND verdict='HESITATE'
                       ORDER BY created_at DESC"""
                )

            return [
                {
                    'case_id': row['id'],
                    'prompt': row['prompt'],
                    'risk_score': row['risk_score'],
                    'created_at': row['created_at'],
                    'child_id': row['child_id'],
                }
                for row in cur.fetchall()
            ]
        finally:
            conn.close()

    except Exception as e:
        logger.error("adaptive_store: get_pending_cases error: %s", e)
        return []


# ---------------------------------------------------------------------------
# Buffer statistics
# ---------------------------------------------------------------------------

def get_buffer_stats():
    """
    Return aggregate statistics about the case buffer.

    Returns dict with keys:
        total_cases, block_count, hesitate_count, pending_rlhf_count,
        human_verified_count, oldest_case_timestamp, newest_case_timestamp
    """
    try:
        conn = sqlite3.connect(DB_PATH, timeout=10)
        try:
            cur = conn.cursor()

            cur.execute("SELECT COUNT(*) FROM cases")
            total = cur.fetchone()[0]

            cur.execute("SELECT COUNT(*) FROM cases WHERE verdict='BLOCK'")
            block_count = cur.fetchone()[0]

            cur.execute("SELECT COUNT(*) FROM cases WHERE verdict='HESITATE'")
            hesitate_count = cur.fetchone()[0]

            cur.execute("SELECT COUNT(*) FROM cases WHERE rlhf_pending=1")
            pending_rlhf_count = cur.fetchone()[0]

            cur.execute("SELECT COUNT(*) FROM cases WHERE rlhf_label IS NOT NULL")
            human_verified_count = cur.fetchone()[0]

            cur.execute("SELECT MIN(created_at), MAX(created_at) FROM cases")
            ts_row = cur.fetchone()
            oldest = ts_row[0]
            newest = ts_row[1]

            return {
                'total_cases': total,
                'block_count': block_count,
                'hesitate_count': hesitate_count,
                'pending_rlhf_count': pending_rlhf_count,
                'human_verified_count': human_verified_count,
                'oldest_case_timestamp': oldest,
                'newest_case_timestamp': newest,
            }
        finally:
            conn.close()

    except Exception as e:
        logger.error("adaptive_store: get_buffer_stats error: %s", e)
        return {
            'total_cases': 0,
            'block_count': 0,
            'hesitate_count': 0,
            'pending_rlhf_count': 0,
            'human_verified_count': 0,
            'oldest_case_timestamp': None,
            'newest_case_timestamp': None,
        }


# ---------------------------------------------------------------------------
# Auto-promotion of expired HESITATE cases
# ---------------------------------------------------------------------------

def promote_expired_hesitate_cases():
    """
    Any HESITATE case older than 48 h that still has no human label
    is automatically promoted to rlhf_label=1 (treat as correctly flagged).

    Returns the count of rows promoted.
    """
    try:
        cutoff = time.time() - 172800  # 48 h

        with _lock:
            conn = sqlite3.connect(DB_PATH, timeout=10)
            try:
                cur = conn.cursor()
                cur.execute(
                    """UPDATE cases
                       SET rlhf_label=1, rlhf_pending=0
                       WHERE verdict='HESITATE'
                         AND rlhf_pending=1
                         AND created_at < ?""",
                    (cutoff,)
                )
                conn.commit()
                count = cur.rowcount
                if count > 0:
                    logger.info(
                        "adaptive_store: promoted %d expired HESITATE cases to rlhf_label=1",
                        count
                    )
                return count
            finally:
                conn.close()

    except Exception as e:
        logger.error("adaptive_store: promote_expired_hesitate_cases error: %s", e)
        return 0


# ---------------------------------------------------------------------------
# Background jobs
# ---------------------------------------------------------------------------

def start_background_jobs():
    """
    Kick off recurring background maintenance:
      - Runs promote_expired_hesitate_cases() immediately
      - Reschedules itself every 3600 seconds (1 hour)
    Never crashes the process on exception.
    """
    def _job():
        try:
            promote_expired_hesitate_cases()
        except Exception as e:
            logger.error("adaptive_store: background job error: %s", e)
        finally:
            try:
                t = threading.Timer(3600, _job)
                t.daemon = True
                t.start()
            except Exception as e:
                logger.error("adaptive_store: failed to reschedule background job: %s", e)

    try:
        _job()
    except Exception as e:
        logger.error("adaptive_store: start_background_jobs error: %s", e)


# ---------------------------------------------------------------------------
# Module-level initialisation
# ---------------------------------------------------------------------------

init_db()
