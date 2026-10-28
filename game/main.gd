extends Node2D
# CodeQuest — Debug Run (Godot 4) — MOBILE + EXPLORABLE WORLD.
#
# A world bigger than the screen. A camera follows you as you explore. Five
# landmarks (village, forest, factory, castle, station) dot the map, each guarded
# by glitches. A gold compass arrow points to the nearest glitch. Clear them all.
#
# Touch controls: left thumb-stick to move, STRIKE / DASH buttons on the right.
# Keyboard (WASD / Space / Shift) still works for quick laptop testing.

# --- screen (the phone viewport) ---
const SW := 450.0
const SH := 800.0
# --- world (much bigger than the screen) ---
const WORLD_W := 1800.0
const WORLD_H := 1400.0

const MOVE_SPEED := 210.0
const DASH_SPEED := 580.0
const ENEMY_SPEED := 58.0
const CHASE_RANGE := 340.0

# on-screen touch controls (screen pixels)
const JOY_HOME := Vector2(96.0, 660.0)
const JOY_R := 64.0
const STRIKE_C := Vector2(372.0, 560.0)
const STRIKE_R := 46.0
const DASH_C := Vector2(360.0, 690.0)
const DASH_R := 56.0

var player: Sprite2D
var cam: Camera2D
var enemies: Array = []          # { "node", "hp", "wob", "bs" }

# UI (screen-fixed)
var ui: CanvasLayer
var hp_label: Label
var goal_label: Label
var power_label: Label
var coach_label: Label
var banner: Label
var arrow: Polygon2D
var joy_base: Sprite2D
var joy_knob: Sprite2D
var strike_btn: Sprite2D
var dash_btn: Sprite2D

# state
var hp := 5
var max_hp := 5
var facing := Vector2(0, 1)
var atk_cd := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_left := 0
var inv := 0.0
var power_n := 3
var playing := false
var coach_timer := 0.0

# feel
var player_base := 0.2
var anim_t := 0.0
var hop := 0.0
var shake := 0.0

# touch
var joy_active := false
var joy_id := -1
var joy_vec := Vector2.ZERO

# landmarks: name, asset, position in the world
var LANDMARKS := [
	{ "asset": "village.png", "pos": Vector2(320, 300) },
	{ "asset": "forest.png",  "pos": Vector2(1450, 280) },
	{ "asset": "factory.png", "pos": Vector2(1520, 1080) },
	{ "asset": "castle.png",  "pos": Vector2(360, 1090) },
	{ "asset": "station.png", "pos": Vector2(900, 700) },
]


func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	_start()


func _build_world() -> void:
	# one big backdrop stretched to cover the whole world
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/bg.png")
	bg.centered = false
	var ts: Vector2 = bg.texture.get_size()
	var s: float = max(WORLD_W / ts.x, WORLD_H / ts.y) * 1.05
	bg.scale = Vector2(s, s)
	bg.position = Vector2((WORLD_W - ts.x * s) * 0.5, (WORLD_H - ts.y * s) * 0.5)
	bg.modulate = Color(0.75, 0.75, 0.9)      # darken so gameplay pops
	add_child(bg)

	# landmarks
	for lm in LANDMARKS:
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/" + lm["asset"])
		spr.scale = Vector2(210.0 / spr.texture.get_size().x, 210.0 / spr.texture.get_size().x)
		spr.position = lm["pos"]
		add_child(spr)

	# player
	player = Sprite2D.new()
	player.texture = load("res://assets/player.png")
	player_base = 58.0 / player.texture.get_size().x
	player.scale = Vector2(player_base, player_base)
	player.position = Vector2(900, 720)         # start at the station hub
	add_child(player)

	# follow camera
	cam = Camera2D.new()
	cam.position = player.position
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WORLD_W)
	cam.limit_bottom = int(WORLD_H)
	add_child(cam)
	cam.make_current()


func _spawn_zones() -> void:
	# 3 glitches guarding each of the 4 outer landmarks (station stays safe)
	for i in range(4):
		var home: Vector2 = LANDMARKS[i]["pos"]
		for j in range(3):
			var off := Vector2(randf_range(-130, 130), randf_range(60, 200))
			var pos := Vector2(
				clamp(home.x + off.x, 60.0, WORLD_W - 60.0),
				clamp(home.y + off.y, 60.0, WORLD_H - 60.0))
			var spr := Sprite2D.new()
			spr.texture = load("res://assets/enemy.png")
			var ef := 46.0 / spr.texture.get_size().x
			spr.scale = Vector2(ef, ef)
			spr.position = pos
			add_child(spr)
			enemies.append({ "node": spr, "hp": 2, "wob": randf() * TAU, "bs": Vector2(ef, ef) })


func _process(delta: float) -> void:
	anim_t += delta
	if coach_timer > 0.0:
		coach_timer -= delta
		if coach_timer <= 0.0:
			coach_label.visible = false

	if hop > 0.0: hop = max(0.0, hop - delta * 5.0)
	if shake > 0.0: shake = max(0.0, shake - delta * 40.0)
	if cam:
		cam.position = player.position
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	if not playing:
		return

	# movement: joystick first, keyboard fallback
	var dir := Vector2.ZERO
	if joy_active:
		dir = joy_vec
	else:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1.0
		if dir != Vector2.ZERO:
			dir = dir.normalized()

	var moving := dir.length() > 0.15
	if moving:
		facing = dir.normalized()

	var spd := MOVE_SPEED
	if dash_t > 0.0:
		dash_t -= delta
		spd = DASH_SPEED
		dir = facing

	player.position += dir * spd * delta
	player.position.x = clamp(player.position.x, 40.0, WORLD_W - 40.0)
	player.position.y = clamp(player.position.y, 40.0, WORLD_H - 40.0)

	if atk_cd > 0.0: atk_cd -= delta
	if dash_cd > 0.0: dash_cd -= delta
	if inv > 0.0: inv -= delta

	_animate_player(moving)
	_update_enemies(delta)
	_update_ui()


func _animate_player(moving: bool) -> void:
	var wob := 0.0
	if moving and dash_t <= 0.0:
		wob = sin(anim_t * 16.0) * 0.06
	var grow := 1.0 + hop * 0.30
	var sx := player_base * grow * (1.0 - wob)
	var sy := player_base * grow * (1.0 + wob)
	if facing.x < -0.2:
		sx = -sx
	player.scale = Vector2(sx, sy)
	var a := 1.0
	if inv > 0.0 and int(inv * 12.0) % 2 == 0:
		a = 0.4
	player.modulate = Color(1, 1, 1, a)


func _update_enemies(delta: float) -> void:
	for e in enemies:
		var spr: Sprite2D = e["node"]
		e["wob"] += delta * 6.0
		var to: Vector2 = player.position - spr.position
		var dist: float = to.length()
		# only chase when the player wanders near — keeps the world calm to explore
		if dist < CHASE_RANGE and dist > 0.0:
			spr.position += (to / dist) * ENEMY_SPEED * delta
		if dist < 32.0 and inv <= 0.0 and dash_t <= 0.0:
			hp -= 1
			inv = 1.0
			shake = 11.0
			if dist > 0.0:
				player.position -= (to / dist) * 26.0
			if hp <= 0:
				_lose()
				return


# ---------- INPUT ----------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		if kc == KEY_ENTER or kc == KEY_KP_ENTER:
			if not playing: _start()
			return
		if playing:
			if kc == KEY_SPACE or kc == KEY_J: _strike()
			elif kc == KEY_SHIFT or kc == KEY_K: _dash()
		return

	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if not playing:
				_start()
				return
			if p.distance_to(STRIKE_C) <= STRIKE_R + 8.0:
				_strike(); return
			if p.distance_to(DASH_C) <= DASH_R + 8.0:
				_dash(); return
			if not joy_active and p.x < 210.0 and p.y > 430.0:
				joy_active = true
				joy_id = event.index
				_joy_to(p)
		else:
			if event.index == joy_id:
				joy_active = false
				joy_id = -1
				joy_vec = Vector2.ZERO
				joy_knob.position = JOY_HOME
	elif event is InputEventScreenDrag:
		if joy_active and event.index == joy_id:
			_joy_to(event.position)


func _joy_to(p: Vector2) -> void:
	var off: Vector2 = p - JOY_HOME
	if off.length() > JOY_R:
		off = off.normalized() * JOY_R
	joy_knob.position = JOY_HOME + off
	joy_vec = off / JOY_R


# ---------- ACTIONS ----------
func _strike() -> void:
	if atk_cd > 0.0:
		return
	atk_cd = 0.35
	_press(strike_btn)
	_hit(70.0)


func _dash() -> void:
	if dash_cd > 0.0 or dash_left > 0:
		return
	dash_left = power_n
	dash_cd = 0.15 + power_n * 0.16
	hop = 1.0
	_press(dash_btn)
	while dash_left > 0 and playing:
		dash_left -= 1
		dash_t = 0.13
		_hit(64.0)
		await get_tree().create_timer(0.15).timeout


func _press(btn: Sprite2D) -> void:
	var tw := create_tween()
	btn.scale = Vector2(0.82, 0.82)
	tw.tween_property(btn, "scale", Vector2(1, 1), 0.14)


func _hit(rng: float) -> void:
	var to_remove: Array = []
	for e in enemies:
		var spr: Sprite2D = e["node"]
		if spr.position.distance_to(player.position) < rng:
			e["hp"] -= 1
			shake = max(shake, 6.0)
			if e["hp"] <= 0:
				to_remove.append(e)
			else:
				var bs: Vector2 = e["bs"]
				var t1 := create_tween()
				t1.tween_property(spr, "scale", bs * 1.3, 0.06)
				t1.tween_property(spr, "scale", bs, 0.12)
				var t2 := create_tween()
				spr.modulate = Color(2, 0.6, 0.6)
				t2.tween_property(spr, "modulate", Color(1, 1, 1, 1), 0.2)
	for e in to_remove:
		e["node"].queue_free()
		enemies.erase(e)
	if enemies.is_empty() and playing:
		_win()


# ---------- UI ----------
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	hp_label = _mk_label(Vector2(14, 10), 18)
	ui.add_child(hp_label)

	goal_label = _mk_label(Vector2(W_R(150), 12), 15)
	ui.add_child(goal_label)

	power_label = _mk_label(Vector2(14, 42), 13)
	power_label.text = "dash = for i in range(%d): strike()" % power_n
	ui.add_child(power_label)

	var minus := Button.new()
	minus.text = "-"
	minus.position = Vector2(316, 38)
	minus.size = Vector2(44, 40)
	minus.pressed.connect(_on_minus)
	ui.add_child(minus)

	var plus := Button.new()
	plus.text = "+"
	plus.position = Vector2(366, 38)
	plus.size = Vector2(44, 40)
	plus.pressed.connect(_on_plus)
	ui.add_child(plus)

	# compass arrow to the nearest glitch
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, -12), Vector2(9, 9), Vector2(-9, 9)])
	arrow.color = Color(1, 0.79, 0.24, 0.95)
	arrow.position = Vector2(SW * 0.5, 92)
	ui.add_child(arrow)

	coach_label = _mk_label(Vector2(24, 150), 16)
	coach_label.size = Vector2(SW - 48, 100)
	coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_label.visible = false
	ui.add_child(coach_label)

	banner = _mk_label(Vector2(24, SH * 0.40), 22)
	banner.size = Vector2(SW - 48, 150)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.visible = false
	ui.add_child(banner)

	# touch controls
	joy_base = Sprite2D.new()
	joy_base.texture = _circle_tex(int(JOY_R * 2.0), Color(1, 1, 1, 0.13))
	joy_base.position = JOY_HOME
	ui.add_child(joy_base)

	joy_knob = Sprite2D.new()
	joy_knob.texture = _circle_tex(74, Color(0.55, 0.36, 1.0, 0.75))
	joy_knob.position = JOY_HOME
	ui.add_child(joy_knob)

	strike_btn = Sprite2D.new()
	strike_btn.texture = _circle_tex(int(STRIKE_R * 2.0), Color(0.22, 0.85, 0.9, 0.55))
	strike_btn.position = STRIKE_C
	ui.add_child(strike_btn)
	_btn_label(STRIKE_C, "STRIKE", STRIKE_R)

	dash_btn = Sprite2D.new()
	dash_btn.texture = _circle_tex(int(DASH_R * 2.0), Color(1, 0.79, 0.24, 0.65))
	dash_btn.position = DASH_C
	ui.add_child(dash_btn)
	_btn_label(DASH_C, "DASH", DASH_R)


func W_R(margin_from_right: float) -> float:
	return SW - margin_from_right


func _btn_label(center: Vector2, txt: String, r: float) -> void:
	var l := _mk_label(center - Vector2(r, 9), 14)
	l.text = txt
	l.size = Vector2(r * 2.0, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(l)


func _circle_tex(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c + 0.5, float(y) - c + 0.5).length()
			var a := 0.0
			if d <= c:
				a = clamp((c - d) / 2.0 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)


func _mk_label(pos: Vector2, sz: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.96, 0.95, 1.0))
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


func _update_ui() -> void:
	var hearts := ""
	for i in max_hp:
		hearts += "@" if i < hp else "."
	hp_label.text = "HP  " + hearts
	goal_label.text = "Glitches: %d" % enemies.size()
	_update_arrow()


func _update_arrow() -> void:
	if enemies.is_empty():
		arrow.visible = false
		return
	arrow.visible = true
	var best := 1.0e20
	var target := player.position
	for e in enemies:
		var d: float = e["node"].position.distance_to(player.position)
		if d < best:
			best = d
			target = e["node"].position
	var dirv: Vector2 = target - player.position
	if dirv.length() > 0.0:
		arrow.rotation = dirv.angle() + PI * 0.5


func _on_plus() -> void:
	_set_power(power_n + 1)


func _on_minus() -> void:
	_set_power(power_n - 1)


func _set_power(n: int) -> void:
	power_n = clampi(n, 1, 5)
	power_label.text = "dash = for i in range(%d): strike()" % power_n


func _show_coach(txt: String) -> void:
	coach_label.text = txt
	coach_label.visible = true
	coach_timer = 7.0


func _start() -> void:
	for e in enemies:
		e["node"].queue_free()
	enemies.clear()
	hp = max_hp
	inv = 0.0
	dash_t = 0.0
	dash_left = 0
	dash_cd = 0.0
	atk_cd = 0.0
	hop = 0.0
	shake = 0.0
	joy_active = false
	joy_id = -1
	joy_vec = Vector2.ZERO
	if joy_knob:
		joy_knob.position = JOY_HOME
	player.position = Vector2(900, 720)
	player.modulate = Color(1, 1, 1, 1)
	if cam:
		cam.position = player.position
	banner.visible = false
	_spawn_zones()
	_show_coach("Explore the world!\nFollow the gold arrow to find glitches.\nDrag to move, tap STRIKE / DASH to fight.")
	playing = true


func _win() -> void:
	playing = false
	banner.text = "WORLD RESTORED!\nEvery zone debugged.\nTap anywhere to play again"
	banner.visible = true


func _lose() -> void:
	playing = false
	banner.text = "DOWN!\nTap DASH to blitz through them.\nTap anywhere to retry"
	banner.visible = true
