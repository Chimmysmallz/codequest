# CodeQuest 🤖

A mobile game that *happens to teach Python*. Kids move through worlds (Village → Forest →
Factory → Castle → Space Station), solve fill-in-the-blank and real-code challenges, and earn
XP, coins, and cosmetics.

**Stack:** a **Flutter** app using **Firebase Auth** (login) and **Cloud Firestore** (saved
progress), plus **your own Python (FastAPI)** backend that safely runs and checks submitted code.
Firebase secures the data; your server does the one thing Firebase can't — run untrusted Python.

> **Heads up:** this was scaffolded without a Flutter/Dart SDK, so the app was **not compiled
> here** — your first `flutter run` (after Firebase setup) is the compile check. The backend's
> code-runner logic *was* run and tested; the Firebase-facing code is syntax-checked (its
> libraries can't be installed in this scaffolding sandbox).

---

## Architecture

```
┌─────────────────────────────┐
│         Flutter app         │
│  (app/)                     │
│  • 6 game screens + Flame   │        ┌──────────────────────────────┐
│  • login / register / reset │ ─────► │ Firebase Auth  (Google-managed)│  login, tokens, reset
│                             │        └──────────────────────────────┘
│                             │        ┌──────────────────────────────┐
│                             │ ─────► │ Cloud Firestore (rules-locked)│  users/{uid} progress
│                             │        └──────────────────────────────┘
│                             │        ┌──────────────────────────────┐
│                             │ ─────► │ YOUR FastAPI backend         │  /run + /submit
│   sends Firebase ID token ──┼──────► │ (backend/) verifies the token│  runs Python in a sandbox
└─────────────────────────────┘        └──────────────────────────────┘
```

- **Firebase Auth** owns accounts, sessions, password reset — no auth code to maintain.
- **Cloud Firestore** stores each player's progress at `users/{uid}`, protected by
  `firestore.rules` (a user can only touch their own data), with offline caching built in.
- **Your FastAPI backend** is now a small, stateless service: it serves game content, runs
  submitted Python in a hardened sandbox, checks answers, and authenticates callers by
  **verifying their Firebase ID token**. It stores nothing.

The app still **plays offline as a guest** (fill-in-the-blank works with bundled content).
Signing in saves progress to Firestore and syncs across devices. Real-code missions need the
backend running.

---

## ⚠️ Setup is required before it runs — see `FIREBASE_SETUP.md`

Because it uses Firebase, you must create a (free) Firebase project once and generate your config.
**Follow `FIREBASE_SETUP.md` first** — it's click-by-click. In short:

1. Create a Firebase project; enable **Email/Password** auth; create **Firestore**; publish
   `firestore.rules`.
2. In `app/`, run `flutterfire configure` (replaces the placeholder `lib/firebase_options.dart`).
3. Download a **service-account key** for the backend and set `GOOGLE_APPLICATION_CREDENTIALS`.

---

## Folder structure

```
codequest/
├── FIREBASE_SETUP.md             # ← do this first
├── firestore.rules               # your data-access lock
├── app/                          # Flutter front end
│   ├── pubspec.yaml
│   ├── assets/art/               # the 8 generated images
│   └── lib/
│       ├── main.dart             # initializes Firebase
│       ├── firebase_options.dart # PLACEHOLDER — regenerate with flutterfire configure
│       ├── theme/  models/  data/  widgets/
│       ├── game/                 # Flame robot scene
│       ├── services/             # firebase_auth_service, firestore_service, api_service
│       ├── providers/            # game_state.dart
│       └── screens/              # splash, login, register, home, world_map,
│                                 #   mission, code_challenge, result
└── backend/                      # Python API (your code — runs Python safely)
    ├── requirements.txt
    ├── .env.example
    ├── config.py                 # settings from env vars
    ├── firebase_auth.py          # verifies Firebase ID tokens
    ├── schemas.py                # run/submit request+response models
    ├── content.py                # worlds + missions (answers live here, server-side)
    ├── runner.py                 # picks subprocess vs docker sandbox
    ├── runner_docker.py          # the hardened Docker sandbox
    ├── sandbox/Dockerfile        # image used to run submitted code
    ├── main.py                   # FastAPI app: /health /content /run /submit
    ├── Dockerfile                # to deploy the backend
    └── docker-compose.yml        # runs the backend
```

---

## Run it (after `FIREBASE_SETUP.md`)

### Backend — the code runner
```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # set GOOGLE_APPLICATION_CREDENTIALS + AUTH_MODE=firebase
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Check it: <http://localhost:8000/health> → `{"status":"ok"}`.
(For a quick local test without the service key, set `AUTH_MODE=insecure_dev` — **dev only**.)

### App
```bash
cd app
flutter pub get
flutter run
```
Set the backend URL in `app/lib/services/api_service.dart` (`baseUrl`): `http://10.0.2.2:8000`
for the Android emulator, `http://localhost:8000` for iOS simulator / desktop / web.

---

## The four backend endpoints

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /health` | public | liveness check |
| `GET /content` | public | worlds + missions (answers hidden) |
| `POST /run` | Firebase token | run Python, return its output |
| `POST /submit` | Firebase token | check a mission answer, return pass/fail + earned XP/coins |

The backend never stores progress — the app writes it to Firestore. The app sends the player's
Firebase ID token as `Authorization: Bearer <token>` on `/run` and `/submit`.

---

## ⚠️ Security posture

- **Firebase secures your data** (rules-protected Firestore, managed auth). Keep `firestore.rules`
  tight and never commit `serviceAccountKey.json`.
- **Your sandbox secures code execution.** Run production with `SANDBOX_MODE=docker` (no network,
  read-only, capped, non-root). The subprocess mode is dev-only.
- **Never trust the app.** The server re-checks code answers; the app can't fake a code pass.
  Firestore rules stop a user from writing anyone else's progress.
- **HTTPS + locked-down CORS** before launch; **kids' app** → COPPA/GDPR-K (parental consent,
  minimal data).

---

**Already included:** ✅ per-user **rate limiting** on `/run` and `/submit` (HTTP 429 + Retry-After;
tunable in `config.py`) · ✅ a Firestore **leaderboard** (`leaderboard/{uid}`, ranked by XP, rules-locked).

## Where to take it next

1. **Server-authoritative XP** — have the backend write progress + leaderboard entries via the
   Firebase Admin SDK if you want to fully prevent client-side cheating.
2. **Redis-backed rate limiting** — the current limiter is per-process; use Redis for multiple
   backend instances.
3. **Typed-Python levels**, more worlds, daily challenges, the coin shop.
4. **Deploy** the backend `Dockerfile` to a host you control.

You own the parts that matter — the game, the content, and the code sandbox — while Firebase
handles the security-heavy data and login layer. 🚀
