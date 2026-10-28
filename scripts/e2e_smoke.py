"""Live end-to-end smoke test for a RUNNING CodeQuest backend.

Uses only the Python standard library, so it runs anywhere Python 3 is installed.

Local dev server (no Firebase):
    python scripts/e2e_smoke.py

Deployed server with real Firebase login:
    python scripts/e2e_smoke.py --url https://api.yourdomain.com --token <FIREBASE_ID_TOKEN>

It walks the same path the app does: health -> content -> run code ->
submit a right answer -> submit a wrong answer, and prints PASS/FAIL per step.
"""

import argparse
import json
import sys
import urllib.error
import urllib.request


def call(base, method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base.rstrip("/") + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://localhost:8000")
    ap.add_argument("--token", default="dev-token", help="Firebase ID token (any value in insecure_dev mode)")
    a = ap.parse_args()

    results = []

    def check(name, ok, detail=""):
        results.append(ok)
        print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail and not ok else ""))

    try:
        s, b = call(a.url, "GET", "/health")
    except Exception as e:
        print(f"FAIL  cannot reach {a.url}: {e}\nIs the backend running?")
        sys.exit(1)
    check("server is healthy", s == 200 and b == {"status": "ok"}, f"{s} {b}")

    s, b = call(a.url, "GET", "/content")
    ok = s == 200 and len(b.get("worlds", [])) == 5 and len(b.get("missions", [])) >= 1
    check("content loads (5 worlds)", ok, f"{s}")
    if s == 200:
        check("answers are hidden from players", '"answer"' not in json.dumps(b) and '"expectedOutput"' not in json.dumps(b))

    s, b = call(a.url, "POST", "/run", a.token, {"code": 'print("Zap")'})
    check("runs Python code", s == 200 and b and b["output"].strip() == "Zap", f"{s} {b}")

    s, b = call(a.url, "POST", "/run", a.token, {"code": "while True:\n    pass"})
    check("stops infinite loops", s == 200 and b and b["timedOut"] is True, f"{s} {b}")

    s, b = call(a.url, "POST", "/submit", a.token, {"missionId": "f3", "code": "for i in range(1, 6):\n    print(i)"})
    check("correct answer passes and earns XP", s == 200 and b and b["passed"] and b["xpEarned"] > 0, f"{s} {b}")

    s, b = call(a.url, "POST", "/submit", a.token, {"missionId": "v1", "answer": 'echo("Hello")'})
    check("wrong answer fails with a hint", s == 200 and b and not b["passed"] and b["hint"], f"{s} {b}")

    s, _ = call(a.url, "POST", "/run", None, {"code": "print(1)"})
    if s == 401:
        print("INFO  login is enforced (no token -> 401). Good for production.")
    else:
        print("INFO  login is NOT enforced (dev mode). Never deploy with AUTH_MODE=insecure_dev.")

    passed = sum(results)
    print(f"\n{passed}/{len(results)} checks passed")
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
