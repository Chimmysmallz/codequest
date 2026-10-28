"""Firebase authentication for the CodeQuest backend.

The backend is now a STATELESS microservice: it holds no accounts and no
progress. It authenticates every protected call by verifying a **Firebase ID
token** that the Flutter app obtains from Firebase Auth and sends in the
``Authorization: Bearer <idToken>`` header.

Token-verification contract (``get_current_identity``):
  * Read ``Authorization: Bearer <idToken>``.
  * ``AUTH_MODE == "firebase"`` (default, PRODUCTION):
      verify the token with ``firebase_admin.auth.verify_id_token`` and return
      ``{"uid": <decoded uid>, "email": <decoded email or None>}``.
  * ``AUTH_MODE == "insecure_dev"`` (DEV ONLY):
      SKIP verification entirely and return a fixed dev identity. Loudly warns.
  * Any missing / malformed / invalid token -> HTTP 401.

The Firebase Admin SDK is initialized exactly once at import time.
"""

import logging
from typing import Dict, Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings

logger = logging.getLogger("codequest.firebase_auth")

# ---------------------------------------------------------------------------
# One-time Firebase Admin SDK initialization.
# ---------------------------------------------------------------------------
# We import firebase_admin lazily inside the initializer so that the module can
# be imported (and the app can boot in AUTH_MODE=insecure_dev) even if the
# firebase-admin package or credentials are not present in a local dev setup.
_firebase_app = None


def _init_firebase() -> None:
    """Initialize the Firebase Admin SDK exactly once (idempotent).

    Credentials resolution:
      * If ``GOOGLE_APPLICATION_CREDENTIALS`` points at a service-account JSON,
        load it explicitly via ``credentials.Certificate(path)``.
      * Otherwise fall back to Application Default Credentials
        (``firebase_admin.initialize_app()``) — e.g. a metadata server on GCP
        or the ambient ``GOOGLE_APPLICATION_CREDENTIALS`` env the SDK reads.

    Guarded against double-initialization: if an app already exists (either
    tracked here or created elsewhere) we reuse it instead of raising.
    """
    global _firebase_app
    if _firebase_app is not None:
        return

    import firebase_admin
    from firebase_admin import credentials

    # If a default app already exists (e.g. re-import under --reload), reuse it.
    try:
        _firebase_app = firebase_admin.get_app()
        return
    except ValueError:
        # No app yet — create one below.
        pass

    options: Dict[str, str] = {}
    if settings.FIREBASE_PROJECT_ID:
        options["projectId"] = settings.FIREBASE_PROJECT_ID

    if settings.GOOGLE_APPLICATION_CREDENTIALS:
        cred = credentials.Certificate(settings.GOOGLE_APPLICATION_CREDENTIALS)
        _firebase_app = firebase_admin.initialize_app(cred, options or None)
    else:
        # Application Default Credentials.
        _firebase_app = firebase_admin.initialize_app(options=options or None)


# Initialize at import/startup — but only when we actually need Firebase.
# In insecure_dev mode we intentionally skip init so the service can run with
# no firebase-admin package and no credentials at all.
if settings.AUTH_MODE != "insecure_dev":
    _init_firebase()


# auto_error=False so a MISSING header yields our own 401 (not FastAPI's 403),
# keeping a single consistent auth contract for the app.
_bearer_scheme = HTTPBearer(auto_error=False)

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate Firebase credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_identity(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> Dict[str, Optional[str]]:
    """FastAPI dependency: resolve the caller's identity from a Firebase token.

    Returns ``{"uid": str, "email": Optional[str]}`` on success; raises HTTP 401
    on any missing / malformed / invalid token.
    """
    # === DEV-ONLY BYPASS ===================================================
    # NEVER enable AUTH_MODE=insecure_dev in production. It returns a fixed
    # identity WITHOUT verifying anything, so ANYONE can call protected
    # endpoints. It exists purely so you can poke the API locally without a
    # Firebase project. This branch must never ship enabled.
    if settings.AUTH_MODE == "insecure_dev":
        logger.warning(
            "AUTH_MODE=insecure_dev: SKIPPING Firebase token verification and "
            "returning a fake dev identity. THIS IS UNSAFE — never use this in "
            "production."
        )
        return {"uid": "dev-user", "email": "dev@local"}
    # =======================================================================

    if credentials is None or not credentials.credentials:
        raise _UNAUTHORIZED

    token = credentials.credentials

    from firebase_admin import auth as firebase_auth_admin

    try:
        decoded = firebase_auth_admin.verify_id_token(token)
    except Exception:
        # Expired, malformed, wrong-project, revoked, etc. — all map to 401.
        raise _UNAUTHORIZED

    uid = decoded.get("uid")
    if not uid:
        raise _UNAUTHORIZED

    return {"uid": uid, "email": decoded.get("email")}
