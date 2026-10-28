"""Application settings for the CodeQuest backend.

Everything is driven by environment variables (optionally via a local `.env`
file). The backend is a STATELESS microservice: it stores nothing. It serves
content, runs code, checks answers, and authenticates callers with **Firebase
ID tokens**. Accounts and progress live in Firebase Auth + Cloud Firestore.

  * Local dev  -> subprocess runner + AUTH_MODE=insecure_dev (no Firebase)
  * Production -> Docker sandbox (SANDBOX_MODE=docker) + Firebase token auth

Import the ready-made singleton:  ``from config import settings``.
"""

from typing import List, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Typed settings read from the environment / a `.env` file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Firebase auth -----------------------------------------------------
    # The backend verifies Firebase ID tokens instead of issuing its own.
    #   FIREBASE_PROJECT_ID: optional; helps the Admin SDK target a project
    #     (usually inferred from the service-account credentials).
    #   GOOGLE_APPLICATION_CREDENTIALS: path to a service-account JSON file.
    #     If unset, Application Default Credentials are used.
    FIREBASE_PROJECT_ID: Optional[str] = None
    GOOGLE_APPLICATION_CREDENTIALS: Optional[str] = None

    # "firebase"     = verify Firebase ID tokens (production default).
    # "insecure_dev" = DEV ONLY: skip verification, use a fake identity.
    AUTH_MODE: str = "firebase"

    # --- Code sandbox ------------------------------------------------------
    # "subprocess" = built-in dev runner (no Docker needed).
    # "docker"     = hardened container sandbox (see runner_docker.py); prod.
    SANDBOX_MODE: str = "subprocess"
    SANDBOX_IMAGE: str = "codequest-sandbox"
    RUN_TIMEOUT_S: float = 3.0

    # --- CORS --------------------------------------------------------------
    # DEV ONLY: "*" lets any origin call the API. Lock this down to your
    # actual front-end origin(s) before going to production.
    CORS_ORIGINS: List[str] = ["*"]

    # --- Rate limiting -----------------------------------------------------
    # Per-Firebase-user sliding-window limits on the two code endpoints. When a
    # user exceeds a limit the endpoint returns HTTP 429 with a Retry-After
    # header. NOTE: the limiter is per-process/in-memory (see ratelimit.py) —
    # each worker/instance counts independently; use Redis for multi-instance.
    #   /run:    RUN_RATE_MAX hits per RUN_RATE_WINDOW_S seconds.
    #   /submit: SUBMIT_RATE_MAX hits per SUBMIT_RATE_WINDOW_S seconds.
    RUN_RATE_MAX: int = 30
    RUN_RATE_WINDOW_S: int = 60
    SUBMIT_RATE_MAX: int = 60
    SUBMIT_RATE_WINDOW_S: int = 60


# Import this singleton everywhere instead of re-instantiating Settings().
settings = Settings()
