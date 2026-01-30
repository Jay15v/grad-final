from flask import Flask, request, jsonify
from flask_cors import CORS
from services.fusion_services import fuse_prompt

app = Flask(__name__)
CORS(app)

@app.route("/api/analyze", methods=["POST"])
def analyze():
    data = request.get_json()
    prompt = data.get("prompt", "")

    if not prompt.strip():
        return jsonify({"error": "Empty prompt"}), 400

    result = fuse_prompt(prompt)
    return jsonify(result)

@app.route("/", methods=["GET"])
def root():
    return jsonify({
        "message": "Backend is running",
        "endpoint": "/api/analyze"
    })

if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
