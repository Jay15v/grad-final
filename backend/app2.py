import threading
import uuid

from flask import Flask, request, jsonify
from flask_cors import CORS

from services.fusion_services import fuse_prompt
from services.model_services import bert_predict
from services.semantic_services import semantic_risk
from services.llm_service import call_ollama_chat
from services.decomposition_service import decompose_prompt
from services.reasoning_service import generate_reasoning_from_steps, generate_claims_from_reasoning
from services.rag_service import verify_claims_with_rag_google

from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)

CORS(
    app,
    resources={r"/api/*": {"origins": "*"}},
    supports_credentials=False,
    allow_headers=["Content-Type", "Authorization"],
    methods=["GET", "POST", "OPTIONS"],
)

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
        if claims and RAG_ENABLED:
            rag_results = verify_claims_with_rag_google(claims, k=5, refresh_web=True) or {
                "results": [], "rag_eval": {"total_steps": 0, "hits": 0, "misses": 0, "hit_rate": 0.0}
            }
        else:
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

    data = request.get_json(force=True)
    prompt = (data.get("prompt") or "").strip()

    if not prompt:
        return jsonify({"error": "Empty prompt"}), 400

    result = fuse_prompt(prompt)
    return jsonify(result), 200


# ------------------------------------------------------------------
# New: Chat endpoint
# ------------------------------------------------------------------
@app.route("/api/chat", methods=["POST", "OPTIONS"])
def chat():
    if request.method == "OPTIONS":
        return ("", 204)

    data = request.get_json(force=True)
    message = (data.get("message") or "").strip()
    history = data.get("history") or []

    if not message:
        return jsonify({"error": "Empty message"}), 400

    # 1. Defense check
    defense = _defense_check(message)
    decision = defense["decision"]

    if decision == "BLOCK":
        return jsonify({
            "decision": "BLOCK",
            "reply": None,
            "defense_meta": defense,
            "pipeline_id": None,
        })

    # 2. Ollama chat reply
    reply = call_ollama_chat(message, history)

    # 3. Start background pipeline
    pipeline_id = str(uuid.uuid4())
    pipeline_store[pipeline_id] = {"status": "running", "stages": {}}

    thread = threading.Thread(
        target=_run_pipeline,
        args=(pipeline_id, message),
        daemon=True,
    )
    thread.start()

    return jsonify({
        "decision": decision,
        "reply": reply,
        "defense_meta": defense,
        "pipeline_id": pipeline_id,
    })


# ------------------------------------------------------------------
# New: Pipeline status polling
# ------------------------------------------------------------------
@app.route("/api/pipeline/<pipeline_id>", methods=["GET"])
def get_pipeline(pipeline_id):
    entry = pipeline_store.get(pipeline_id)
    if entry is None:
        return jsonify({"error": "Pipeline not found"}), 404
    return jsonify(entry)


# ------------------------------------------------------------------
# Root
# ------------------------------------------------------------------
@app.route("/", methods=["GET"])
def root():
    return jsonify({"message": "Backend is running", "endpoint": "/api/analyze"}), 200


@app.after_request
def add_cors_headers(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    return resp


if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
