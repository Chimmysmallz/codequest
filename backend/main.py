"""CodeQuest FastAPI backend — a stateless code-checking microservice.

The app moved to **Firebase Auth + Cloud Firestore**, so this backend NO LONGER
handles accounts or stores progress. It only:

  * serves game content (worlds + missions, secret answers stripped),
  * runs kid-written Python safely (subprocess dev runner / Docker sandbox),
  * checks mission answers, and
  * authenticates callers by verifying a **Firebase ID token**.

There is no database and no startup migration — the service is stateless. The
Flutter app owns all persistence: it reads/writes accounts and progress
directly in Firebase/Firestore.

Run locally:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

From an Android emulator, the host machine is reachable at http://10.0.2.2:8000.
"""

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

import content
from config import settings
from ratelimit import rate_limited
from runner import run_code
from schemas import (
    RunRequest,
    RunResponse,
    SubmitRequest,
    SubmitResponse,
)

app = FastAPI(
    title="CodeQuest API",
    description=(
        "Stateless backend for CodeQuest — serves content, runs Python safely, "
        "and checks answers. Authenticated with Firebase ID tokens; accounts "
        "and progress live in Firebase Auth + Cloud Firestore."
    ),
    version="3.0.0",
)

# --- CORS -------------------------------------------------------------------
# Origins come from settings (default ["*"] for dev). Lock down in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Helpers ----------------------------------------------------------------
def _normalize(text: str) -> str:
    """Normalize program output for comparison.

    Strips trailing whitespace on each line and strips trailing newlines so
    that "1\n2\n3\n" and "1 \n2\n3" compare equal.
    """
    if text is None:
        text = ""
    lines = [line.rstrip() for line in text.split("\n")]
    normalized = "\n".join(lines)
    return normalized.rstrip("\n")


# --- Health -----------------------------------------------------------------
@app.get("/health")
def health():
    """Liveness probe (public)."""
    return {"status": "ok"}


# --- Content (public) -------------------------------------------------------
@app.get("/content")
def get_content():
    """Return all worlds and missions with client-safe challenges (public).

    Secret challenge fields (answer / expectedOutput) are NEVER included.
    """
    safe_missions = []
    for mission in content.MISSIONS:
        safe = dict(mission)  # shallow copy so we don't mutate the source.
        safe["challenge"] = content.public_challenge(mission["challenge"])
        safe_missions.append(safe)
    return {"worlds": content.WORLDS, "missions": safe_missions}


# --- Run code (protected) ---------------------------------------------------
@app.post("/run", response_model=RunResponse)
def run(
    body: RunRequest,
    identity: dict = Depends(
        rate_limited("run", settings.RUN_RATE_MAX, settings.RUN_RATE_WINDOW_S)
    ),
):
    """Execute submitted Python code and return its captured output.

    Requires a valid Firebase ID token. Rate limited per Firebase user
    (``RUN_RATE_MAX`` hits / ``RUN_RATE_WINDOW_S`` seconds) — over the limit
    returns HTTP 429 with a ``Retry-After`` header.
    """
    result = run_code(body.code)
    return RunResponse(
        output=result["output"],
        error=result["error"],
        timedOut=result["timedOut"],
    )


# --- Submit (protected) -----------------------------------------------------
@app.post("/submit", response_model=SubmitResponse)
def submit(
    body: SubmitRequest,
    identity: dict = Depends(
        rate_limited("submit", settings.SUBMIT_RATE_MAX, settings.SUBMIT_RATE_WINDOW_S)
    ),
):
    """Check a mission submission and report what it would earn.

    Requires a valid Firebase ID token. Rate limited per Firebase user
    (``SUBMIT_RATE_MAX`` hits / ``SUBMIT_RATE_WINDOW_S`` seconds) — over the
    limit returns HTTP 429 with a ``Retry-After`` header.

    IMPORTANT: this backend persists NOTHING. It only tells the caller whether
    the attempt passed and how much xp/coins the mission is worth. The app is
    responsible for writing progress to Firestore and for "award once" logic —
    it keeps its own set of completed mission ids (enforced by Firestore
    security rules) so a mission's xp/coins are only granted a single time.
    """
    mission = content.get_mission(body.missionId)
    if mission is None:
        raise HTTPException(status_code=404, detail="Mission not found")

    challenge = mission["challenge"]
    hint = challenge.get("hint")

    passed = False
    output = None
    error = None

    if challenge["type"] == "fill_blank":
        # Case-sensitive exact match after trimming surrounding whitespace.
        submitted = (body.answer or "").strip()
        passed = submitted == challenge["answer"]
    elif challenge["type"] == "code":
        run_result = run_code(body.code or "")
        output = run_result["output"]
        error = run_result["error"]
        if run_result["timedOut"]:
            passed = False
        else:
            passed = _normalize(output) == _normalize(challenge["expectedOutput"])
    else:
        # Unknown challenge type — fail loudly rather than silently pass.
        raise HTTPException(status_code=500, detail="Unsupported challenge type")

    # stars is a flat 3 for the MVP. xp/coins reflect the mission's worth when
    # passed (else 0). These are advisory amounts — the app awards them once
    # and stores the result in Firestore.
    stars = 3 if passed else 0
    xp_earned = mission["xp"] if passed else 0
    coins_earned = mission["coins"] if passed else 0

    message = "Nice! The robot made it ⚡" if passed else "Not quite — check the hint."

    return SubmitResponse(
        passed=passed,
        stars=stars,
        xpEarned=xp_earned,
        coinsEarned=coins_earned,
        output=output,
        error=error,
        hint=None if passed else hint,
        message=message,
    )


# --- Dev entrypoint ---------------------------------------------------------
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
