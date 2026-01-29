from flask import Flask, request, jsonify
from flask_cors import CORS
from services.model_services import bert_predict

app = Flask(__name__)
CORS(app)

@app.route("/api/analyze", methods=["POST"])
def analyze():
    data = request.get_json()
    prompt = data.get("prompt", "")

    if not prompt.strip():
        return jsonify({"error": "Empty prompt"}), 400

    risk = bert_predict(prompt)

    if risk >= 0.6:
        decision = "BLOCK"
    elif risk >= 0.35:
        decision = "HESITATE"
    else:
        decision = "ALLOW"

    return jsonify({
        "decision": decision,
        "bert_risk": round(risk, 3)
    })
@app.route("/", methods=["GET"])
def root():
    return jsonify({
        "message": "Backend is running",
        "endpoint": "/api/analyze"
    })

if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
