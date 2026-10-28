"""End-to-end API tests: they call the real FastAPI app over HTTP (in-process).

Covers: health, content (with secrets stripped), running code (normal output,
errors, infinite-loop timeout), grading every mission with a correct answer,
wrong answers, unknown missions, authentication and rate limiting.
"""

import pytest

import content
import firebase_auth
from config import settings

# A correct solution for every mission in content.py.
CORRECT = {
    "v1": {"answer": 'print("Hello")'},
    "v2": {"code": 'print("Ada")'},
    "f1": {"answer": "for"},
    "f2": {"answer": "i"},
    "f3": {"code": "for i in range(1, 6):\n    print(i)"},
    "fac1": {"code": "print(3 * 4)"},
    "c1": {"answer": "print"},
    "s1": {"code": 'print("Liftoff")'},
}


# --- Health -----------------------------------------------------------------
def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


# --- Content ----------------------------------------------------------------
def test_content_lists_all_worlds_and_missions(client):
    data = client.get("/content").json()
    assert [w["id"] for w in data["worlds"]] == ["village", "forest", "factory", "castle", "space"]
    assert len(data["missions"]) == len(content.MISSIONS)


def test_content_never_leaks_answers(client):
    text = client.get("/content").text
    assert '"answer"' not in text
    assert '"expectedOutput"' not in text


def test_every_mission_has_a_test_solution():
    # If you add a mission to content.py, add its solution to CORRECT above.
    assert set(CORRECT) == {m["id"] for m in content.MISSIONS}


# --- Run code ---------------------------------------------------------------
def test_run_prints_output(client, auth):
    r = client.post("/run", json={"code": 'print("Zap")'}, headers=auth)
    assert r.status_code == 200
    body = r.json()
    assert body["output"].strip() == "Zap"
    assert body["timedOut"] is False


def test_run_reports_python_errors(client, auth):
    body = client.post("/run", json={"code": "print(undefined_name)"}, headers=auth).json()
    assert body["error"] and "NameError" in body["error"]


def test_run_kills_infinite_loops(client, auth):
    body = client.post("/run", json={"code": "while True:\n    pass"}, headers=auth).json()
    assert body["timedOut"] is True


# --- Submit -----------------------------------------------------------------
@pytest.mark.parametrize("mission_id", list(CORRECT))
def test_submit_correct_answer_passes(client, auth, mission_id):
    payload = {"missionId": mission_id, **CORRECT[mission_id]}
    body = client.post("/submit", json=payload, headers=auth).json()
    mission = content.get_mission(mission_id)
    assert body["passed"] is True, body
    assert body["stars"] == 3
    assert body["xpEarned"] == mission["xp"]
    assert body["coinsEarned"] == mission["coins"]
    assert body["hint"] is None


def test_submit_wrong_fill_blank_fails_with_hint(client, auth):
    body = client.post("/submit", json={"missionId": "v1", "answer": 'echo("Hello")'}, headers=auth).json()
    assert body["passed"] is False
    assert body["xpEarned"] == 0
    assert body["hint"]


def test_submit_wrong_code_fails(client, auth):
    body = client.post("/submit", json={"missionId": "v2", "code": 'print("Bob")'}, headers=auth).json()
    assert body["passed"] is False
    assert body["output"].strip() == "Bob"


def test_submit_unknown_mission_is_404(client, auth):
    r = client.post("/submit", json={"missionId": "nope", "answer": "x"}, headers=auth)
    assert r.status_code == 404


# --- Auth -------------------------------------------------------------------
def test_firebase_mode_rejects_missing_token(client, monkeypatch):
    # Switch to real Firebase mode for this test only: no token -> 401.
    monkeypatch.setattr(firebase_auth.settings, "AUTH_MODE", "firebase")
    r = client.post("/run", json={"code": "print(1)"})
    assert r.status_code == 401


# --- Rate limiting ----------------------------------------------------------
def test_run_rate_limit_returns_429(client, auth):
    for _ in range(settings.RUN_RATE_MAX):
        assert client.post("/run", json={"code": "pass"}, headers=auth).status_code == 200
    r = client.post("/run", json={"code": "pass"}, headers=auth)
    assert r.status_code == 429
    assert int(r.headers["Retry-After"]) >= 1
