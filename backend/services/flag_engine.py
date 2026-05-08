"""
Flag engine: called on bad feedback to classify what went wrong and write
diagnostic flags to the Firestore admin_flags collection.

Flag types:
  HALLUCINATION_CONFIRMED — models disagreed, user confirmed bad output
  FALSE_CONSENSUS         — models agreed, RAG evidence was weak
  RAG_WEAK                — models agreed, RAG found evidence but output still bad
  LLM_DEGRADED            — auto-generated when HALLUCINATION_CONFIRMED > 5 in 24h
"""
import logging
import threading
import time

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import firestore as fb_firestore
    _firebase_available = True
except ImportError:
    fb_firestore = None
    _firebase_available = False

_DEFAULT_CONSENSUS_THRESHOLD = 0.60
_DEFAULT_RAG_THRESHOLD       = 0.50
_SURGE_LIMIT                 = 5
_SURGE_WINDOW                = 86400   # 24 hours in seconds


# ---------------------------------------------------------------------------
# Firestore system_config reader
# ---------------------------------------------------------------------------

def _get_system_config() -> dict:
    """
    Read consensus_threshold and rag_threshold from
    Firestore system_config/thresholds. Falls back to hardcoded defaults
    if Firestore is unavailable or the document does not exist.
    """
    defaults = {
        "consensus_threshold": _DEFAULT_CONSENSUS_THRESHOLD,
        "rag_threshold":       _DEFAULT_RAG_THRESHOLD,
    }
    if not _firebase_available:
        return defaults
    try:
        db  = fb_firestore.client()
        doc = db.collection("system_config").document("thresholds").get()
        if doc.exists:
            data = doc.to_dict()
            return {
                "consensus_threshold": float(
                    data.get("consensus_threshold", _DEFAULT_CONSENSUS_THRESHOLD)
                ),
                "rag_threshold": float(
                    data.get("rag_threshold", _DEFAULT_RAG_THRESHOLD)
                ),
            }
    except Exception as exc:
        logger.warning("flag_engine: could not read system_config: %s", exc)
    return defaults


# ---------------------------------------------------------------------------
# Flag type logic
# ---------------------------------------------------------------------------

def _determine_flag_type(
    verdict: str | None,
    avg_agreement: float | None,
    rag_hit_rate: float | None,
    consensus_threshold: float,
    rag_threshold: float,
) -> str:
    """
    Classify why the session was bad.

    Uses avg_agreement against the live threshold (from Firestore) rather
    than the stored verdict string, so admin threshold changes take effect
    immediately on new flags.

    Falls back to the stored verdict string when avg_agreement is None
    (e.g. pipeline timed out before consensus finished).
    """
    if avg_agreement is not None:
        is_consensus = avg_agreement >= consensus_threshold
    else:
        # verdict string computed at pipeline time with its own threshold
        is_consensus = (verdict == "CONSENSUS")

    if not is_consensus:
        return "HALLUCINATION_CONFIRMED"

    # Models agreed — was RAG strong enough to catch the error?
    rag_strong = rag_hit_rate is not None and rag_hit_rate >= rag_threshold
    return "RAG_WEAK" if rag_strong else "FALSE_CONSENSUS"


# ---------------------------------------------------------------------------
# Surge detector
# ---------------------------------------------------------------------------

def _check_hallucination_surge(db) -> None:
    """
    Count HALLUCINATION_CONFIRMED flags in the last 24 h.
    If the count exceeds _SURGE_LIMIT and no open LLM_DEGRADED flag exists,
    write one automatically.

    Uses single-field equality queries only to avoid composite index
    requirements in Firestore.
    """
    try:
        cutoff = time.time() - _SURGE_WINDOW

        # Fetch all HALLUCINATION_CONFIRMED flags and count recent ones in Python
        all_flags = (
            db.collection("admin_flags")
            .where("flag_type", "==", "HALLUCINATION_CONFIRMED")
            .stream()
        )
        count = sum(
            1 for f in all_flags
            if f.to_dict().get("created_at", 0) >= cutoff
        )
        logger.info("flag_engine: HALLUCINATION_CONFIRMED in last 24h: %d", count)

        if count <= _SURGE_LIMIT:
            return

        # Only write LLM_DEGRADED if none is already open
        existing = (
            db.collection("admin_flags")
            .where("flag_type", "==", "LLM_DEGRADED")
            .stream()
        )
        has_open = any(not f.to_dict().get("resolved", True) for f in existing)
        if has_open:
            return

        db.collection("admin_flags").add({
            "flag_type":               "LLM_DEGRADED",
            "reason":                  (
                f"HALLUCINATION_CONFIRMED flags exceeded {_SURGE_LIMIT} "
                f"in 24h (count={count})"
            ),
            "hallucination_count_24h": count,
            "resolved":                False,
            "created_at":              time.time(),
        })
        logger.warning(
            "flag_engine: LLM_DEGRADED auto-flag written (count=%d)", count
        )

    except Exception as exc:
        logger.warning("flag_engine: surge check failed: %s", exc)


# ---------------------------------------------------------------------------
# Core runner (executes in a background thread)
# ---------------------------------------------------------------------------

def _run(session_id: str, user_id: str, pipeline_id: str | None, pipeline_store: dict, message: str | None = None) -> None:
    try:
        if not _firebase_available or not firebase_admin._apps:
            logger.debug("flag_engine: firebase not initialised, skipping")
            return

        # ── Pull pipeline data ────────────────────────────────────────────
        entry = pipeline_store.get(pipeline_id) if pipeline_id else None

        verdict       = None
        avg_agreement = None
        rag_hit_rate  = None

        if entry:
            verdict       = entry.get("verdict")
            avg_agreement = entry.get("avg_agreement")
            try:
                rag_hit_rate = (
                    entry
                    .get("stages", {})
                    .get("rag",    {})
                    .get("data",   {})
                    .get("rag_eval", {})
                    .get("hit_rate")
                )
            except Exception:
                pass

        # ── Load live thresholds ──────────────────────────────────────────
        config = _get_system_config()

        flag_type = _determine_flag_type(
            verdict, avg_agreement, rag_hit_rate,
            config["consensus_threshold"],
            config["rag_threshold"],
        )

        # ── Write flag document ───────────────────────────────────────────
        db = fb_firestore.client()
        db.collection("admin_flags").add({
            "session_id":     session_id,
            "user_id":        user_id,
            "pipeline_id":    pipeline_id,
            "flag_type":      flag_type,
            "verdict":        verdict,
            "avg_agreement":  avg_agreement,
            "rag_hit_rate":   rag_hit_rate,
            "prompt_snippet": (message or "")[:200] if message else None,
            "rating":         "bad",
            "resolved":       False,
            "created_at":     time.time(),
        })
        logger.info(
            "flag_engine: wrote %s flag for session=%s pipeline=%s",
            flag_type, session_id, pipeline_id,
        )

        # ── Surge check (only worthwhile for hallucination flags) ─────────
        if flag_type == "HALLUCINATION_CONFIRMED":
            _check_hallucination_surge(db)

    except Exception as exc:
        logger.error("flag_engine: unhandled error: %s", exc)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def run_flag_engine(
    session_id: str,
    user_id: str,
    pipeline_id: str | None,
    pipeline_store: dict,
    message: str | None = None,
) -> None:
    """
    Dispatch the flag engine in a daemon thread so the HTTP response
    to the user is not blocked.
    """
    threading.Thread(
        target=_run,
        args=(session_id, user_id, pipeline_id, pipeline_store, message),
        daemon=True,
    ).start()
