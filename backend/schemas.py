"""Pydantic v2 request/response schemas for the CodeQuest API.

These define the exact JSON the Flutter app sends and receives. The backend is
stateless: it only runs code and checks answers, so there are NO auth, token,
user, or progress schemas here — Firebase Auth + Firestore own those. What
remains mirrors the game's run / submit flows.
"""

from typing import Optional

from pydantic import BaseModel


# --- Code running -----------------------------------------------------------
class RunRequest(BaseModel):
    """Body for POST /run."""

    code: str


class RunResponse(BaseModel):
    """Result of running code."""

    output: str
    error: Optional[str] = None
    timedOut: bool = False


# --- Submissions ------------------------------------------------------------
class SubmitRequest(BaseModel):
    """Body for POST /submit.

    `answer` is used for fill_blank challenges; `code` for code challenges.
    There is intentionally NO userId here — the caller's identity comes from
    the verified Firebase ID token, and the backend persists nothing anyway.
    """

    missionId: str
    answer: Optional[str] = None
    code: Optional[str] = None


class SubmitResponse(BaseModel):
    """Result of a submission attempt.

    Reports whether the attempt passed and how much it WOULD earn. The backend
    does not persist anything; the app writes the awarded xp/coins to Firestore.
    """

    passed: bool
    stars: int = 0
    xpEarned: int = 0
    coinsEarned: int = 0
    output: Optional[str] = None
    error: Optional[str] = None
    hint: Optional[str] = None
    message: str
