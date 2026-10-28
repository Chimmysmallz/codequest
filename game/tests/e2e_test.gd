# CodeQuest game end-to-end test (runs with no window, in seconds).
#
# Run it from the project root:
#   godot --headless --path game --script res://tests/e2e_test.gd
#
# It loads the real game scene and plays it automatically:
#   1. the world starts correctly (12 glitches, full health, playing)
#   2. the coding hook works: range(n) is clamped between 1 and 5
#   3. the player can clear every glitch and see the WIN banner
#   4. restarting respawns the world
#   5. touching a glitch with 1 HP left shows the GAME OVER banner
# Prints "E2E PASS" and exits with code 0, or lists failures and exits 1.
extends SceneTree

var failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS  ", what)
	else:
		print("FAIL  ", what)
		failures.append(what)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	_check(scene != null, "main scene loads")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(5)

	# 1. Start state
	_check(game.enemies.size() == 12, "world spawns 12 glitches (3 at each of 4 landmarks)")
	_check(game.hp == game.max_hp, "player starts at full health")
	_check(game.playing, "game is running after start")
	_check(game.LANDMARKS.size() == 5, "5 landmarks placed")

	# 2. Coding hook: dash = for i in range(n)
	game._set_power(5)
	_check(game.power_n == 5, "loop power can be set to 5")
	game._set_power(9)
	_check(game.power_n == 5, "loop power is capped at 5")
	game._set_power(0)
	_check(game.power_n == 1, "loop power never drops below 1")
	game._set_power(3)

	# 3. Clear every glitch -> win
	var safety := 0
	while game.enemies.size() > 0 and safety < 200:
		safety += 1
		var target: Sprite2D = game.enemies[0]["node"]
		game.player.position = target.position
		game.inv = 10.0                 # keep the tester invincible while clearing
		game._hit(70.0)
		await _frames(1)
	_check(game.enemies.is_empty(), "all glitches can be cleared")
	_check(not game.playing, "game stops after the world is restored")
	_check(game.banner.visible and "WORLD RESTORED" in game.banner.text, "win banner is shown")

	# 4. Restart
	game._start()
	await _frames(2)
	_check(game.enemies.size() == 12 and game.playing and game.hp == game.max_hp, "restart respawns the world")

	# 5. Lose: stand on a glitch with 1 HP and no invincibility
	game.hp = 1
	game.inv = 0.0
	var lost := false
	for i in range(240):
		if game.enemies.is_empty():
			break
		game.player.position = game.enemies[0]["node"].position
		await process_frame
		if not game.playing:
			lost = true
			break
	_check(lost, "touching a glitch at 1 HP ends the run")
	_check(game.banner.visible and "DOWN" in game.banner.text, "game-over banner is shown")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("\nE2E PASS")
		quit(0)
	else:
		print("\nE2E FAIL: ", failures.size(), " check(s) failed")
		quit(1)
