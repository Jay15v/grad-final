import threading
import uuid
import sqlite3
import logging

# Step 1 & 2: load .env FIRST so all os.environ.get() calls below see the values
from dotenv import load_dotenv
import os
load_dotenv()

from flask import Flask, request, jsonify
from flask_cors import CORS

from services.fusion_services import fuse_prompt
from services.model_services import bert_predict
from services.semantic_services import semantic_risk
from services.llm_service import call_ollama_chat
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

# Step 5, 6, 7: resolve path and initialize
if _firebase_available:
    sa_path = os.environ.get('FIREBASE_SERVICE_ACCOUNT_PATH')
    if sa_path and not os.path.isabs(sa_path):
        sa_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), sa_path)
    if sa_path and os.path.exists(sa_path):
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(sa_path)
                firebase_admin.initialize_app(cred)
                print("✅ Firebase Admin initialized successfully")
        except Exception as e:
            logging.warning(f"Firebase Admin init failed: {e}")
    else:
        logging.warning(f"serviceAccount.json not found at: {sa_path}")

from services.consensus_service import cross_model_validate
from services.notification_service import notify_parent_if_needed

from services.adaptive_store import (
    init_db, log_case, update_rlhf_label,
    get_pending_cases, get_buffer_stats,
    get_firebase_uid, start_background_jobs
)
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
    start_background_jobs()

BLOCK_THRESHOLD = 0.60
HESITATE_THRESHOLD = 0.35
RAG_ENABLED = bool(os.getenv("GOOGLE_CSE_API_KEY") and os.getenv("GOOGLE_CSE_ID"))

# In-memory store for background pipeline results
pipeline_store: dict = {}


# ------------------------------------------------------------------
# Helper: run the quick defense check
# ------------------------------------------------------------------
def _defense_check(message: str) -> dict:
    bert_risk = bert_predict(message)
    final_risk = bert_risk
    semantic_domain, semantic_similarity = semantic_risk(message)

    if semantic_domain == "roleplay_jailbreak":
        final_risk = max(bert_risk * 0.8, 0.35)
    elif semantic_domain == "direct_injection":
        final_risk = max(bert_risk * 1.2, 0.50)
    elif semantic_domain == "obfuscation_payload":
        final_risk = max(bert_risk * 1.3, 0.55)
    elif semantic_domain == "virtualization_hypotheticals":
        final_risk = bert_risk * 0.6
    elif semantic_domain == "violence_intent":
        final_risk = max(bert_risk * 1.5, 0.45)
    elif semantic_domain == "self_harm":
        final_risk = max(bert_risk * 1.5, 0.45)
    elif semantic_domain == "dangerous_weapons":
        final_risk = max(bert_risk * 1.4, 0.65)
    elif semantic_domain == "direct_harm":
        final_risk = max(bert_risk * 1.2, 0.40)
    elif semantic_domain == "parental_control_bypass":
        final_risk = max(bert_risk * 1.2, 0.40)

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
def _run_pipeline(pipeline_id: str, message: str):
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

    entry["status"] = "done"


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
        rlhf_pending = decision == 'HESITATE' and parent_id is not None
        logging.info(f"[CHAT] rlhf_pending={rlhf_pending} (decision={decision}, parent_id={parent_id})")
    except Exception as e:
        logging.warning(f"log_case failed in chat: {e}")

    if decision == "BLOCK":
        return jsonify({
            "decision": "BLOCK",
            "reply": None,
            "defense_meta": defense,
            "pipeline_id": None,
            "case_id": case_id,
            "rlhf_pending": rlhf_pending,
        })

    # 2. Ollama chat reply
    reply = call_ollama_chat(message, history)

    # 3. Cross-model consensus validation
    consensus_result = None
    try:
        consensus_result = cross_model_validate(message)
        if consensus_result.get("verdict") == "DISAGREEMENT":
            notify_parent_if_needed(child_id or "anonymous", message, consensus_result)
    except Exception as e:
        logging.warning(f"consensus validation failed: {e}")

    # 4. Start background pipeline
    pipeline_id = str(uuid.uuid4())
    pipeline_store[pipeline_id] = {"status": "running", "stages": {}}

    thread = threading.Thread(
        target=_run_pipeline,
        args=(pipeline_id, message),
        daemon=True,
    )
    thread.start()

    return jsonify({
        "decision":       decision,
        "reply":          reply,
        "defense_meta":   defense,
        "pipeline_id":    pipeline_id,
        "case_id":        case_id,
        "rlhf_pending":   rlhf_pending,
        "verdict":        consensus_result["verdict"]        if consensus_result else None,
        "display_label":  consensus_result["display_label"]  if consensus_result else None,
        "avg_agreement":  consensus_result["avg_agreement"]  if consensus_result else None,
        "model_statuses": consensus_result["model_statuses"] if consensus_result else None,
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
# New: RLHF feedback
# ------------------------------------------------------------------
@app.route("/api/feedback/<int:case_id>", methods=["POST", "OPTIONS"])
def feedback(case_id):
    if request.method == "OPTIONS":
        return ("", 204)
    uid, role, _ = get_firebase_uid(request)
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
    if uid is None:
        return jsonify({"error": "Forbidden"}), 403
    if role == 'admin':
        cases = get_pending_cases(None)
    elif role == 'parent':
        cases = get_pending_cases(uid)
    else:
        return jsonify({"error": "Forbidden"}), 403
    return jsonify({"cases": cases, "count": len(cases)}), 200


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