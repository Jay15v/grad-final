from flask import Flask, request, jsonify
from flask_cors import CORS
from services.fusion_services import fuse_prompt
from dotenv import load_dotenv
import traceback
import json

load_dotenv()

app = Flask(__name__)

CORS(
    app,
    resources={r"/api/*": {"origins": "*"}},
    supports_credentials=False,
    allow_headers=["Content-Type", "Authorization"],
    methods=["GET", "POST", "OPTIONS"],
)


def _compact_result(result: dict) -> dict:
    if not isinstance(result, dict):
        return result

    rag_verification = result.get("rag_verification")
    if not isinstance(rag_verification, dict):
        return result

    compact_results = []
    for item in rag_verification.get("results", []) or []:
        if not isinstance(item, dict):
            continue

        compact_item = {
            "claim": item.get("claim", ""),
            "source_step_id": item.get("source_step_id", 0),
            "verdict": item.get("verdict", "NO_EVIDENCE"),
            "best_evidence": None,
        }

        best = item.get("best_evidence")
        if isinstance(best, dict):
            compact_item["best_evidence"] = {
                "source": best.get("source", ""),
                "title": best.get("title", ""),
                "url": best.get("url", ""),
                "text": (best.get("text") or "")[:280],
                "similarity": best.get("similarity", 0),
                "coverage": best.get("coverage"),
            }

        compact_results.append(compact_item)

    rag_verification["results"] = compact_results

    rag_eval = rag_verification.get("rag_eval")
    if isinstance(rag_eval, dict):
        rag_verification["rag_eval"] = {
            "total_steps": rag_eval.get("total_steps", 0),
            "hits": rag_eval.get("hits", 0),
            "misses": rag_eval.get("misses", 0),
            "hit_rate": rag_eval.get("hit_rate", 0),
        }

    result["rag_verification"] = rag_verification
    return result


@app.route("/api/analyze", methods=["POST", "OPTIONS"])
def analyze():
    if request.method == "OPTIONS":
        return ("", 204)

    try:
        data = request.get_json(force=True)
        prompt = (data.get("prompt") or "").strip()

        if not prompt:
            return jsonify({"error": "Empty prompt"}), 400

        result = fuse_prompt(prompt)

        result = _compact_result(result)

        print("DEBUG response size:", len(json.dumps(result)))

        return jsonify(result), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({
            "error": str(e),
            "type": e.__class__.__name__,
        }), 500


@app.route("/", methods=["GET"])
def root():
    return jsonify({
        "message": "Backend is running",
        "endpoint": "/api/analyze"
    }), 200


@app.after_request
def add_cors_headers(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    return resp


if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)