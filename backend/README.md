# CodeQuest — Python Backend

FastAPI backend for **CodeQuest**, a Flutter + Python coding game that teaches
kids Python. This service is now **stateless**: it serves the game content, runs
kid-written Python safely, and checks mission answers. It does **not** hold
accounts and does **not** store progress.

Authentication is handled by **Firebase**. The app signs users in with Firebase
Auth and calls this API with a **Firebase ID token** in the
`Authorization: Bearer <idToken>` header; the backend verifies that token with
the Firebase Admin SDK. **Accounts and progress now live in Firebase Auth +
Cloud Firestore**, owned by the app — the backend persists nothing.

The best part for local development: it needs **no database and no Docker**. Out
of the box it uses a simple subprocess code runner, and (with
`AUTH_MODE=insecure_dev`) can run without a Firebase project at all. You can
upgrade to a hardened Docker sandbox and real Firebase token verification just
by changing environment variables — the code stays the same.

---

## 1. Quick local run

```bash
# a) Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate          # macOS / Linux
# .venv\Scripts\activate           # Windows (PowerShell / cmd)

# b) Install dependencies
pip install -r requirements.txt

# c) Run the server (auto-reload for development)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The server listens on `http://localhost:8000`, and interactive API docs live at
`http://localhost:8000/docs`.

> **Android emulator note:** an emulator can't reach the host via `localhost`.
> Use **`http://10.0.2.2:8000`** instead — that's the emulator's alias for your
> machine.

### Local without Firebase (dev bypass)

To poke the protected endpoints locally without a Firebase project, set:

```bash
export AUTH_MODE=insecure_dev
uvicorn main:app --reload
```

In this mode the backend **skips token verification entirely** and treats every
caller as a fixed dev identity (`{"uid":"dev-user","email":"dev@local"}`). It
logs a loud warning on every request. **This is DEV ONLY — never enable
`insecure_dev` in production, because anyone can then call protected endpoints.**

---

## 2. Endpoints

| Method & path   | Auth               | What it does                                       |
| --------------- | ------------------ | -------------------------------------------------- |
| `GET  /health`  | public             | Liveness probe -> `{"status":"ok"}`                |
| `GET  /content` | public             | All worlds + missions (secret answers stripped)    |
| `POST /run`     | **Firebase token** | Run Python, return `{output,error,timedOut}`       |
| `POST /submit`  | **Firebase token** | Check a mission, report `{passed,stars,xpEarned,…}` |

Protected calls require an `Authorization: Bearer <idToken>` header, where
`<idToken>` is a Firebase ID token obtained by the app from Firebase Auth. A
missing, malformed, expired, or otherwise invalid token returns **401**.

**Rate limiting.** `/run` and `/submit` are rate limited **per Firebase user**
(keyed by the token's `uid`) using an in-memory sliding window. When a user
exceeds a limit the endpoint returns **HTTP 429** with a **`Retry-After`**
header (seconds to wait). Defaults: `/run` = 30 requests/60s, `/submit` = 60
requests/60s (see [Configuration](#5-configuration)). `/health` and `/content`
are public and never limited.

> **Single-instance caveat:** the limiter is **per-process and in-memory**, so
> each Uvicorn worker / container instance keeps its own counters. With multiple
> workers or replicas a user's effective limit is multiplied by the process
> count. For a horizontally-scaled deployment, back the limiter with a shared
> store such as **Redis** (there's a `TODO` in `ratelimit.py`).

`POST /submit` takes `{missionId, answer?, code?}`:

- **fill_blank** challenges: `passed` is `answer.strip()` equal to the mission's
  secret answer.
- **code** challenges: the code is run and its normalized stdout is compared to
  the mission's expected output.

On a pass it returns `stars = 3` and the mission's `xpEarned` / `coinsEarned`
(both `0` on a miss), plus a friendly `message`; on a miss it also returns the
`hint`. **The backend does not persist anything.** These xp/coins are advisory —
the app writes progress to **Firestore** and is responsible for "award once"
(it keeps its own completed-mission set, enforced by Firestore security rules,
so a mission's reward is only granted a single time).

### Rules

- `XP_PER_LEVEL = 250`; `level = 1 + xp // 250` (computed by the app).
- A world unlocks when it is the **village** (order 0) **or** every mission of
  the immediately-previous world is completed.
- On a passing submit, a mission's XP and coins are worth their listed amounts,
  awarded **once** by the app. `stars` is a flat **3** for the MVP.

---

## 3. Firebase credentials

In production (`AUTH_MODE=firebase`, the default) the backend verifies ID tokens
with the Firebase Admin SDK, which needs service-account credentials.

Point `GOOGLE_APPLICATION_CREDENTIALS` at a service-account JSON file:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-service-account.json
export AUTH_MODE=firebase          # (default)
uvicorn main:app --host 0.0.0.0 --port 8000
```

Get the JSON from the Firebase console:
**Project settings → Service accounts → Generate new private key**. Keep it
secret — never commit it. Optionally set `FIREBASE_PROJECT_ID` to pin the
project (it is usually inferred from the key).

If `GOOGLE_APPLICATION_CREDENTIALS` is unset, the SDK falls back to
**Application Default Credentials** (e.g. the metadata server on Google Cloud).

### In Docker

`docker-compose.yml` runs just the API service. Mount your service-account JSON
into the container and point `GOOGLE_APPLICATION_CREDENTIALS` at it:

```yaml
    environment:
      AUTH_MODE: firebase
      GOOGLE_APPLICATION_CREDENTIALS: /run/secrets/firebase-service-account.json
    volumes:
      - ./firebase-service-account.json:/run/secrets/firebase-service-account.json:ro
```

```bash
docker compose up --build
```

---

## 4. Turn on the hardened code sandbox

By default `/run` and code `/submit` use a **subprocess** runner. That's fine on
your own machine, but it is **not** safe for code from strangers. For that, use
the Docker sandbox.

```bash
# a) Build the tiny sandbox image once
docker build -t codequest-sandbox ./sandbox

# b) Tell the app to use it (needs a running Docker daemon)
export SANDBOX_MODE=docker
uvicorn main:app --reload
```

Each submission then runs in a throwaway container with **no network**, a
**read-only filesystem**, capped **memory / CPU / process count**, and as the
non-root `nobody` user.

---

## 5. Configuration

All settings have safe defaults (see `config.py`); override via environment
variables or a `.env` file (copy `.env.example`).

| Variable                         | Default             | Meaning                                            |
| -------------------------------- | ------------------- | -------------------------------------------------- |
| `AUTH_MODE`                      | `firebase`          | `firebase` (verify tokens) or `insecure_dev` (bypass) |
| `GOOGLE_APPLICATION_CREDENTIALS` | *(unset → ADC)*     | Path to a Firebase service-account JSON            |
| `FIREBASE_PROJECT_ID`            | *(unset)*           | Optional Firebase project id                       |
| `SANDBOX_MODE`                   | `subprocess`        | `subprocess` (dev) or `docker` (safe)              |
| `SANDBOX_IMAGE`                  | `codequest-sandbox` | Sandbox image name for docker mode                 |
| `RUN_TIMEOUT_S`                  | `3.0`               | Seconds a submission may run                       |
| `RUN_RATE_MAX`                   | `30`                | Max `/run` requests per user per window            |
| `RUN_RATE_WINDOW_S`              | `60`                | `/run` rate-limit window (seconds)                 |
| `SUBMIT_RATE_MAX`                | `60`                | Max `/submit` requests per user per window         |
| `SUBMIT_RATE_WINDOW_S`           | `60`                | `/submit` rate-limit window (seconds)              |

Rate limits are **per Firebase user**; exceeding one returns **HTTP 429** with a
**`Retry-After`** header. The limiter is in-memory / per-process — see the
single-instance caveat under [Endpoints](#2-endpoints) (use **Redis** for
multi-instance).

---

## ⚠️ Security notes

- **Subprocess mode is development-only.** It applies OS-level limits (timeout,
  CPU/memory/file limits, minimal env) but is **not** a real security boundary.
- The **Docker sandbox** (`SANDBOX_MODE=docker`) is what makes accepting public
  code submissions safe: no network, read-only filesystem, memory/CPU/pids caps,
  and a non-root user. Enable it before exposing `/run` or `/submit` to the
  internet.
- **`AUTH_MODE=insecure_dev` is a local bypass only.** It skips Firebase token
  verification and must never be enabled in production. Keep the default
  `AUTH_MODE=firebase` for any real deployment.

---

## Project layout

```
backend/
├── main.py            # FastAPI app + all endpoints (stateless)
├── config.py          # Settings (env / .env) -> `settings` singleton
├── schemas.py         # Pydantic request/response models (run + submit)
├── firebase_auth.py   # Firebase Admin init + get_current_identity dependency
├── ratelimit.py       # Per-user in-memory sliding-window limiter (429 + Retry-After)
├── content.py         # Canonical worlds/missions + public_challenge()
├── runner.py          # Code runner: subprocess + docker dispatcher
├── runner_docker.py   # Hardened Docker sandbox
├── sandbox/Dockerfile # Minimal image for the sandbox
├── Dockerfile         # API image for deployment
├── docker-compose.yml # The API service (no database)
├── requirements.txt
├── .env.example
└── README.md
```

Accounts and progress are **not** here — they live in **Firebase Auth + Cloud
Firestore**, written directly by the Flutter app.
