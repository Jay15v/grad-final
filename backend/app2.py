import threading
import uuid
import sqlite3
import logging
import requests as req_lib

# Step 1 & 2: load .env FIRST so all os.environ.get() calls below see the values
from dotenv import load_dotenv
import os
load_dotenv()

from flask import Flask, request, jsonify
from flask_cors import CORS

from services.fusion_services import fuse_prompt
from services.model_services import bert_predict
from services.semantic_services import semantic_risk
from services.llm_service import call_ollama_chat, call_ollama_block_fallback
from services.decomposition_service import decompose_prompt
from services.reasoning_service import generate_reasoning_from_steps, generate_claims_from_reasoning
from services.rag_service import verify_claims_with_rag_google

# Step 3 & 4: import firebase_admin after env is loaded
try:
    import firebase_admin
    from firebase_admin import credentials
    _firebase_available = True
except ImportError:
    firebase_admin = None
    credentials = None
    _firebase_available = False
    logging.warning("firebase_admin not installed — token verification disabled")

# Step 5, 6, 7: initialize Firebase from JSON env var (Railway) or file path (local)
if _firebase_available:
    try:
        if not firebase_admin._apps:
            sa_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
            if sa_json:
                import json
                cred = credentials.Certificate(json.loads(sa_json))
                firebase_admin.initialize_app(cred)
                print("✅ Firebase Admin initialized from env var")
            else:
                sa_path = os.environ.get('FIREBASE_SERVICE_ACCOUNT_PATH')
                if sa_path and not os.path.isabs(sa_path):
                    sa_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), sa_path)
                if sa_path and os.path.exists(sa_path):
                    cred = credentials.Certificate(sa_path)
                    firebase_admin.initialize_app(cred)
                    print("✅ Firebase Admin initialized from file")
                else:
                    logging.warning(f"Firebase: no JSON env var and no file at: {sa_path}")
    except Exception as e:
        logging.warning(f"Firebase Admin init failed: {e}")

from services.consensus_service import cross_model_validate
from services.notification_service import notify_parent_if_needed

from services.adaptive_store import (
    init_db, log_case, update_rlhf_label,
    get_pending_cases, get_buffer_stats,
    get_firebase_uid, start_background_jobs
)
from services.feedback_store import init_feedback_db, save_session_feedback
from services.flag_engine import run_flag_engine
from services.retrain_bert import retrain_state, run_retraining, check_trigger_conditions

app = Flask(__name__)

CORS(
    app,
    resources={r"/api/*": {"origins": "*"}},
    supports_credentials=False,
    allow_headers=["Content-Type", "Authorization"],
    methods=["GET", "POST", "OPTIONS"],
)

import os as _os
if _os.environ.get('WERKZEUG_RUN_MAIN') == 'true' or not app.debug:
    init_db()
    init_feedback_db()
    start_background_jobs()

BLOCK_THRESHOLD = 0.60
HESITATE_THRESHOLD = 0.15
RAG_ENABLED = bool(os.getenv("GOOGLE_CSE_API_KEY") and os.getenv("GOOGLE_CSE_ID"))

# In-memory store for background pipeline results
pipeline_store: dict = {}


# ------------------------------------------------------------------
# Helper: run the quick defense check
# ------------------------------------------------------------------
def _defense_check(message: str) -> dict:
    print("[DEFENSE_CHECK] loaded version with threshold=0.50", flush=True)
    bert_risk = bert_predict(message)
    final_risk = bert_risk
    semantic_domain, semantic_similarity = semantic_risk(message)

    if semantic_domain == "roleplay_jailbreak":
        final_risk = max(bert_risk * 0.65, 0.35)
    elif semantic_domain == "direct_injection":
        final_risk = max(bert_risk * 1.2, 0.50)
    elif semantic_domain == "obfuscation_payload":
        final_risk = max(bert_risk * 1.3, 0.55)
    elif semantic_domain == "virtualization_hypotheticals":
        final_risk = bert_risk * 0.45
    elif semantic_domain == "violence_intent":
        final_risk = max(bert_risk * 1.5, 0.65)
    elif semantic_domain == "self_harm":
        final_risk = max(bert_risk * 1.5, 0.65)
    elif semantic_domain == "dangerous_weapons":
        final_risk = max(bert_risk * 1.4, 0.65)
    elif semantic_domain == "direct_harm":
        if semantic_similarity < 0.65:
            final_risk = bert_risk * 0.55   # weak match → hesitate
        else:
            final_risk = max(bert_risk * 1.2, 0.40)  # strong match → amplify
    elif semantic_domain == "parental_control_bypass":
        final_risk = max(bert_risk * 1.2, 0.40)
    elif semantic_domain == "technical_exploit":
        final_risk = bert_risk * 0.55
    elif semantic_domain == "social_engineering":
        final_risk = bert_risk * 0.55
    elif semantic_domain == "educational_security":
        final_risk = bert_risk * 0.30

    if final_risk >= BLOCK_THRESHOLD:
        decision = "BLOCK"
    elif final_risk >= HESITATE_THRESHOLD:
        decision = "HESITATE"
    else:
        decision = "ALLOW"

    return {
        "decision": decision,
        "bert_risk": round(bert_risk, 3),
        "semantic_domain": semantic_domain,
        "semantic_similarity": round(semantic_similarity, 3),
        "final_risk": round(final_risk, 3),
    }


# ------------------------------------------------------------------
# Helper: run full pipeline in a background thread
# ------------------------------------------------------------------
def _run_consensus(entry: dict, message: str, child_id: str):
    """Runs cross-model consensus after pipeline stages. Sets status='done' when complete."""
    try:
        consensus_result = cross_model_validate(message)
        entry["verdict"]        = consensus_result.get("verdict")
        entry["display_label"]  = consensus_result.get("display_label")
        entry["avg_agreement"]  = consensus_result.get("avg_agreement")
        entry["model_statuses"] = consensus_result.get("model_statuses")
        if consensus_result.get("verdict") == "DISAGREEMENT":
            notify_parent_if_needed(child_id, message, consensus_result)
    except Exception as e:
        logging.warning(f"consensus validation failed: {e}")
    finally:
        entry["status"] = "done"  # Flutter stops polling only after consensus finishes


def _run_pipeline(pipeline_id: str, message: str, child_id: str = "anonymous"):
    entry = pipeline_store[pipeline_id]
    print(f"[PIPELINE] Starting for message: {message[:60]!r}", flush=True)

    # Stage 1 – decomposition
    try:
        entry["stages"]["decomposition"] = {"status": "running"}
        decomposition = decompose_prompt(message)
        entry["stages"]["decomposition"] = {"status": "done", "data": decomposition}
    except Exception as e:
        decomposition = {"steps": [], "constraints": {}, "quality": {"score": 0.0}}
        entry["stages"]["decomposition"] = {"status": "done", "data": decomposition, "error": str(e)}

    steps = decomposition.get("steps", [])

    # Stage 2 – reasoning
    try:
        entry["stages"]["reasoning"] = {"status": "running"}
        reasoning = generate_reasoning_from_steps(steps=steps, original_prompt=message)
        entry["stages"]["reasoning"] = {"status": "done", "data": reasoning}
    except Exception as e:
        reasoning = []
        entry["stages"]["reasoning"] = {"status": "done", "data": [], "error": str(e)}

    # Stage 3 – claims (fast, no status needed)
    try:
        claims = generate_claims_from_reasoning(reasoning) or []
        entry["stages"]["claims"] = {"status": "done", "data": claims}
    except Exception:
        claims = []
        entry["stages"]["claims"] = {"status": "done", "data": []}

    # Stage 4 – RAG
    try:
        entry["stages"]["rag"] = {"status": "running"}
        print(f"[RAG] RAG_ENABLED={RAG_ENABLED}, claims_count={len(claims)}", flush=True)
        if claims and RAG_ENABLED:
            rag_results = verify_claims_with_rag_google(claims, k=5, refresh_web=True) or {
                "results": [], "rag_eval": {"total_steps": 0, "hits": 0, "misses": 0, "hit_rate": 0.0}
            }
        else:
            print(f"[RAG] Skipped — RAG_ENABLED={RAG_ENABLED}, claims={claims}", flush=True)
            rag_results = {
                "results": [],
                "rag_eval": {"total_steps": 0, "hits": 0, "misses": 0, "hit_rate": 0.0},
            }
        entry["stages"]["rag"] = {"status": "done", "data": rag_results}
    except Exception as e:
        entry["stages"]["rag"] = {
            "status": "done",
            "data": {"results": [], "rag_eval": {}},
            "error": str(e),
        }

    # Pipeline stages done — keep status as "pipeline_done" so Flutter keeps polling
    # while consensus runs. Consensus will set status to "done" when it finishes.
    entry["status"] = "pipeline_done"

    # Cross-model runs AFTER pipeline so it doesn't compete with reasoning for Ollama
    threading.Thread(
        target=_run_consensus, args=(entry, message, child_id), daemon=True
    ).start()


# ------------------------------------------------------------------
# Existing endpoint
# ------------------------------------------------------------------
@app.route("/api/analyze", methods=["POST", "OPTIONS"])
def analyze():
    if request.method == "OPTIONS":
        return ("", 204)

    uid, role, parent_id = get_firebase_uid(request)
    child_id = uid if role == 'child' else None

    data = request.get_json(force=True)
    prompt = (data.get("prompt") or "").strip()

    if not prompt:
        return jsonify({"error": "Empty prompt"}), 400

    result = fuse_prompt(prompt)

    verdict = result.get('status', 'ALLOW')
    risk_score = result.get('decision_meta', {}).get('final_risk', 0.0)
    case_id = None
    try:
        case_id = log_case(prompt, verdict, risk_score, child_id, parent_id)
    except Exception as e:
        logging.warning(f"log_case failed: {e}")

    result['case_id'] = case_id
    if verdict == 'HESITATE' and parent_id:
        result['rlhf_pending'] = True

    return jsonify(result), 200


# ------------------------------------------------------------------
# New: Chat endpoint
# ------------------------------------------------------------------
@app.route("/api/chat", methods=["POST", "OPTIONS"])
def chat():
    print("===CHAT V2 CALLED===", flush=True)
    if request.method == "OPTIONS":
        return ("", 204)

    uid, role, parent_id = get_firebase_uid(request)
    child_id = uid if role == 'child' else None

    data = request.get_json(force=True)
    message = (data.get("message") or "").strip()
    history = data.get("history") or []

    if not message:
        return jsonify({"error": "Empty message"}), 400

    # 1. Defense check
    defense = _defense_check(message)
    decision = defense["decision"]
    risk_score = defense.get("final_risk", 0.0)

    # Log the case (only BLOCK/HESITATE are stored)
    case_id = None
    rlhf_pending = False
    try:
        # DEBUG: Log auth info
        logging.info(f"[CHAT] uid={uid}, role={role}, parent_id={parent_id}, decision={decision}, risk={risk_score}")
        case_id = log_case(message, decision, risk_score, child_id, parent_id)
        rlhf_pending = decision == 'HESITATE'
        logging.info(f"[CHAT] rlhf_pending={rlhf_pending} (decision={decision}, parent_id={parent_id})")
    except Exception as e:
        logging.warning(f"log_case failed in chat: {e}")

    print("===DECISION CHECK===", decision, flush=True)
    if decision == "BLOCK":
        print("===BLOCK BRANCH ENTERED===", flush=True)
        fallback_reply = call_ollama_block_fallback(message)
        print("===FALLBACK REPLY===", repr(fallback_reply[:80]) if fallback_reply else "EMPTY", flush=True)
        logging.info(f"[BLOCK_FALLBACK] reply={repr(fallback_reply[:120]) if fallback_reply else 'EMPTY'}")
        return jsonify({
            "decision":       "ALLOW",
            "reply":          fallback_reply,
            "defense_meta":   None,
            "pipeline_id":    None,
            "case_id":        case_id,
            "rlhf_pending":   False,
            "verdict":        None,
            "display_label":  None,
            "avg_agreement":  None,
            "model_statuses": None,
        })

    # 2. Ollama chat reply — pipeline is NOT started here; it fires only on bad rating
    reply = call_ollama_chat(message, history)

    return jsonify({
        "decision":       decision,
        "reply":          reply,
        "defense_meta":   defense,
        "pipeline_id":    None,
        "case_id":        case_id,
        "rlhf_pending":   rlhf_pending,
        "verdict":        None,
        "display_label":  None,
        "avg_agreement":  None,
        "model_statuses": None,
    })


# ------------------------------------------------------------------
# New: Pipeline status polling
# ------------------------------------------------------------------
@app.route("/api/pipeline/<pipeline_id>", methods=["GET"])
def get_pipeline(pipeline_id):
    entry = pipeline_store.get(pipeline_id)
    if entry is None:
        return jsonify({"error": "Pipeline not found"}), 404
    if entry.get("status") == "done":
        rag_stage = entry.get("stages", {}).get("rag", {})
        rag_data = rag_stage.get("data", {})
        rag_results_list = rag_data.get("results", [])
        print(f"[PIPELINE DONE] rag_results_count={len(rag_results_list)}, rag_error={rag_stage.get('error')}", flush=True)
    return jsonify(entry)


# ------------------------------------------------------------------
# Helper: run full pipeline then flag engine (triggered by bad rating)
# ------------------------------------------------------------------
def _run_pipeline_and_flag(message: str, session_id: str, user_id: str):
    pipeline_id = str(uuid.uuid4())
    pipeline_store[pipeline_id] = {
        "status": "running", "stages": {}, "verdict": None,
        "display_label": None, "avg_agreement": None, "model_statuses": None,
    }

    def _work():
        import time as _t
        _run_pipeline(pipeline_id, message)
        # _run_pipeline returns after spawning consensus in its own thread;
        # wait until consensus sets status='done' (max ~2 min)
        for _ in range(240):
            if pipeline_store.get(pipeline_id, {}).get("status") == "done":
                break
            _t.sleep(0.5)
        from services.flag_engine import _run as _flag_run
        _flag_run(session_id, user_id, pipeline_id, pipeline_store, message)

    threading.Thread(target=_work, daemon=True).start()


# ------------------------------------------------------------------
# New: Per-message rating — bad rating fires reasoning pipeline
# ------------------------------------------------------------------
@app.route("/api/message_rating", methods=["POST", "OPTIONS"])
def message_rating():
    if request.method == "OPTIONS":
        return ("", 204)

    data       = request.get_json(force=True) or {}
    message    = (data.get("message")    or "").strip()
    session_id = (data.get("session_id") or "").strip()
    user_id    = (data.get("user_id")    or "").strip()
    rating     = (data.get("rating")     or "").strip()

    if rating not in ("good", "bad"):
        return jsonify({"error": "rating must be 'good' or 'bad'"}), 400

    if rating == "bad" and message:
        _run_pipeline_and_flag(message, session_id, user_id)
        return jsonify({"started": True, "rating": "bad"}), 200

    return jsonify({"started": False, "rating": rating}), 200


# ------------------------------------------------------------------
# New: Session-level user feedback (thumbs up / down)
# ------------------------------------------------------------------
@app.route("/api/feedback", methods=["POST", "OPTIONS"])
def session_feedback():
    if request.method == "OPTIONS":
        return ("", 204)

    data = request.get_json(force=True) or {}
    session_id  = (data.get("session_id")  or "").strip()
    user_id     = (data.get("user_id")     or "").strip()
    rating      = (data.get("rating")      or "").strip()
    verdict     = data.get("verdict")
    pipeline_id = data.get("pipeline_id")
    message     = data.get("message") or None

    if not session_id:
        return jsonify({"error": "session_id is required"}), 400
    if rating not in ("good", "bad"):
        return jsonify({"error": "rating must be 'good' or 'bad'"}), 400

    ok = save_session_feedback(session_id, user_id, rating, verdict, pipeline_id)

    if rating == "bad" and pipeline_id:
        run_flag_engine(session_id, user_id, pipeline_id, pipeline_store, message)

    return jsonify({"success": ok, "session_id": session_id}), 200


# ------------------------------------------------------------------
# New: RLHF feedback
# ------------------------------------------------------------------
@app.route("/api/feedback/<int:case_id>", methods=["POST", "OPTIONS"])
def feedback(case_id):
    if request.method == "OPTIONS":
        return ("", 204)
    uid, role, _ = get_firebase_uid(request)
    if uid is None:
        uid  = request.headers.get('X-Firebase-UID', '').strip()
        role = request.headers.get('X-Firebase-Role', '').strip().lower()
    elif not role:
        role = request.headers.get('X-Firebase-Role', '').strip().lower()
    if role != 'parent':
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(force=True)
    label = data.get("label")
    if label not in [0, 1]:
        return jsonify({"error": "Invalid label"}), 400
    # Verify case belongs to this parent
    try:
        conn = sqlite3.connect(os.path.join(os.path.dirname(__file__), 'adaptive_cases.db'))
        row = conn.execute("SELECT parent_id FROM cases WHERE id=?", (case_id,)).fetchone()
        conn.close()
        if row is None:
            return jsonify({"error": "Case not found"}), 404
        case_parent_id = row[0]
        if case_parent_id is not None and case_parent_id != uid:
            return jsonify({"error": "Forbidden"}), 403
    except Exception as e:
        logging.warning(f"feedback auth check failed: {e}")
    success = update_rlhf_label(case_id, label)
    return jsonify({"success": success, "case_id": case_id}), 200


# ------------------------------------------------------------------
# New: Parent review queue
# ------------------------------------------------------------------
@app.route("/api/pending", methods=["GET", "OPTIONS"])
def pending():
    if request.method == "OPTIONS":
        return ("", 204)
    uid, role, _ = get_firebase_uid(request)

    # Fallback: when Firebase Admin isn't initialized, or token verified but role
    # missing in Firestore, accept UID/role from headers.
    if uid is None:
        uid  = request.headers.get('X-Firebase-UID', '').strip()
        role = request.headers.get('X-Firebase-Role', '').strip().lower()
        if uid and role:
            print(f"[PENDING] Using header fallback: uid={uid}, role={role}", flush=True)
    elif not role:
        role = request.headers.get('X-Firebase-Role', '').strip().lower()
        if role:
            print(f"[PENDING] Role from header (uid verified via token): uid={uid}, role={role}", flush=True)

    print(f"[PENDING] uid={uid}, role={role}", flush=True)
    if not uid:
        print("[PENDING] Blocked — no valid uid", flush=True)
        return jsonify({"error": "Forbidden"}), 403

    if role == 'admin':
        cases = get_pending_cases(None)
    elif role == 'parent':
        cases = get_pending_cases(uid)
    else:
        print(f"[PENDING] Blocked — unexpected role={role!r}", flush=True)
        return jsonify({"error": "Forbidden"}), 403

    print(f"[PENDING] Returning {len(cases)} cases for uid={uid}", flush=True)
    return jsonify({"cases": cases, "count": len(cases)}), 200


# ------------------------------------------------------------------
# Voice: Whisper transcription proxy
# ------------------------------------------------------------------
@app.route('/api/transcribe', methods=['POST', 'OPTIONS'])
def transcribe():
    if request.method == 'OPTIONS':
        return ('', 204)

    openai_key = os.getenv('OPENAI_API_KEY')
    if not openai_key:
        return jsonify({'error': 'OpenAI API key not configured on server'}), 500

    if 'file' not in request.files:
        return jsonify({'error': 'No audio file provided'}), 400

    audio = request.files['file']
    try:
        resp = req_lib.post(
            'https://api.openai.com/v1/audio/transcriptions',
            headers={'Authorization': f'Bearer {openai_key}'},
            files={'file': (audio.filename or 'voice.m4a', audio.stream, audio.mimetype or 'audio/m4a')},
            data={'model': 'whisper-1'},
            timeout=30,
        )
    except Exception as e:
        return jsonify({'error': f'Whisper request failed: {e}'}), 502

    if resp.status_code != 200:
        logging.warning(f"Whisper error {resp.status_code}: {resp.text}")
        return jsonify({'error': 'Whisper API error', 'detail': resp.text}), 502

    return jsonify(resp.json()), 200


# ------------------------------------------------------------------
# New: Buffer statistics
# ------------------------------------------------------------------
@app.route("/api/buffer/stats", methods=["GET"])
def buffer_stats():
    return jsonify(get_buffer_stats()), 200


# ------------------------------------------------------------------
# Root
# ------------------------------------------------------------------
@app.route("/", methods=["GET"])
def root():
    return jsonify({"message": "Backend is running", "endpoint": "/api/analyze"}), 200


@app.route('/api/retrain/status', methods=['GET'])
def retrain_status():
    """
    Returns current retraining state.
    Auth: any valid Firebase token (parent, child, or admin).
    """
    uid, role, _ = get_firebase_uid(request)
    if not uid:
        return jsonify({'error': 'Unauthorized'}), 403
    can_retrain, trigger_reason = check_trigger_conditions()
    return jsonify({
        'status': retrain_state['status'],
        'message': retrain_state['message'],
        'last_f1_before': retrain_state['last_f1_before'],
        'last_f1_after': retrain_state['last_f1_after'],
        'can_retrain': can_retrain,
        'trigger_reason': trigger_reason,
    })


@app.route('/api/retrain/trigger', methods=['POST'])
def retrain_trigger():
    """
    Starts retraining in a background daemon thread.
    Auth: admin role only.
    Optional body: {"force": true} to bypass trigger condition checks.
    """
    uid, role, _ = get_firebase_uid(request)
    if not uid or role != 'admin':
        return jsonify({'error': 'Admin role required'}), 403
    if retrain_state['status'] == 'running':
        return jsonify({'error': 'Retraining already in progress'}), 409
    body = request.get_json(silent=True, force=True) or {}
    force = body.get('force', False)
    t = threading.Thread(
        target=run_retraining,
        kwargs={'force': force},
        daemon=True
    )
    t.start()
    return jsonify({
        'started': True,
        'forced': force,
        'message': 'Retraining started in background thread',
    })



@app.after_request
def add_cors_headers(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    return resp


# Debug: Print all registered routes on startup
if __name__ == "__main__":
    print("\n" + "="*60)
    print("ROUTES REGISTERED ON STARTUP:")
    print("="*60)
    for rule in sorted(app.url_map.iter_rules(), key=lambda r: str(r)):
        methods = ','.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
        print(f"  {str(rule):40} [{methods}]")
    print("="*60 + "\n")
    app.run(debug=False, host="0.0.0.0", port=5000)