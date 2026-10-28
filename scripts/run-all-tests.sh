#!/usr/bin/env bash
# Runs the backend tests on your own computer (Mac/Linux).
set -e
cd "$(dirname "$0")/../backend"
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -q -r requirements.txt -r requirements-dev.txt
python -m pytest
