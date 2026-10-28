"""Shared test setup for the CodeQuest backend.

Tests run WITHOUT a Firebase project: AUTH_MODE=insecure_dev makes the backend
accept any caller as a fixed dev user, and SANDBOX_MODE=subprocess runs code
with the built-in runner (no Docker needed). These environment variables must
be set BEFORE the app modules are imported, which is why they live here.
"""

import os
import sys

os.environ["AUTH_MODE"] = "insecure_dev"
os.environ["SANDBOX_MODE"] = "subprocess"
os.environ["RUN_TIMEOUT_S"] = "2.0"
os.environ["RUN_RATE_MAX"] = "30"
os.environ["SUBMIT_RATE_MAX"] = "60"

# Make the backend folder importable (main.py, content.py, ...).
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
import ratelimit  # noqa: E402


@pytest.fixture(autouse=True)
def _reset_rate_limits():
    """Every test starts with empty rate-limit counters."""
    ratelimit.limiter._hits.clear()
    yield
    ratelimit.limiter._hits.clear()


@pytest.fixture()
def client():
    return TestClient(main.app)


@pytest.fixture()
def auth():
    # Any token works in insecure_dev mode; we still send one, like the app does.
    return {"Authorization": "Bearer test-token"}
