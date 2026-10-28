# CodeQuest — Debug Run (Godot 4 starter)

This is the action prototype rebuilt as a **real Godot project** you can open, run, and grow.
Real-time movement, a dash whose power is defined by a `for` loop, chasing glitch enemies,
on-screen instructions, and win/lose. Everything is built in one readable script (`main.gd`) so
it runs the moment you press Play — no scene wiring needed to start.

> Built without a Godot install here, so it wasn't test-run. If anything errors on first open,
> copy me the message and I'll fix it fast.

---

## What tool do I use?

**Godot has its own built-in editor — that's your main tool.** You do NOT need VS Code *or*
Android Studio to build this game. You write the code (GDScript) right inside Godot.

- **VS Code** — optional. Some people prefer it with a Godot extension, but it's not required.
- **Android Studio** — not used to build the game. You only need it *later*, if you export the
  game to Android (it provides the Android SDK). Ignore it for now.

---

## Run it — exact steps

1. **Download Godot 4.** Go to **godotengine.org/download**, get **Godot Engine 4.x (Standard)**
   for your OS. It's a single app — no installer. (Get "Standard", not ".NET/C#".)
2. **Open Godot.** Unzip and run it. The Project Manager window appears.
3. **Import this project.** Click **Import**, then **Browse**, open this `codequest-godot`
   folder, select **`project.godot`**, and click **Import & Edit**.
4. **Let it import the art.** The first time, Godot converts the PNGs in `assets/` — give it a
   few seconds.
5. **Press Play.** Click the ▶ button (top-right) or press **F5**. The game window opens.

### Controls (this is a MOBILE game — touch first)
- **Left thumb-stick** (drag the circle, lower-left) — move
- **STRIKE button** (lower-right) — hit nearby glitches
- **DASH button** (lower-right) — dash-blitz; runs your loop, and you're safe mid-dash
- **+ / − buttons** (top) — change your dash loop (1–5): more loop = longer blitz
- **Tap anywhere** — restart after win/lose

**Testing on your laptop:** the project has "emulate touch from mouse" on, so in Godot you can
**use your mouse like a finger** — click-drag the lower-left circle to move, and click the
STRIKE / DASH buttons. (Keyboard WASD / Space / Shift also still work for quick testing.)

**Goal:** the world is now bigger than the screen — the **camera follows you** as you explore.
Five landmarks (village, forest, factory, castle, station) dot the map, each guarded by glitches.
Follow the **gold compass arrow** (top of screen) to the nearest glitch, clear every zone to win.
Enemies only wake up when you get close, so you can explore calmly.

---

## Where things live

| File | What it is |
| ---- | ---------- |
| `project.godot` | Project settings + window size (open this in Godot) |
| `main.tscn` | The one scene Godot runs (just holds the script) |
| `main.gd` | **All the game logic** — start here to change things |
| `assets/` | `player.png`, `enemy.png`, `bg.png` |

## Easy things to try changing (in `main.gd`)

- **More enemies:** in `_start()`, change `_spawn(6, 2)` to `_spawn(10, 2)`.
- **Tougher enemies:** the `2` in `_spawn(6, 2)` is their HP.
- **Faster hero:** change `MOVE_SPEED` near the top.
- **Stronger dash:** raise the max loop in `_set_power` (`clampi(n, 1, 5)`).
- **Your health:** change `max_hp`.

## Where to grow next (I can help with each)
1. Real sprite **animation** (walk / hit frames) instead of a static image.
2. A scrolling **world to explore** with a follow camera, not one arena.
3. **Between-fights power crafting** — assemble bigger code spells for new abilities.
4. **Juice** — particles, screen shake, hit sparks, music.
5. **Export** to Windows/Mac, then later Android (that's when Android Studio's SDK comes in).

GDScript looks a lot like Python, so your CodeQuest instincts transfer. Open `main.gd` and read
it top to bottom — it's commented and meant to be learned from.
