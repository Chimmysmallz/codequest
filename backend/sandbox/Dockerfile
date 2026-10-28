# Minimal sandbox image for running untrusted CodeQuest submissions.
#
# Build it once:
#     docker build -t codequest-sandbox ./sandbox
#
# It deliberately installs NOTHING beyond stock Python. All of the real
# isolation (no network, read-only fs, memory/cpu/pids caps, non-root user)
# is applied at RUN time by runner_docker.py via docker flags — including
# `--user 65534:65534` (nobody), so the image itself stays intentionally bare.
FROM python:3.12-slim

# No extra packages, no app code baked in — the user's script is mounted at
# /code and executed with `python -I -S /code/main.py` at run time.
