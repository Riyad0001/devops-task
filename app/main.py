"""Minimal Flask app for the DevOps Intern screening task."""
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(message="Hello from DevOps Intern Task!", status="running")


if __name__ == "__main__":
    # Local development only. In the container, gunicorn serves the app.
    app.run(host="0.0.0.0", port=8080)
