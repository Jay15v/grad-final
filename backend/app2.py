from flask import Flask, request, jsonify
from flask_cors import CORS

# 🔥 Single orchestration entry point
from services.fusion_services import fuse_prompt

app = Flask(__name__)
CORS(app)


@app.route("/api/analyze", methods=["POST"])
def analyze():
    """
    Main analysis endpoint.

    Flow (delegated entirely to fusion_services):
    - Risk analysis
    - Decision (ALLOW / BLOCK / HESITATE)
    - Decomposition (if ALLOW)
    - Claims generation (if ALLOW)
    - RAG-ready output
    """

    data = request.get_json(force=True)
    prompt = (data.get("prompt") or "").strip()

    if not prompt:
        return jsonify({"error": "Empty prompt"}), 400

    # ✅ Single source of truth
    result = fuse_prompt(prompt)

    return jsonify(result), 200


@app.route("/", methods=["GET"])
def root():
    return jsonify({
        "message": "Backend is running",
        "endpoint": "/api/analyze"
    })


if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
