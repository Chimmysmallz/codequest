# Firebase setup — step by step

CodeQuest now uses **Firebase Auth** for login and **Cloud Firestore** for saving progress.
Your own Python backend stays, but only to run code safely. This is a **one-time setup** in the
Firebase console plus one command that generates your config. Follow it top to bottom.

> You'll need a Google account. Everything here is free at the scale you'll start at.

---

## Part A — Create the Firebase project (in your browser)

1. Go to **console.firebase.google.com** and click **Add project**.
2. Name it `codequest` (or anything), accept the terms, and finish. Analytics is optional — you
   can turn it off.
3. In the left menu, open **Build → Authentication → Get started**.
   - Open the **Sign-in method** tab, click **Email/Password**, toggle it **on**, and Save.
4. In the left menu, open **Build → Firestore Database → Create database**.
   - Choose **Production mode** (we'll add rules next), pick a location close to your users, Enable.
5. In Firestore, open the **Rules** tab. Delete what's there, paste the contents of
   **`firestore.rules`** (in this project), and click **Publish**. This locks each user to their
   own data.

✅ Firebase now handles accounts and stores progress.

---

## Part B — Connect the Flutter app

You'll replace the placeholder `app/lib/firebase_options.dart` with your real project config.
A single command does it.

1. **Install the tools** (one time):
   ```bash
   npm install -g firebase-tools          # the Firebase CLI
   firebase login                         # sign in with your Google account
   dart pub global activate flutterfire_cli
   ```
2. **Generate your config** — from inside the `app/` folder:
   ```bash
   cd app
   flutterfire configure
   ```
   Pick your `codequest` project and the platforms (Android/iOS). This **overwrites**
   `lib/firebase_options.dart` with real values and adds the platform files
   (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) automatically.
3. **Run it:**
   ```bash
   flutter pub get
   flutter run
   ```
4. In the app, tap **Sign in → Create account**, register a test email, and play. Your progress
   now saves to Firestore — check the **Firestore → Data** tab in the console and you'll see a
   `users/{your-id}` document appear. 🎉

---

## Part C — Connect the backend (so code challenges work)

The backend verifies each player's Firebase login before running their Python.

1. In the Firebase console: **Project settings (gear icon) → Service accounts →
   Generate new private key**. A JSON file downloads.
2. Save it as **`backend/serviceAccountKey.json`**. **Never commit this file** — it's a secret
   (add it to `.gitignore`).
3. In `backend/.env` set:
   ```
   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
   AUTH_MODE=firebase
   ```
4. Start the backend (`uvicorn main:app --reload`). It will now accept the app's Firebase tokens.

**Local shortcut:** to test the backend *without* the service account, set `AUTH_MODE=insecure_dev`.
This skips token checks and is **for local development only — never deploy with it.**

---

## Part D — Security reminders

- **`serviceAccountKey.json` is a secret.** Keep it out of Git and out of the app. Only your
  server holds it.
- **`firestore.rules` is your data lock.** The provided rules already stop users from reading or
  writing anyone else's data. Re-check them before launch.
- **Turn the code sandbox on** in production (`SANDBOX_MODE=docker`) — Firebase secures your data,
  but running kids' Python safely is still your backend's job.
- **Kids' app:** COPPA / GDPR-K rules apply — collect minimal data and plan for parental consent.

---

## What lives where now

| Concern              | Handled by            |
| -------------------- | --------------------- |
| Login / passwords / reset | **Firebase Auth**  |
| Saving progress & accounts | **Cloud Firestore** (rules-protected) |
| Running Python safely | **Your FastAPI backend** (`/run`, `/submit`) |
| Deciding a code answer is correct | **Your FastAPI backend** |
| Game content & art   | **Bundled in the app** |
