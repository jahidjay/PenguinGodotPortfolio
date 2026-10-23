# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do destructible boss parts (own hitboxes + patterns) make boss fights more
#           interesting while keeping the strict chain + Critical Break payoff?
# Date: 2026-10-23
#
# CONTROLS (keyboard / gamepad slot 0)
#   Move:   Arrows or WASD / left stick or d-pad
#   Shot:   Z or Space (hold)                  / A
#   Laser:  X (hold; needs meter >= LASER_MIN) / X button   -> invulnerable + 3x damage
#   Bomb:   C                                  / B button
#   Boss:   1 / 2 / 3 pick boss, N next boss, R restart
# Goal: keep the chain alive. Break parts to weaken/expose the core. When the core is
#       CRITICAL, press Bomb while Laser is active for the Critical Break.
extends Node2D

# ---------------- TUNING (all hardcoded on purpose) ----------------
const W := 480.0
const H := 640.0
const CHAIN_WINDOW := 1.0        # seconds; strict, pure reset when it runs out
const SPEED_NORMAL := 280.0
const SPEED_FIRE := 200.0
const SPEED_LASER := 120.0
const HIT_R := 3.0               # player hitbox radius
const FIRE_INTERVAL := 0.06
const SHOT_SPEED := 900.0
const SHOT_DMG := 1.0
const LASER_MIN := 40.0
const METER_MAX := 100.0
const METER_PER_HIT := 0.6
const METER_BURN := 25.0
const LASER_DMG := 3.0
const LASER_TICK := 1.0 / 20.0
const BOMB_DMG := 80.0
const CRIT_HP := 200.0           # core is CRITICAL at or below this
const BREAK_MULT := 3
const BREAK_ADD := 50
const ARMOR_MULT := 0.25         # core damage taken while parts are alive
const PART_KILL_SCORE := 2000
const PART_KILL_CHAIN := 5
const CANCEL_RADIUS := 90.0      # bullets cancelled around a destroyed part
const BOSS_NAMES := ["1941  FLYING FORTRESS", "1970s  JET CARRIER", "2100  PLASMA RING"]

static var boss_id := 0          # survives scene reload

# ---------------- STATE ----------------
var font: Font
var state := "play"
var t := 0.0

var p_pos := Vector2(W * 0.5, H - 70.0)
var lives := 3
var bombs := 3
var invuln := 0.0
var fire_cd := 0.0
var laser_on := false
var laser_acc := 0.0
var laser_top := 0.0
var meter := 0.0
var prev_bomb := false

var shots: Array = []            # [Vector2 pos]
var bullets: Array = []          # [pos, vel, kind, age, extra]  kind: 0 normal, 1 accel, 2 warp, 3 curve

var boss_pos := Vector2(W * 0.5, 120.0)
var boss_t := 0.0
var spiral_a := 0.0
var parts: Array = []            # Array of Dictionary (core included)
var core: Dictionary = {}
var others_total := 0

var chain := 0
var chain_t := 0.0
var max_chain := 0
var last_lost_chain := 0
var score := 0
var flash := 0.0
var result_text := ""
var popups: Array = []           # [pos, text, age]


func _ready() -> void:
	font = ThemeDB.fallback_font
	_build_boss()


# ---------------- BOSS DEFINITIONS ----------------
func _make_part(pname: String, shape: String, size: Vector2, off: Vector2, hp: float, pattern: String,
		is_core := false, orbit_r := 0.0, orbit_spd := 0.0, orbit_a := 0.0) -> Dictionary:
	return {
		"name": pname, "shape": shape, "size": size, "off": off, "hp": hp, "max": hp,
		"pattern": pattern, "core": is_core, "orbit_r": orbit_r, "orbit_spd": orbit_spd,
		"orbit_a": orbit_a, "cd": 0.6 + randf() * 0.6, "n": 0, "alive": true, "sign": 1.0,
	}


func _build_boss() -> void:
	parts.clear()
	match boss_id:
		0: # Flying Fortress: wide bomber, turrets + engines, rect core
			core = _make_part("core", "rect", Vector2(70, 36), Vector2(0, -6), 1200, "core_fortress", true)
			parts.append(_make_part("L turret", "circle", Vector2(14, 14), Vector2(-95, 12), 120, "fan"))
			parts.append(_make_part("R turret", "circle", Vector2(14, 14), Vector2(95, 12), 120, "fan"))
			parts.append(_make_part("L engine", "rect", Vector2(22, 30), Vector2(-52, 22), 160, "ring"))
			parts.append(_make_part("R engine", "rect", Vector2(22, 30), Vector2(52, 22), 160, "ring"))
		1: # Jet Carrier: orbiting missile pods + wings, circle core
			core = _make_part("core", "circle", Vector2(34, 34), Vector2.ZERO, 1400, "core_jet", true)
			for i in 3:
				parts.append(_make_part("pod", "circle", Vector2(12, 12), Vector2.ZERO, 100, "stream",
					false, 72.0, 1.2, TAU * i / 3.0))
			parts.append(_make_part("L wing", "rect", Vector2(44, 12), Vector2(-70, -14), 150, "wall"))
			parts.append(_make_part("R wing", "rect", Vector2(44, 12), Vector2(70, -14), 150, "wall"))
		_: # Plasma Ring: core immune until 4 orbiting shields die
			core = _make_part("core", "circle", Vector2(30, 30), Vector2.ZERO, 1600, "core_plasma", true)
			for i in 4:
				parts.append(_make_part("shield", "circle", Vector2(16, 16), Vector2.ZERO, 140, "curve",
					false, 62.0, 0.8, TAU * i / 4.0))
	others_total = parts.size()
	parts.push_front(core)       # core first so it's drawn underneath


func _part_pos(p: Dictionary) -> Vector2:
	var r: float = p.orbit_r
	if r > 0.0:
		var a: float = p.orbit_a
		var spd: float = p.orbit_spd
		return boss_pos + Vector2.from_angle(a + boss_t * spd) * r
	var off: Vector2 = p.off
	return boss_pos + off


func _others_alive() -> int:
	var n := 0
	for p in parts:
		if p.alive and not p.core:
			n += 1
	return n


func core_immune() -> bool:
	return boss_id == 2 and _others_alive() > 0


func core_armored() -> bool:
	return _others_alive() > 0 and not core_immune()


func rage() -> float:
	if others_total == 0:
		return 1.0
	return 1.0 - float(_others_alive()) / others_total


func critical() -> bool:
	var hp: float = core.hp
	return hp <= CRIT_HP


func _point_hits(p: Dictionary, wp: Vector2, pt: Vector2, margin: float) -> bool:
	var size: Vector2 = p.size
	if p.shape == "circle":
		return pt.distance_to(wp) < size.x + margin
	return Rect2(wp - size * 0.5, size).grow(margin).has_point(pt)


# ---------------- INPUT ----------------
func key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func joy_btn(b: JoyButton) -> bool:
	return Input.is_joy_button_pressed(0, b)


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_1:
				boss_id = 0
				get_tree().reload_current_scene()
			KEY_2:
				boss_id = 1
				get_tree().reload_current_scene()
			KEY_3:
				boss_id = 2
				get_tree().reload_current_scene()
			KEY_N:
				boss_id = (boss_id + 1) % 3
				get_tree().reload_current_scene()


func move_vec() -> Vector2:
	var v := Vector2.ZERO
	if key(KEY_LEFT) or key(KEY_A) or joy_btn(JOY_BUTTON_DPAD_LEFT):
		v.x -= 1
	if key(KEY_RIGHT) or key(KEY_D) or joy_btn(JOY_BUTTON_DPAD_RIGHT):
		v.x += 1
	if key(KEY_UP) or key(KEY_W) or joy_btn(JOY_BUTTON_DPAD_UP):
		v.y -= 1
	if key(KEY_DOWN) or key(KEY_S) or joy_btn(JOY_BUTTON_DPAD_DOWN):
		v.y += 1
	var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(jx) > 0.2:
		v.x += jx
	if absf(jy) > 0.2:
		v.y += jy
	return v.limit_length(1.0)


# ---------------- MAIN LOOP ----------------
func _physics_process(d: float) -> void:
	if state != "play":
		queue_redraw()
		return
	t += d
	flash = maxf(0.0, flash - d)
	invuln = maxf(0.0, invuln - d)
	for i in range(popups.size() - 1, -1, -1):
		popups[i][2] += d
		if popups[i][2] > 1.0:
			popups.remove_at(i)

	_update_boss(d)
	_update_player(d)
	_update_bullets(d)
	_update_chain(d)
	queue_redraw()


func _update_player(d: float) -> void:
	var fire := key(KEY_Z) or key(KEY_SPACE) or joy_btn(JOY_BUTTON_A)
	var laser_key := key(KEY_X) or joy_btn(JOY_BUTTON_X)
	var bomb_key := key(KEY_C) or joy_btn(JOY_BUTTON_B)

	if laser_key:
		if not laser_on and meter >= LASER_MIN:
			laser_on = true
	else:
		laser_on = false
	if laser_on:
		meter -= METER_BURN * d
		if meter <= 0.0:
			meter = 0.0
			laser_on = false

	var spd := SPEED_NORMAL
	if laser_on:
		spd = SPEED_LASER
	elif fire:
		spd = SPEED_FIRE
	p_pos += move_vec() * spd * d
	p_pos.x = clampf(p_pos.x, 10.0, W - 10.0)
	p_pos.y = clampf(p_pos.y, 40.0, H - 10.0)

	fire_cd -= d
	if fire and not laser_on and fire_cd <= 0.0:
		fire_cd = FIRE_INTERVAL
		shots.append([p_pos + Vector2(-8, -10)])
		shots.append([p_pos + Vector2(8, -10)])

	# shots vs parts (first part hit absorbs the shot)
	for i in range(shots.size() - 1, -1, -1):
		var s: Array = shots[i]
		s[0] += Vector2(0, -SHOT_SPEED * d)
		var sp: Vector2 = s[0]
		if sp.y < -10.0:
			shots.remove_at(i)
			continue
		for p in parts:
			if p.alive and _point_hits(p, _part_pos(p), sp, 2.0):
				shots.remove_at(i)
				_hit_part(p, SHOT_DMG, true)
				break

	# laser: stops at the closest part above the player in its column
	laser_top = 0.0
	if laser_on:
		var target: Dictionary = {}
		var best_y := -INF
		for p in parts:
			if not p.alive:
				continue
			var wp := _part_pos(p)
			var size: Vector2 = p.size
			var half_w := size.x if p.shape == "circle" else size.x * 0.5
			var half_h := size.y if p.shape == "circle" else size.y * 0.5
			if absf(wp.x - p_pos.x) < half_w + 7.0 and wp.y < p_pos.y and wp.y + half_h > best_y:
				best_y = wp.y + half_h
				target = p
		if not target.is_empty():
			laser_top = best_y
		laser_acc += d
		while laser_acc >= LASER_TICK:
			laser_acc -= LASER_TICK
			if not target.is_empty() and target.alive:
				_hit_part(target, LASER_DMG, false)
	else:
		laser_acc = 0.0

	var bomb_pressed := bomb_key and not prev_bomb
	prev_bomb = bomb_key
	if bomb_pressed and bombs > 0 and state == "play":
		bombs -= 1
		bullets.clear()
		invuln = maxf(invuln, 2.0)
		flash = 0.4
		if laser_on and critical():
			_critical_break()
		else:
			for p in parts.duplicate():
				if p.alive:
					_hit_part(p, BOMB_DMG if p.core else BOMB_DMG * 0.6, true)


func _hit_part(p: Dictionary, dmg: float, gain_meter: bool) -> void:
	if state != "play":
		return
	var hp: float = p.hp
	if p.core:
		if core_immune():
			return               # shielded: no damage, no chain
		if core_armored():
			dmg *= ARMOR_MULT
		p.hp = maxf(hp - dmg, 1.0)   # core only dies to Critical Break
	else:
		p.hp = hp - dmg
		if p.hp <= 0.0:
			_destroy_part(p)
	chain += 1
	chain_t = CHAIN_WINDOW
	max_chain = maxi(max_chain, chain)
	score += 10 + chain
	if gain_meter and not laser_on:
		meter = minf(meter + METER_PER_HIT, METER_MAX)


func _destroy_part(p: Dictionary) -> void:
	p.alive = false
	var wp := _part_pos(p)
	score += PART_KILL_SCORE
	chain += PART_KILL_CHAIN
	chain_t = CHAIN_WINDOW
	flash = maxf(flash, 0.12)
	for i in range(bullets.size() - 1, -1, -1):
		var bp: Vector2 = bullets[i][0]
		if bp.distance_to(wp) < CANCEL_RADIUS:
			bullets.remove_at(i)
	var msg := "%s DOWN" % String(p.name).to_upper()
	if _others_alive() == 0:
		msg = "CORE EXPOSED!"
	popups.append([wp, msg, 0.0])


func _critical_break() -> void:
	chain = chain * BREAK_MULT + BREAK_ADD
	max_chain = maxi(max_chain, chain)
	var life_bonus := lives * 5000
	score += chain * 100 + life_bonus
	core.hp = 0.0
	core.alive = false
	flash = 1.2
	state = "win"
	result_text = "CRITICAL BREAK!  Chain x%d  (+%d life bonus)" % [chain, life_bonus]
	bullets.clear()


func _update_chain(d: float) -> void:
	if chain > 0:
		chain_t -= d
		if chain_t <= 0.0:
			last_lost_chain = chain
			chain = 0


# ---------------- BOSS + PATTERNS ----------------
func _update_boss(d: float) -> void:
	boss_t += d
	match boss_id:
		0:
			boss_pos = Vector2(W * 0.5 + sin(boss_t * 0.5) * 90.0, 130.0)
		1:
			boss_pos = Vector2(W * 0.5 + sin(boss_t * 0.9) * 130.0, 120.0 + sin(boss_t * 1.7) * 15.0)
		_:
			boss_pos = Vector2(W * 0.5 + sin(boss_t * 0.6) * 120.0, 150.0 + sin(boss_t * 1.2) * 40.0)

	for p in parts:
		if not p.alive:
			continue
		p.cd -= d
		if p.cd <= 0.0:
			_fire_pattern(p, _part_pos(p))


func _fire_pattern(p: Dictionary, wp: Vector2) -> void:
	var rg := rage()
	var n: int = p.n
	match p.pattern:
		"fan":
			p.cd = 1.1
			_fan(wp, 3, 0.28, 170.0, 0)
		"ring":
			p.cd = 1.9
			_ring(wp, 12, 100.0, randf() * TAU, 0)
		"core_fortress":
			p.cd = lerpf(0.11, 0.045, rg)
			spiral_a += 0.33
			_shoot(wp, spiral_a, 140.0, 0)
			if rg >= 0.5:
				_shoot(wp, spiral_a + PI, 140.0, 0)
			if rg >= 1.0 and n % 25 == 0:
				_ring(wp, 24, 110.0, randf() * TAU, 0)
			p.n = n + 1
		"stream":
			if n < 6:
				p.cd = 0.1
				_fan(wp, 1, 0.0, 240.0, 0)
				p.n = n + 1
			else:
				p.cd = 1.4
				p.n = 0
		"wall":
			p.cd = 2.3
			var gap := randi() % 9
			for i in 9:
				if i == gap:
					continue
				_shoot_vel(Vector2(wp.x - 64.0 + i * 16.0, wp.y), Vector2(0, 110), 0)
		"core_jet":
			p.cd = lerpf(1.3, 0.55, rg)
			_fan(wp, 5 + int(rg * 4.0), 0.22, 50.0, 1)
		"curve":
			p.cd = 0.16
			var s: float = p.sign
			p.sign = -s
			var out := (wp - boss_pos).angle()
			bullets.append([wp, Vector2.from_angle(out) * 120.0, 3, 0.0, 1.3 * s])
		"core_plasma":
			if core_immune():
				p.cd = 1.8
				_ring(wp, 12, 90.0, randf() * TAU, 2)
			else:
				p.cd = 0.6
				if n % 2 == 0:
					_ring(wp, 20, 130.0, randf() * TAU, 2)
				else:
					_fan(wp, 5, 0.25, 180.0, 0)
				p.n = n + 1


func _shoot(from: Vector2, angle: float, speed: float, kind: int) -> void:
	bullets.append([from, Vector2.from_angle(angle) * speed, kind, 0.0, 0.0])


func _shoot_vel(from: Vector2, vel: Vector2, kind: int) -> void:
	bullets.append([from, vel, kind, 0.0, 0.0])


func _ring(from: Vector2, n: int, speed: float, offset: float, kind: int) -> void:
	for i in n:
		_shoot(from, offset + TAU * i / n, speed, kind)


func _fan(from: Vector2, n: int, spread: float, speed: float, kind: int) -> void:
	var base := (p_pos - from).angle()
	for i in n:
		_shoot(from, base + (i - (n - 1) * 0.5) * spread, speed, kind)


func _update_bullets(d: float) -> void:
	var can_be_hit := invuln <= 0.0 and not laser_on
	var hit := false
	for i in range(bullets.size() - 1, -1, -1):
		var b: Array = bullets[i]
		var kind: int = b[2]
		b[3] += d
		var age: float = b[3]
		var vel: Vector2 = b[1]
		match kind:
			1: # accelerate
				vel *= 1.0 + 1.6 * d
				if vel.length() > 330.0:
					vel = vel.normalized() * 330.0
			2: # time-warp: fly, freeze, re-aim at player
				var stage: float = b[4]
				if stage == 0.0 and age > 0.7:
					vel = Vector2.ZERO
					b[4] = 1.0
				elif stage == 1.0 and age > 1.1:
					var bp: Vector2 = b[0]
					vel = (p_pos - bp).normalized() * 190.0
					b[4] = 2.0
			3: # curve
				var spin: float = b[4]
				vel = vel.rotated(spin * d)
		b[1] = vel
		var pos: Vector2 = b[0]
		pos += vel * d
		b[0] = pos
		if pos.x < -20.0 or pos.x > W + 20.0 or pos.y < -20.0 or pos.y > H + 20.0 or age > 10.0:
			bullets.remove_at(i)
		elif can_be_hit and pos.distance_to(p_pos) < HIT_R + 3.0:
			hit = true
	if hit:
		_player_hit()


func _player_hit() -> void:
	lives -= 1
	last_lost_chain = chain
	chain = 0
	bullets.clear()
	invuln = 2.5
	flash = 0.3
	if lives <= 0:
		state = "lose"
		result_text = "GAME OVER"


# ---------------- DRAW ----------------
func txt(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_shape(p: Dictionary, wp: Vector2, col: Color) -> void:
	var size: Vector2 = p.size
	if p.shape == "circle":
		draw_circle(wp, size.x, col)
	else:
		draw_rect(Rect2(wp - size * 0.5, size), col)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.10))

	# non-hittable hull silhouette (visual only)
	var hull := Color(0.18, 0.18, 0.22)
	match boss_id:
		0:
			draw_rect(Rect2(boss_pos + Vector2(-120, 0), Vector2(240, 18)), hull)
		1:
			draw_colored_polygon(PackedVector2Array([boss_pos + Vector2(0, 40),
				boss_pos + Vector2(-95, -20), boss_pos + Vector2(95, -20)]), hull)
		_:
			draw_arc(boss_pos, 62.0, 0.0, TAU, 48, hull, 3.0)

	# parts
	for p in parts:
		var wp := _part_pos(p)
		if not p.alive:
			if not p.core:
				_draw_shape(p, wp, Color(0.22, 0.14, 0.12))
			continue
		var col := Color(0.85, 0.55, 0.25)
		if p.core:
			col = Color(0.85, 0.3, 0.3)
			if core_immune():
				col = Color(0.45, 0.45, 0.55)
			elif core_armored():
				col = Color(0.5, 0.2, 0.22)
			if critical() and int(t * 8.0) % 2 == 0:
				col = Color(1.0, 0.9, 0.3)
		_draw_shape(p, wp, col)
		if p.core and core_immune():
			draw_arc(wp, 40.0, 0.0, TAU, 32, Color(0.5, 0.8, 1.0, 0.6), 2.0)
		if not p.core:
			var hp: float = p.hp
			var mx: float = p.max
			draw_rect(Rect2(wp + Vector2(-14, -24), Vector2(28, 3)), Color(0.2, 0.2, 0.25))
			draw_rect(Rect2(wp + Vector2(-14, -24), Vector2(28.0 * hp / mx, 3)), Color(1.0, 0.7, 0.3))

	# laser
	if laser_on:
		var beam_len := p_pos.y - laser_top
		draw_rect(Rect2(p_pos.x - 7, laser_top, 14, beam_len), Color(1.0, 0.5, 0.1, 0.55))
		draw_rect(Rect2(p_pos.x - 3, laser_top, 6, beam_len), Color(1.0, 0.95, 0.7))

	for s in shots:
		draw_rect(Rect2(s[0] + Vector2(-2, -6), Vector2(4, 12)), Color(1.0, 0.8, 0.2))

	# enemy bullets: cool colors + dark outline, tint by kind
	var kind_col := [Color(0.4, 0.85, 1.0), Color(0.6, 0.6, 1.0), Color(1.0, 0.6, 1.0), Color(0.3, 1.0, 0.85)]
	for b in bullets:
		draw_circle(b[0], 5.0, Color(0.0, 0.0, 0.1))
		draw_circle(b[0], 3.5, kind_col[b[2]])

	if state != "lose":
		var blink := invuln > 0.0 and int(t * 20.0) % 2 == 0
		if not blink:
			var pc := Color(1.0, 0.7, 0.2) if not laser_on else Color(1.0, 1.0, 0.8)
			draw_colored_polygon(PackedVector2Array([
				p_pos + Vector2(0, -12), p_pos + Vector2(10, 10), p_pos + Vector2(-10, 10)]), pc)
		draw_circle(p_pos, HIT_R, Color(1, 1, 1))
		draw_circle(p_pos, HIT_R - 1.0, Color(1, 0.1, 0.1))

	for pu in popups:
		var a: float = 1.0 - float(pu[2])
		txt(pu[0] + Vector2(-40, -30 - pu[2] * 30.0), pu[1], 12, Color(1, 1, 0.6, a))

	# core HP bar + status
	var chp: float = core.hp
	var cmax: float = core.max
	draw_rect(Rect2(20, 12, W - 40, 8), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(20, 12, (W - 40) * chp / cmax, 8), Color(0.9, 0.3, 0.3))
	var cx := 20.0 + (W - 40) * CRIT_HP / cmax
	draw_line(Vector2(cx, 9), Vector2(cx, 23), Color(1, 1, 0.3), 2.0)
	txt(Vector2(20, 34), BOSS_NAMES[boss_id], 11, Color(0.8, 0.8, 0.9))
	var status := ""
	if core_immune():
		status = "CORE SHIELDED - destroy shields"
	elif core_armored():
		status = "CORE ARMORED (%d parts left)" % _others_alive()
	if critical():
		status = "!! CRITICAL: LASER + BOMB !!"
	txt(Vector2(W - 230, 34), status, 11, Color(1, 0.9, 0.3) if critical() else Color(0.7, 0.8, 1.0))

	var ccol := Color(1, 1, 1)
	if chain >= 200:
		ccol = Color(1.0, 0.3, 0.9)
	elif chain >= 100:
		ccol = Color(1.0, 0.85, 0.2)
	txt(Vector2(20, 90), "%d" % chain, 48, ccol)
	txt(Vector2(20, 108), "HITS", 12, Color(0.8, 0.8, 0.9))
	draw_rect(Rect2(20, 114, 120, 6), Color(0.2, 0.2, 0.25))
	if chain > 0:
		draw_rect(Rect2(20, 114, 120.0 * clampf(chain_t / CHAIN_WINDOW, 0.0, 1.0), 6), Color(0.3, 1.0, 0.5))
	if last_lost_chain > 0:
		txt(Vector2(20, 134), "dropped: %d" % last_lost_chain, 12, Color(1.0, 0.5, 0.5))

	txt(Vector2(10, H - 10), "LIVES %d   BOMBS %d   SCORE %d   MAX CHAIN %d" % [lives, bombs, score, max_chain], 12, Color(0.9, 0.9, 1.0))
	draw_rect(Rect2(W - 130, H - 22, 120, 8), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(W - 130, H - 22, 120.0 * meter / METER_MAX, 8), Color(1.0, 0.6, 0.1) if meter >= LASER_MIN else Color(0.6, 0.4, 0.2))
	txt(Vector2(W - 130, H - 26), "LASER (X)", 10, Color(1, 0.8, 0.5))
	txt(Vector2(10, H - 28), "Z shot  X laser  C bomb  1/2/3 boss  N next  R restart", 10, Color(0.6, 0.6, 0.7))

	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, clampf(flash, 0.0, 0.6) * 0.5))

	if state != "play":
		draw_rect(Rect2(0, H * 0.35, W, 150), Color(0, 0, 0, 0.75))
		txt(Vector2(20, H * 0.35 + 40), result_text, 18, Color(1, 0.9, 0.4))
		txt(Vector2(20, H * 0.35 + 75), "Max chain: %d    Score: %d" % [max_chain, score], 16, Color(1, 1, 1))
		txt(Vector2(20, H * 0.35 + 110), "R retry   N next boss   1/2/3 pick boss", 14, Color(0.7, 0.9, 1.0))
