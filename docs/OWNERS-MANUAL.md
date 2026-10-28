# CodeQuest: Owner's Manual

Prepared by Chiamaka Nwabulue. Last updated 25 October 2026.

This manual lets you keep building CodeQuest without any AI assistant. It covers what you own, where to keep it, what to install, how the game works, and how to change it.

---

## 1. What you own

| Folder / file | What it is | Status |
|---|---|---|
| `codequest-godot/` | **The main game.** A mobile action-adventure built in Godot 4. Open world, thumb-stick, STRIKE and DASH buttons, loop-powered dash. | **Active. Keep building this one.** |
| `codequest/app/` | An earlier Flutter app (quiz-style screens, Firebase login, leaderboard). | Retired for gameplay. Its login, leaderboard and Firebase parts can come back later. |
| `codequest/backend/` | A Python (FastAPI) server that runs kids' Python code safely in a sandbox, with rate limits. | Keep. You need it later if players type real Python. |
| `codequest/firestore.rules` and `FIREBASE_SETUP.md` | Database security rules and the Firebase setup guide. | Keep, for later. |
| `codequest-action-demo.html` | Browser test of the real-time controls. | Reference only. |
| `codequest-story-demo.html`, `codequest-figma-flow.html`, `codequest-mockup.html` | Early design prototypes. | Reference only. |
| `assets/` folders | All the character and world art (PNG files). | Keep. You own these. |

---

## 2. Protect your copy first (do this today)

Everything was created in your **work** OneDrive (`Documents/Cowork`). If you leave the job or lose that account, those files go with it.

1. **Check your company's IT policy** on copying files from your work OneDrive to personal storage. This is your personal project, but follow the rules that apply to your work account.
2. **Download the backup file** `codequest-full-backup.zip` to your **personal** computer.
3. **Make a second copy somewhere else you own**: a personal Google Drive, personal OneDrive, a USB stick, or (best) a private GitHub repository (see section 4).
4. Use a **personal email address** for every account below (Godot needs none, but GitHub, Firebase, Google Play and Apple do). Do not tie them to your work email.

The rule: **at least two copies, at least one off your work account.**

---

## 3. The tools you need (all free unless marked)

### Needed now
| Tool | What it does | Where to get it |
|---|---|---|
| **Godot 4 (Standard, not .NET)** | The game engine and its built-in code editor. This is the only tool needed to play and change the game. | godotengine.org/download |
| **Git** | Saves every version of your project so nothing is ever lost. | git-scm.com/downloads |
| **GitHub account + GitHub Desktop** | Online backup of your code, with a simple click-based app. No command line needed. | github.com and desktop.github.com |

### Nice to have
| Tool | Why |
|---|---|
| **VS Code** (with the "godot-tools" extension) | A more comfortable code editor. Optional. Godot's own editor is enough. |
| **Krita** or **GIMP** | Free image editors for drawing or touching up art. |
| **Aseprite** (paid, about $20) or **LibreSprite** (free) | Pixel art and sprite-sheet animation, for when the hero gets real walk frames. |
| **Audacity** + **jsfxr / sfxr** | Free sound recording and retro sound-effect makers. |

### Needed later, for putting the game on phones
| Tool | Why |
|---|---|
| **Android Studio** (or just the Android SDK) + **OpenJDK 17** | Godot uses these to build the Android app file. |
| **Godot export templates** | Download inside Godot: *Editor → Manage Export Templates → Download*. |
| **Google Play Console** ($25 once) | Publishing on Android. |
| **A Mac + Xcode + Apple Developer account** ($99 a year) | Publishing on iPhone. |

### Needed only if you bring back the Python backend or Firebase
Python 3, Docker Desktop, Node.js, the Firebase CLI (`npm install -g firebase-tools`), and a Firebase account. The steps are in `codequest/README.md` and `codequest/FIREBASE_SETUP.md`.

---

## 4. Put the game on GitHub (your permanent home)

Using GitHub Desktop, no typing of commands:

1. Install GitHub Desktop and sign in with your **personal** GitHub account.
2. **File → Add local repository** → choose your `codequest-godot` folder. When it says "this is not a Git repository", click **create a repository here**.
3. Make sure **Git ignore** is set. A ready-made `.gitignore` file is already in the folder. It stops Godot's temporary `.godot/` folder from being uploaded.
4. Click **Commit to main**, then **Publish repository**. Tick **Keep this code private**.
5. From now on, after each work session: write a short note (for example "Added castle boss") → **Commit** → **Push origin**.

If you ever need to roll back, GitHub Desktop's **History** tab shows every saved version.

Do the same for the `codequest` folder if you keep the app and backend. **Never upload** `.env` files or `serviceAccountKey.json`. The `.gitignore` already blocks them.

---

## 5. Open and run the game

1. Open Godot → **Import** → browse to `codequest-godot` → select `project.godot` → **Import & Edit**.
2. Wait for the art to import, then press **F5** (or the ▶ button, top right).
3. On a laptop, your mouse acts as a finger: drag the lower-left circle to move, click STRIKE and DASH.

---

## 6. How the game is built (so you can change it)

The whole game is in **one script**: `codequest-godot/main.gd`. The scene file `main.tscn` just loads it. Here is the map.

### Easy numbers to tweak (top of `main.gd`)
| Line starts with | What it controls |
|---|---|
| `const SW` / `const SH` | Screen size (450 × 800, portrait phone). |
| `const WORLD_W` / `const WORLD_H` | Size of the explorable world (1800 × 1400). Bigger = more to explore. |
| `const MOVE_SPEED` | How fast the hero walks. |
| `const DASH_SPEED` | How fast the dash is. |
| `const ENEMY_SPEED` | How fast glitches chase you. |
| `const CHASE_RANGE` | How close you must get before glitches wake up. |
| `const JOY_HOME`, `STRIKE_C`, `DASH_C` (and the `_R` values) | Where the thumb-stick and buttons sit, and how big they are. |
| `var hp := 5` / `var max_hp := 5` | Player health. |
| `var power_n := 3` | Starting dash loop, the number in `range(3)`. |
| `var LANDMARKS := [ ... ]` | The five landmarks: their picture, position and size. Add or move places here. |

### What each function does
| Function | Job |
|---|---|
| `_ready()` | Runs once at start: builds the world and the on-screen controls. |
| `_build_world()` | Places the background and landmarks. |
| `_spawn_zones()` | Puts groups of glitches near landmarks. Change counts here. |
| `_process(delta)` | The game loop. Runs every frame: movement, camera, dash, damage, win check. |
| `_animate_player()` | Walk bounce, dash hop, facing left or right. |
| `_update_enemies()` | Glitch chasing and contact damage. |
| `_input(event)` | Reads touch (thumb-stick, buttons) and keyboard for testing. |
| `_strike()` / `_dash()` / `_hit()` | Combat. `_dash()` uses `power_n`, the coding hook. |
| `_build_ui()` / `_update_ui()` | Health, goal counter, loop panel, coach text. |
| `_update_arrow()` | The gold compass that points to the nearest glitch. |
| `_on_plus()` / `_on_minus()` / `_set_power()` | The `range(n)` loop buttons. |
| `_start()` / `_win()` / `_lose()` | Start, win and game-over screens. |

### The working rhythm
1. Change something in `main.gd`.
2. **Ctrl+S** to save.
3. **F5** to play.
4. If it breaks, read the red text in the **Output** panel at the bottom. Undo with **Ctrl+Z**, or roll back in GitHub Desktop.
5. When it works, **Commit and Push** in GitHub Desktop.

---

## 7. What to build next (the roadmap)

1. **Rooms and walls**: structure in the world (Godot: `StaticBody2D` + `CollisionShape2D`, or a `TileMap`).
2. **Real walk animation**: draw 4 to 8 frames, then use an `AnimatedSprite2D`.
3. **Enemy variety and a boss**: new glitch types with different speeds and health.
4. **Power crafting between fights**: a screen where players assemble code (loops, `if`, functions) to unlock abilities. This is where the Python teaching lives.
5. **Juice**: particles (`GPUParticles2D`), sound (`AudioStreamPlayer`), music.
6. **Menus, levels and saving**: Godot's `FileAccess` or `ConfigFile` saves progress on the phone.
7. **Export to Android**: *Project → Export → Add → Android*. Install the export templates, Android SDK and OpenJDK 17 first. Godot's guide is titled "Exporting for Android".
8. **Optional later**: reconnect Firebase (login, leaderboard) and the Python backend (typed-code challenges).

---

## 8. Where to get help without this assistant

- **Official docs**: docs.godotengine.org. Start with "Your first 2D game". It teaches the same ideas this game uses.
- **Godot's built-in help**: in the code editor, Ctrl+click any word (like `Sprite2D`) to open its documentation.
- **Community**: the Godot Forum (forum.godotengine.org), r/godot on Reddit, and the official Godot Discord.
- **Video courses**: search YouTube for "Godot 4 2D tutorial" (GDQuest, Brackeys and HeartBeast are well known).
- **Any AI assistant**: paste the "restart brief" below together with your `main.gd`, then ask for the change you want.
- **A freelancer**: for tricky one-off jobs (Android export, a boss fight), hiring a Godot developer for a few hours is normal and affordable.

### Restart brief (copy this into any AI assistant)

> I am building **CodeQuest**, a mobile 2D action-adventure game in **Godot 4 (GDScript)**, portrait 450×800. The whole game is one script, `main.gd`, attached to `main.tscn`. The player explores an open world (1800×1400) with a follow camera, five landmarks (village, forest, factory, castle, station), and groups of "glitch" enemies that chase when you come close. Controls are touch: a thumb-stick in the lower left, STRIKE and DASH buttons in the lower right. The coding hook: the dash is `for i in range(n): strike()`, and the player changes `n` with + and − buttons to make the dash hit more times. A gold arrow points to the nearest glitch. Clearing all zones wins. I am a beginner, so please give me exact, step-by-step changes and tell me exactly where in `main.gd` to paste them. Here is my current `main.gd`: [paste it]

---

## 9. Accounts checklist

| Account | Use a personal email | Notes |
|---|---|---|
| GitHub | Yes | Holds your code. Turn on two-factor login. |
| Firebase / Google Cloud | Yes | Only when you bring back login or leaderboard. |
| Google Play Console | Yes | $25 once. |
| Apple Developer | Yes | $99 a year, needs a Mac. |
| Domain and server host | Yes | Only if you deploy the Python backend. |

Store passwords in a password manager (Bitwarden is free) and keep your Firebase `serviceAccountKey.json` somewhere private, never in GitHub.
