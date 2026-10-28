#!/usr/bin/env bash
# Starts the CodeQuest backend in local DEV mode (no Firebase, no Docker).
set -e
cd "$(dirname "$0")/../backend"
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -q -r requirements.txt -r requirements-dev.txt
export AUTH_MODE=insecure_dev SANDBOX_MODE=subprocess
echo "Backend starting on http://localhost:8000  (Ctrl+C to stop)"
echo "Open http://localhost:8000/docs in your browser to try it."
uvicorn main:app --reload --host 0.0.0.0 --port 8000
