# CodeQuest

A mobile 2D action-adventure that teaches Python. You explore a world, fight "glitch" creatures, and power up your dash by editing a real Python loop: `for i in range(n): strike()`.

Prepared by Chiamaka Nwabulue.

---

## What is in this repository

| Folder | What it is |
|---|---|
| `game/` | **The game.** Godot 4 project (GDScript). Touch controls, open world, follow camera. |
| `game/tests/` | Automated play-through test for the game. |
| `backend/` | Python (FastAPI) server: serves missions, runs player code safely, checks answers. Firebase login, rate limits. |
| `backend/tests/` | API tests (pytest). |
| `firestore.rules` | Database security rules ("each player can only touch their own data"). |
| `firebase-tests/` | Tests that prove those rules work, using the free Firebase emulator. |
| `app/` | Earlier Flutter app (login, leaderboard, quiz screens). Kept for its Firebase parts. |
| `scripts/` | One-click helpers: start the backend, run the tests, live smoke test. |
| `docs/` | Owner's manual, Firebase setup, notes, and early HTML prototypes. |
| `.github/workflows/ci.yml` | GitHub runs every test automatically each time you upload changes. |

---

## Quick start

### Play the game
1. Install **Godot 4.3 or newer (Standard)** from godotengine.org.
2. Godot → **Import** → choose `game/project.godot` → **Import & Edit**.
3. Press **F5**. Your mouse acts as a finger: drag lower-left to move, click STRIKE and DASH.

### Start the backend (no Firebase needed)
- Windows: double-click `scripts/run-backend-dev.bat`
- Mac/Linux: `./scripts/run-backend-dev.sh`

Then open http://localhost:8000/docs to try every endpoint in your browser.

### Run all the checks
Upload the repository to GitHub and open the **Actions** tab. Four green ticks mean the game, the backend, the security rules and the app all passed.

The full step-by-step guide is in **[TESTING.md](TESTING.md)**.

---

## Never upload secrets

The `.gitignore` file already blocks `.env`, `serviceAccountKey.json`, signing keys and build files. Keep it that way. If a secret is ever uploaded by mistake, treat it as leaked: create a new key in Firebase and delete the old one.
