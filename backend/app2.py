from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route("/", methods=["GET"])
def root():
    return jsonify({
        "message": "AegisMind API is running",
        "available_endpoints": [
            "/api/health",
            "/api/analyze"
        ]
    })

@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "Backend is running"})

if __name__ == "__main__":
    app.run(debug=True)
