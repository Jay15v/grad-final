from flask import Flask, request, jsonify
from flask_cors import CORS

from services.fusion_services import fuse_prompt
from dotenv import load_dotenv
load_dotenv()


app = Flask(__name__)

# ✅ Proper CORS (allow Vite + allow headers)
CORS(
    app,
    resources={r"/api/*": {"origins": ["http://localhost:5173"]}},
    supports_credentials=True,
    allow_headers=["Content-Type", "Authorization"],
    methods=["GET", "POST", "OPTIONS"],
)

@app.route("/api/analyze", methods=["POST", "OPTIONS"])
def analyze():
    # ✅ Explicitly handle preflight
    if request.method == "OPTIONS":
        return ("", 204)

    data = request.get_json(force=True)
    prompt = (data.get("prompt") or "").strip()

    if not prompt:
        return jsonify({"error": "Empty prompt"}), 400

    result = fuse_prompt(prompt)
    return jsonify(result), 200

@app.route("/", methods=["GET"])
def root():
    return jsonify({"message": "Backend is running", "endpoint": "/api/analyze"}), 200

if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)


@app.after_request
def add_cors_headers(resp):
    resp.headers["Access-Control-Allow-Origin"] = "http://localhost:5173"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    return resp
