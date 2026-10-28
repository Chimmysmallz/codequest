# Testing CodeQuest end to end

This guide takes you from a downloaded zip to a fully tested platform. It is written for a beginner. Do the parts in order. Each part says what "passed" looks like.

| Part | What it proves | Needs | Time |
|---|---|---|---|
| 1. GitHub automatic checks | Everything works on a clean computer | A GitHub account | 20 min |
| 2. Play the game | The game boots and plays on your machine | Godot | 10 min |
| 3. Automated game test | The game can be won and lost correctly | Godot | 5 min |
| 4. Backend on your computer | The server runs code and grades answers | Python 3 | 15 min |
| 5. Security rules | Players cannot read or change other players' data | Node.js, Java | 15 min |
| 6. Full stack with real Firebase | Login, progress and leaderboard work for real | Flutter, Firebase | 1 to 2 hours |

---

## Part 1. Let GitHub test everything for you (start here)

GitHub can run every test on its own computers for free. You do not need to install anything for this part.

1. Unzip `codequest-github.zip`. You get a folder called `codequest`.
2. Go to **github.com** → sign in with your **personal** account → click **+** (top right) → **New repository**.
3. Name it `codequest`, choose **Private**, and do **not** tick "Add a README". Click **Create repository**.
4. Upload the files. Pick one way:
   - **GitHub Desktop (easiest):** File → Add local repository → choose the `codequest` folder → "create a repository here" → **Commit to main** → **Publish repository** (keep "private" ticked).
   - **Browser:** on the new empty repository page, click **uploading an existing file**, then drag in **everything inside** the `codequest` folder (including the hidden `.github` folder and `.gitignore`), then **Commit changes**.
     Tip: hidden files start with a dot. On Windows turn on View → Show → Hidden items. On a Mac press Cmd+Shift+. in Finder.
5. Click the **Actions** tab. If asked, click **I understand my workflows, go ahead and enable them**.
6. Click **CodeQuest CI** → **Run workflow** → **Run workflow**. Wait 5 to 10 minutes.

**Passed looks like:** four green ticks.

| Job | What it checked |
|---|---|
| Game (Godot e2e play-through) | Godot opened the project, booted the game for 300 frames with no errors, then auto-played it: 12 glitches spawn, the loop power stays between 1 and 5, clearing every glitch shows "WORLD RESTORED", restart works, and touching a glitch at 1 HP shows "DOWN". |
| Backend (API tests + live smoke test) | 20 API tests, then a real server started and the smoke test walked the full player path. Also built the Docker sandbox image. |
| Firestore security rules (emulator) | 8 tests proving the data lock. |
| Flutter app (dependencies + analysis) | The app's packages download and the code has no errors. |

**If one is red:** click it, then click the red step to read the message. Copy the last 20 lines of red text into any AI assistant (or to a developer) along with the file it names.

From now on, every time you upload a change, these checks run again on their own.

---

## Part 2. Play the game on your computer

1. Install **Godot 4.3 or newer, Standard version** from godotengine.org/download.
2. Open Godot → **Import** → browse to `codequest/game/project.godot` → **Import & Edit**.
3. Press **F5**.

**Passed looks like:** a portrait game window. You can:
- [ ] drag the lower-left circle to move, and the world scrolls with you
- [ ] see five landmarks (village, forest, factory, castle, station)
- [ ] follow the gold arrow to a group of glitches
- [ ] tap STRIKE to hit, tap DASH to blitz
- [ ] tap **+** to change `range(3)` to `range(5)` and feel the dash hit more times
- [ ] clear all 12 glitches and see "WORLD RESTORED"
- [ ] lose all health and see "DOWN", then tap to retry

---

## Part 3. Run the automated game test yourself

This plays the game for you in a few seconds, without a window.

1. Open a terminal in the `codequest` folder.
2. Run (replace the first word with the full path to your Godot program if needed):
   ```
   godot --headless --path game --script res://tests/e2e_test.gd
   ```
   On Windows the program is called something like `Godot_v4.3-stable_win64_console.exe`. Use the **console** version so you can see the output.

**Passed looks like:** a list of `PASS` lines ending in `E2E PASS`.

---

## Part 4. Test the backend on your computer

1. Install **Python 3.12** from python.org (on Windows tick "Add Python to PATH").
2. Run the tests:
   - Windows: double-click `scripts/run-all-tests.bat`
   - Mac/Linux: `./scripts/run-all-tests.sh`

   **Passed looks like:** `20 passed`.
3. Start the server:
   - Windows: double-click `scripts/run-backend-dev.bat`
   - Mac/Linux: `./scripts/run-backend-dev.sh`
4. Open **http://localhost:8000/docs** in a browser. You can try every endpoint there. For example, open **POST /run** → **Try it out** → put `{"code": "print(\"Zap\")"}` → **Execute**. The response shows `Zap`.
5. With the server still running, open a second terminal in the `codequest` folder and run:
   ```
   python scripts/e2e_smoke.py
   ```
   **Passed looks like:** `7/7 checks passed`.

Note: these scripts use dev mode (`AUTH_MODE=insecure_dev`), which accepts anyone. That is only for testing. Production uses real Firebase login.

---

## Part 5. Test the database security rules

1. Install **Node.js 20 LTS** (nodejs.org) and **Java 21** (adoptium.net). The Firebase emulator needs Java.
2. In a terminal in the `codequest` folder:
   ```
   npm i -g firebase-tools
   npm i --prefix firebase-tests
   firebase emulators:exec --only firestore --project demo-codequest "npm --prefix firebase-tests test"
   ```
   `demo-codequest` is a pretend project that only exists on your computer. Nothing is sent to Google and it costs nothing.

**Passed looks like:** `pass 8` and `fail 0`.

---

## Part 6. Full stack with real Firebase (the true end to end)

This is the only part that needs your own Firebase project. Follow `docs/FIREBASE_SETUP.md` for the clicks. Summary:

1. **Firebase:** create a project, turn on Email/Password sign-in, create Firestore, and publish the rules:
   ```
   firebase login
   firebase use --add          (pick your project)
   firebase deploy --only firestore:rules
   ```
2. **Backend with real login:** in `backend/`, copy `.env.example` to `.env`, set `AUTH_MODE=firebase` and point `GOOGLE_APPLICATION_CREDENTIALS` at your downloaded service-account key. Start it with `uvicorn main:app --host 0.0.0.0 --port 8000` (inside the `.venv` the scripts created).
3. **Flutter app:** install Flutter (flutter.dev), then in `app/`:
   ```
   flutter create . --platforms=android,ios --org app.codequest
   dart pub global activate flutterfire_cli
   flutterfire configure
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```
   Use `http://localhost:8000` instead for the iPhone simulator. For a real phone on the same Wi-Fi, use your computer's IP address, for example `http://192.168.1.20:8000`.
   The first command only adds the missing Android and iOS folders. It does not change your code.

**Passed looks like:**
- [ ] you can register, sign out and sign back in
- [ ] "Forgot password?" sends a reset email
- [ ] finishing a mission adds XP and coins
- [ ] in the Firebase console → Firestore → Data, you see `users/<your id>` and `leaderboard/<your id>`
- [ ] close and reopen the app: your progress is still there
- [ ] the Leaderboard screen shows your name and XP
- [ ] a second test account cannot see the first account's `users` document (Part 5 proves this automatically)

---

## Before going live

- Set `AUTH_MODE=firebase` and `SANDBOX_MODE=docker` on the server. Never deploy dev mode.
- Lock `CORS_ORIGINS` to your real domain.
- Serve the backend over HTTPS.
- Run the smoke test against the live server:
  ```
  python scripts/e2e_smoke.py --url https://api.yourdomain.com --token <a Firebase ID token>
  ```
  The last line should say login is enforced.
