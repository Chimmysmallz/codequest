# CodeQuest — Flutter App

CodeQuest is a mobile game that teaches kids Python through short, playful
missions across five worlds (Village → Forest → Factory → Castle → Space
Station). This folder holds the **Flutter client**. The companion Python
**FastAPI backend** lives in `../backend`.

## Prerequisites

- Flutter SDK **3.x** (Dart `>=3.0.0 <4.0.0`)
- An emulator/simulator or a connected device (Android, iOS, desktop or web)

## Run it

```bash
flutter pub get
flutter run
```

The app plays **offline out of the box** using content bundled in
`lib/data/seed_content.dart`, so you can run it without the backend or an
account.

> **Firebase setup required for accounts.** Accounts and cloud save use
> **Firebase Auth** + **Cloud Firestore**. Before signing in works you must
> generate the Firebase config with the FlutterFire CLI:
>
> ```bash
> dart pub global activate flutterfire_cli
> flutterfire configure
> ```
>
> This overwrites the placeholder `lib/firebase_options.dart` with your real
> project keys and drops `android/app/google-services.json` and
> `ios/Runner/GoogleService-Info.plist` into place. Until you do this, the app
> still compiles and **guest play works**, but Firebase will not connect, so
> sign-in / register will fail. Enable **Email/Password** sign-in and create a
> **Firestore** database in the Firebase console.

## Backend URL

The client talks to the backend through `lib/services/api_service.dart`. Set
`baseUrl` to match where the backend is reachable **from the device running the
app**:

- **Android emulator** (default): `http://10.0.2.2:8000`
- **iOS simulator / desktop / web**: `http://localhost:8000`
- **Physical device**: `http://<your-computer-lan-ip>:8000`

```dart
// lib/services/api_service.dart
ApiService({ this.baseUrl = 'http://10.0.2.2:8000', ... });
```

Start the backend first (see `../backend/README.md`), then launch the app. On
startup the app pings `GET /health`; if it succeeds the app switches to
**online mode** (an "Online" badge appears on the Home and World Map screens).

## Offline vs. online

The game is **fully playable offline and without an account**. Signing in is
optional and only adds cloud save + cross-device sync.

| Challenge type | Guest / offline | Signed in + backend up |
| --- | --- | --- |
| **Fill-in-the-blank** | Checked locally against the bundled answer. Fully playable. | Checked by the server via `POST /submit` (answers stay hidden server-side). |
| **Code (real Python)** | Cannot execute — the app shows a friendly *"Sign in to run and check real code"* message. | `POST /run` previews output; `POST /submit` runs, checks and awards. |

Because `/run` and `/submit` are protected endpoints, running and grading **real
Python** requires being signed in (the request carries the user's Firebase ID
token). Fill-in-the-blank stays fully playable as a guest — it is graded locally
against the bundled answers.

Progress (XP, coins, completed missions, unlocks) is persisted **per user in
Cloud Firestore** when signed in (document `users/{uid}`), and in
`shared_preferences` as a **guest cache** when not signed in, so a guest never
loses their place. On sign-in, local guest progress is merged **once** with the
user's Firestore progress (union of completed missions, max XP/coins) and the
merged result is written back to Firestore and adopted as the source of truth.
Firestore's offline persistence (on by default on mobile) keeps cloud save
working without a connection.

### Robot missions (Flame)

"Help the Robot!" style missions — fill-in-the-blank loop challenges whose
template drives `robot.move()` — use the **Flame** 2D game engine to animate the
robot. When the player picks the correct piece, the robot visibly **walks**
across a lane to the charging pad (one step per `range(N)` loop iteration) before
the result screen appears; a wrong answer just reveals the hint as usual. The
scene lives in `lib/game/robot_run_game.dart` and is hosted via a `GameWidget`
only on robot missions — all other challenges are unchanged. Flame
(`flame: ^1.18.0`) was added to `pubspec.yaml` for this.

## Leaderboard

Signed-in players are ranked by **XP** on a public leaderboard
(`lib/screens/leaderboard_screen.dart`, opened from the **Leaderboard** button
on Home).

- **Separate public collection.** Ranking data lives in its own
  `leaderboard/{uid}` collection — **never** the private `users/{uid}` docs —
  holding only `{displayName, xp, level, updatedAt}`. Security rules let any
  signed-in user **read** the collection, but a user may **write only their own**
  `leaderboard/{uid}` row (rules are applied separately alongside the Firestore
  setup).
- **Kept in sync automatically.** Every time signed-in progress is persisted
  (e.g. after completing a mission), the app republishes the player's row via
  `publishLeaderboard(...)`, so XP/level stay current. The row is also seeded on
  first sign-in.
- **Ranking query.** `collection('leaderboard').orderBy('xp', descending: true)
  .limit(N)` — a single-field `orderBy`, so **no composite index** is needed.
- **Display names.** `displayName` is the player's public handle. It defaults to
  the email's local part (before `@`, sanitized) on sign-in and is **editable**
  from the leaderboard's app-bar pencil (`game.setDisplayName(...)`), which
  updates both the `users/{uid}` doc and the `leaderboard/{uid}` row.
- **Own row highlighted**; the top three get 🥇🥈🥉. The screen loads with a
  spinner, supports pull-to-refresh, and shows friendly empty states for guests
  ("Sign in to join the leaderboard") and an empty board. Guest play is
  unaffected — the leaderboard simply prompts guests to sign in.

## Accounts & sign in

CodeQuest uses **Firebase Auth** (email/password) for accounts and **Cloud
Firestore** for per-user progress. The backend is no longer involved in auth.

- **Guest first.** The app opens straight into the game — there is no login
  wall. A "Sign in to save your progress" banner on Home is the only nudge.
  Guest progress is cached locally in `shared_preferences`.
- **Register / Login.** From Home → the sign-in banner (or Settings → Sign In)
  you can create an account (`createUserWithEmailAndPassword`) or log in
  (`signInWithEmailAndPassword`). On the first sign-in, local guest progress is
  merged once with the user's Firestore progress and written back to Firestore.
- **Forgot password.** The login screen has a "Forgot password?" action that
  calls `sendPasswordResetEmail` and confirms with a SnackBar.
- **Token persistence.** Firebase manages its own session/token persistence —
  there is no `flutter_secure_storage` and no manual token handling. The app
  reacts to `authStateChanges()` to switch between guest and cloud mode.
- **ID token → backend.** The only backend calls are `POST /run` and
  `POST /submit`. Each sends the current user's **Firebase ID token**
  (`currentUser.getIdToken()`) as an `Authorization: Bearer <idToken>` header;
  the backend verifies it with the Firebase Admin SDK and identifies the user
  from it, so submissions never send a `userId`.
- **Startup.** `Firebase.initializeApp` runs in `main()` before the app starts.
  If a Firebase session is already persisted, `authStateChanges()` fires with
  the signed-in user and progress syncs automatically; otherwise the app stays
  in guest mode with local progress.
- **Sign out.** Settings → Sign Out calls `FirebaseAuth.signOut()` and returns
  to guest mode, falling back to the local guest progress cache.

### Rules mirrored on the client

- `XP_PER_LEVEL = 250`; `level = 1 + xp ~/ 250`; `xpIntoLevel = xp % 250`.
- A world is unlocked when its order is `0`, or when **every** mission in the
  previous world (by order) is completed.
- On a pass the mission's XP + coins are awarded once (double-award guarded),
  the mission is marked complete, unlocks recompute, and state persists.
- Stars are `3` per completed mission (MVP).

## Folder structure

```
app/
├── pubspec.yaml
├── assets/art/                 # bundled artwork (already provided)
└── lib/
    ├── main.dart               # Firebase.initializeApp + GameState provider + MaterialApp
    ├── firebase_options.dart   # PLACEHOLDER — regenerate with `flutterfire configure`
    ├── theme/app_theme.dart    # AppColors palette + AppTheme.dark
    ├── models/                 # world, challenge, mission, player_progress, user (AppUser), leaderboard_entry
    ├── data/seed_content.dart  # canonical offline content (single source of truth)
    ├── services/
    │   ├── api_service.dart            # FastAPI client (health, content, run, submit) — ID-token auth
    │   ├── firebase_auth_service.dart  # FirebaseAuth wrapper: register/signIn/signOut/reset/idToken
    │   ├── firestore_service.dart      # users/{uid} progress + public leaderboard/{uid} rows
    │   └── local_store.dart            # shared_preferences guest-progress cache
    ├── providers/game_state.dart  # ChangeNotifier: content, progress, auth, online/offline, grading
    ├── game/robot_run_game.dart   # Flame scene: robot walks to the charging pad (robot missions)
    ├── widgets/                # primary_button, xp_bar, world_tile, reward_chip
    └── screens/                # splash, home, login, register, world_map, mission, code_challenge, result, leaderboard
```

## Backend API contract

The backend is now used **only for running and grading real Python**. Auth and
progress moved to Firebase Auth + Firestore, so the `/auth/*` and `/progress/*`
endpoints are gone.

| Method & path | Auth | Purpose |
| --- | --- | --- |
| `GET /health` | – | `{status:"ok"}` health check |
| `GET /content` | – | worlds + missions (answers hidden server-side) — optional |
| `POST /run` | Firebase ID token | `{code}` → `{output,error,timedOut}` |
| `POST /submit` | Firebase ID token | `{missionId,answer?,code?}` → grade (+ output) |

The `Bearer` token on `/run` and `/submit` is the caller's **Firebase ID token**
(`Authorization: Bearer <idToken>`); the backend verifies it with the Firebase
Admin SDK. Fill-in-the-blank is always graded **locally on the client** against
the bundled answers (both guest and signed-in), so it stays fully playable
offline; only code challenges call the backend.
