extends SceneTree
## Generates the placeholder sprite set from the art bible
## (`design/art/art-bible.md` sections 4, 5.7, 5.8, 8.3, 8.5).
##
## Run from the project folder:
##   godot --headless --script res://tools/gen_placeholder_art.gd
##
## WHAT THESE ARE: on-spec placeholders. Every sprite is the size its tier
## allows, uses only colours from `assets/art/palettes/`, carries the right
## outline (1 px Ink on popcorn and mid, 2 px on large and bosses, the player's
## slot colour on a plane) and sits in a frame cell with even dimensions so a
## centred sprite never lands on a half pixel.
##
## WHAT THEY ARE NOT: art. They are deliberately geometric block silhouettes,
## so nobody mistakes them for final work. What they buy is the whole pipeline
## being real — folders, naming, import settings, pivots, colour budgets — so
## hand-drawn or AI-generated sprites are a file swap rather than a port.
##
## The generator is the spec made executable: if a sprite breaks its size tier
## or its colour cap, this script says so and exits non-zero.

const PALETTE_DIR := "res://assets/art/palettes"
const OUT := "res://assets/art"

## Per-category colour caps from art bible 8.3.
const CAPS := {
	"char": 16, "enemy_popcorn": 8, "enemy_mid": 12, "enemy_large": 16,
	"boss": 24, "shot": 4, "icon": 6, "env": 24,
}

var _pal := {}
var _problems: Array[String] = []
var _written := 0


func _init() -> void:
	_load_palettes()
	if _pal.is_empty():
		print("FAIL: no palettes in %s (run the palette step first)" % PALETTE_DIR)
		quit(1)
		return

	_gen_players()
	_gen_drones()
	_gen_enemies_1941()
	_gen_boss_fortress()
	_gen_shots_and_hitbox()
	_gen_bullet_atlas()
	_gen_items()
	_gen_env_1941()

	print("")
	if _problems.is_empty():
		print("%d files written, every one inside its size tier and colour cap." % _written)
	else:
		print("%d files written, %d PROBLEMS:" % [_written, _problems.size()])
		for p: String in _problems:
			print("  %s" % p)
	quit(1 if _problems.size() > 0 else 0)


# --- palettes ----------------------------------------------------------------

## Reads the `.gpl` files, which the art bible calls the only source of truth.
## Each entry is keyed by its hex, and the order is kept so a sprite can ask
## for "1941 sky" by name.
func _load_palettes() -> void:
	var dir := DirAccess.open(PALETTE_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		if not file.ends_with(".gpl"):
			continue
		var f := FileAccess.open("%s/%s" % [PALETTE_DIR, file], FileAccess.READ)
		var colours: Array[Color] = []
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line.is_empty() or line.begins_with("#") or line.begins_with("GIMP") \
					or line.begins_with("Name:") or line.begins_with("Columns:"):
				continue
			var parts := line.split("\t")
			if parts.size() < 2:
				continue
			var hex := parts[1].split(" ")[0]
			colours.push_back(Color.html(hex))
		_pal[file.trim_suffix(".gpl")] = colours


func _c(palette: String, index: int) -> Color:
	var list: Array[Color] = _pal[palette]
	return list[index]


# Named indices into the palette files, in the order they are written there.
# pal_global
const G_TRACER := 0
const G_GOLD := 1
const G_INK := 10
const G_CREAM := 11
const G_CHAR := 12
# pal_players: P1..P4, shot core, fill, edge, white
const P_SHOT_CORE := 4
const P_SHOT_FILL := 5
const P_SHOT_EDGE := 6
const P_WHITE := 7
# pal_1941: sky, far, mid, ground, accent, shadow, enemy body, enemy outline
const E_SKY := 0
const E_FAR := 1
const E_MID := 2
const E_GROUND := 3
const E_ACCENT := 4
const E_SHADOW := 5
const E_BODY := 6
const E_OUTLINE := 7


# --- players (art bible 3.1, 5.7 value rule, 8.3: 39-48 long axis, 16 col) ---

## The four planes, each in each slot's outline colour.
##
## Four silhouettes that stay apart at thumbnail size (3.1): Sentry is a broad
## straight-winged workhorse, Breaker a stubby swept interceptor, Lancer a long
## thin racer, Leech a low wide delta. The body is a warm cream-to-gold ramp,
## because the value rule puts players above every enemy; the 1 px outline is
## the slot colour (4.4), never Ink.
func _gen_players() -> void:
	# File names only. RunVisuals.plane_sprites stores them in KitRules.Kind
	# order (lancer, leech, sentry, breaker) — see data/art/run_visuals_1941.tres.
	var names := ["sentry", "breaker", "lancer", "leech"]
	for t: int in range(names.size()):
		for slot: int in range(4):
			var canvas := _plane(t, _c("pal_players", slot))
			_check(canvas, "char", 48, "char_%s_p%d_48x48" % [names[t], slot + 1])
			_save(canvas, "%s/players/char_%s_p%d_48x48.png" % [OUT, names[t], slot + 1])


func _plane(kind: int, accent: Color) -> PixelCanvas:
	var canvas := PixelCanvas.new(48, 48)
	var body := _c("pal_global", G_CREAM)
	var shade := _c("pal_global", G_GOLD)
	var glass := Color.html("#3A2A14")
	var exhaust := _c("pal_global", G_TRACER)
	var cx := 24

	match kind:
		0:  # Sentry: broad straight wings, twin tail, radial nose
			canvas.rect_centred(cx, 4, 8, 38, body)
			canvas.ellipse(cx, 7, 5, 4, shade)
			canvas.rect_centred(cx, 22, 44, 7, body)
			canvas.rect_centred(cx, 36, 18, 4, body)
			canvas.rect(cx - 10, 33, 3, 8, body)
			canvas.rect(cx + 7, 33, 3, 8, body)
			canvas.rect_centred(cx, 15, 4, 6, glass)
			canvas.rect_centred(cx, 41, 6, 2, exhaust)
		1:  # Breaker: stubby, swept wings, blunt nose
			canvas.rect_centred(cx, 7, 11, 33, body)
			canvas.ellipse(cx, 9, 6, 4, shade)
			canvas.trapezoid(cx, 20, 44, 26, 9, body)
			canvas.rect_centred(cx, 36, 22, 5, body)
			canvas.rect_centred(cx, 16, 5, 6, glass)
			canvas.rect_centred(cx, 39, 9, 2, exhaust)
		2:  # Lancer: long thin fuselage, narrow wings set back
			canvas.rect_centred(cx, 2, 6, 43, body)
			canvas.ellipse(cx, 4, 3, 5, shade)
			canvas.rect_centred(cx, 26, 30, 5, body)
			canvas.rect_centred(cx, 38, 14, 3, body)
			canvas.rect_centred(cx, 14, 4, 7, glass)
			canvas.rect_centred(cx, 44, 4, 2, exhaust)
		_:  # Leech: low wide delta, short fuselage
			canvas.rect_centred(cx, 8, 10, 30, body)
			canvas.trapezoid(cx, 14, 8, 44, 22, body)
			canvas.ellipse(cx, 11, 5, 4, shade)
			canvas.rect_centred(cx, 17, 5, 6, glass)
			canvas.rect_centred(cx, 37, 12, 2, exhaust)

	canvas.mirror_left_to_right()
	canvas.highlight_top_left(body, Color.html("#FFFFFF"))
	canvas.outline(accent)
	return canvas


## A drone: 12x12, 6 colours (8.3). Warm like the plane it belongs to, with
## the slot accent as its outline, so four players never confuse theirs.
func _gen_drones() -> void:
	for slot: int in range(4):
		var canvas := PixelCanvas.new(12, 12)
		var body := _c("pal_global", G_CREAM)
		canvas.ellipse(6, 6, 4, 4, body)
		canvas.rect_centred(6, 2, 4, 3, _c("pal_global", G_GOLD))
		canvas.rect_centred(6, 9, 6, 2, _c("pal_global", G_TRACER))
		canvas.mirror_left_to_right()
		canvas.outline(_c("pal_players", slot))
		_check(canvas, "icon", 12, "drone_pod_p%d_12" % (slot + 1))
		_save(canvas, "%s/players/drone_pod_p%d_12.png" % [OUT, slot + 1])


# --- the enemy bullet atlas (4.3; ADR-0001 Decision 4) ----------------------

## One strip of ATLAS_CELL-wide cells, one per [enum BulletRules.Shape], in
## enum order: ORB, RICE, NEEDLE, RING. The MultiMesh picks the cell from
## INSTANCE_CUSTOM.x, so a bullet costs no extra draw call whatever shape it
## is, and swapping this one PNG re-skins every enemy bullet in the game.
##
## The art bible locks the bullet FILL hue to 225-265 degrees in every era
## (4.3), so a player's colour-reading skill transfers across all four. The
## cells here are white-on-transparent and are TINTED per shape at runtime,
## which is what keeps that lock in data rather than in a PNG.
func _gen_bullet_atlas() -> void:
	var cell := 16
	var atlas := PixelCanvas.new(cell * 4, cell)
	var core := Color(1, 1, 1, 1)
	var body := Color(1, 1, 1, 0.80)
	var rim := Color(1, 1, 1, 0.45)

	# ORB: the readable default. A disc with a bright centre.
	var o := PixelCanvas.new(cell, cell)
	o.ellipse(8, 8, 6, 6, rim)
	o.ellipse(8, 8, 5, 5, body)
	o.ellipse(8, 8, 2, 2, core)
	atlas.blit(o, 0, 0)

	# RICE: a short vertical grain, the dense-pattern bullet.
	var r := PixelCanvas.new(cell, cell)
	r.capsule(8, 3, 8, 12, 3, rim)
	r.capsule(8, 4, 8, 11, 2, body)
	r.capsule(8, 5, 8, 10, 1, core)
	atlas.blit(r, cell, 0)

	# NEEDLE: long and thin, so a fast aimed shot reads as fast.
	var n := PixelCanvas.new(cell, cell)
	n.rect_centred(8, 1, 3, 14, rim)
	n.rect_centred(8, 2, 1, 12, core)
	atlas.blit(n, cell * 2, 0)

	# RING: hollow, so a wall of them still shows the gaps behind it.
	var g := PixelCanvas.new(cell, cell)
	g.ellipse(8, 8, 7, 7, body)
	g.ellipse(8, 8, 4, 4, Color(0, 0, 0, 0))
	atlas.blit(g, cell * 3, 0)

	_check(atlas, "shot", 64, "bullet_atlas_1941_64x16")
	_save(atlas, "%s/shots_fx/bullet_atlas_64x16.png" % OUT)


# --- score items and pickups (powerups-and-drops.md; 8.3 icon tier) ---------

## The five item kinds, in [enum ItemField.Kind] order. Every one is cream
## with a warm rim, because an item must never be mistaken for a bullet (the
## bullet fill hue is locked to 225-265 degrees and nothing here uses it), and
## every one carries a different GLYPH, so the kind reads in one glance and
## without colour (4.4, accessibility 28).
func _gen_items() -> void:
	var cream := _c("pal_global", G_CREAM)
	var gold := _c("pal_global", G_GOLD)
	var tracer := _c("pal_global", G_TRACER)
	var ink := _c("pal_global", G_INK)

	# POD: a drone pod. A rounded capsule with a gold nose, like the drone it
	# becomes.
	var pod := PixelCanvas.new(16, 16)
	pod.capsule(8, 4, 8, 11, 4, cream)
	pod.rect_centred(8, 3, 6, 3, gold)
	pod.rect_centred(8, 12, 8, 2, tracer)
	pod.outline(ink)
	_check(pod, "icon", 16, "item_pod_16")
	_save(pod, "%s/items/item_pod_16.png" % OUT)

	# CHAIN: a chain link, drawn as two interlocking rings.
	var chain := PixelCanvas.new(14, 14)
	_ring_pattern(chain, 5, 7, 4, 0, cream)
	_ring_pattern(chain, 9, 7, 4, 0, gold)
	chain.outline(ink)
	_check(chain, "icon", 14, "item_chain_14")
	_save(chain, "%s/items/item_chain_14.png" % OUT)

	# MEDAL: the classic shmup medal. An octagon with a bright centre.
	var medal := PixelCanvas.new(14, 14)
	medal.ellipse(7, 7, 5, 5, gold)
	medal.ellipse(7, 7, 3, 3, cream)
	medal.px(7, 7, _c("pal_global", G_TRACER))
	medal.outline(ink)
	_check(medal, "icon", 14, "item_medal_14")
	_save(medal, "%s/items/item_medal_14.png" % OUT)

	# 1UP: a wing, with the gold rim Rule 11 asks for so it reads as special.
	var oneup := PixelCanvas.new(16, 16)
	oneup.trapezoid(8, 4, 4, 12, 7, cream)
	oneup.rect_centred(8, 11, 4, 3, tracer)
	oneup.outline(gold)
	_check(oneup, "icon", 16, "item_1up_16")
	_save(oneup, "%s/items/item_1up_16.png" % OUT)

	# GEM: the small one, made from a cancelled bullet. A diamond, so a stream
	# of them never looks like the bullets they came from.
	var gem := PixelCanvas.new(10, 10)
	for i: int in range(5):
		gem.rect(4 - i + 1, 1 + i, (i * 2) + 1, 1, cream)
	for i: int in range(4):
		gem.rect(1 + i, 6 + i, 7 - (i * 2), 1, gold)
	gem.outline(ink)
	_check(gem, "icon", 10, "item_gem_10")
	_save(gem, "%s/items/item_gem_10.png" % OUT)


# --- 1941 enemies (5.7 classes, 8.3 tiers, era palette 4.5) ------------------

func _gen_enemies_1941() -> void:
	var scout := _scout()
	_check(scout, "enemy_popcorn", 24, "enemy_popcorn_scout_1941_24")
	_save(scout, "%s/enemies/1941/enemy_popcorn_scout_1941_24.png" % OUT)

	var prop := _prop_fighter()
	_check(prop, "enemy_popcorn", 27, "enemy_popcorn_prop_1941_26")
	_save(prop, "%s/enemies/1941/enemy_popcorn_prop_1941_26.png" % OUT)

	var gunner := _flak_gunner()
	_check(gunner, "enemy_mid", 48, "enemy_mid_flakgunner_1941_48")
	_save(gunner, "%s/enemies/1941/enemy_mid_flakgunner_1941_48.png" % OUT)

	var bomber := _heavy_bomber(false)
	_check(bomber, "enemy_large", 96, "enemy_large_bomber_1941_96")
	_save(bomber, "%s/enemies/1941/enemy_large_bomber_1941_96.png" % OUT)

	# 5.7: a plated LARGE enemy shows its armour as an OVERLAY sprite, which
	# falls away over 8 ticks when the plating ends.
	var plate := _heavy_bomber(true)
	_save(plate, "%s/enemies/1941/enemy_large_bomber_1941_96_plate.png" % OUT)


func _scout() -> PixelCanvas:
	var canvas := PixelCanvas.new(24, 24)
	var body := _c("pal_1941", E_BODY)
	canvas.rect_centred(12, 3, 4, 17, body)
	canvas.rect_centred(12, 10, 22, 4, body)
	canvas.rect_centred(12, 18, 10, 2, body)
	canvas.mirror_left_to_right()
	canvas.highlight_top_left(body, _c("pal_1941", E_MID))
	canvas.outline(_c("pal_1941", E_OUTLINE))
	return canvas


func _prop_fighter() -> PixelCanvas:
	var canvas := PixelCanvas.new(28, 28)
	var body := _c("pal_1941", E_BODY)
	canvas.rect_centred(14, 4, 6, 19, body)
	canvas.ellipse(14, 6, 4, 3, _c("pal_1941", E_ACCENT))
	canvas.trapezoid(14, 11, 24, 17, 5, body)
	canvas.rect_centred(14, 21, 12, 3, body)
	canvas.rect_centred(14, 12, 3, 4, _c("pal_1941", E_SHADOW))
	canvas.mirror_left_to_right()
	canvas.highlight_top_left(body, _c("pal_1941", E_MID))
	canvas.outline(_c("pal_1941", E_OUTLINE))
	return canvas


## A ground emplacement (Rule 11: the player flies OVER it), so it reads as
## something sitting on the ground: a sandbag ring, a squat turret, a barrel.
func _flak_gunner() -> PixelCanvas:
	var canvas := PixelCanvas.new(48, 48)
	var sand := _c("pal_1941", E_ACCENT)
	var body := _c("pal_1941", E_BODY)
	canvas.ellipse(24, 32, 22, 11, sand)
	canvas.ellipse(24, 32, 15, 7, _c("pal_1941", E_SHADOW))
	canvas.ellipse(24, 28, 11, 8, body)
	canvas.rect_centred(24, 8, 5, 18, body)
	canvas.rect_centred(24, 6, 7, 3, _c("pal_1941", E_MID))
	canvas.mirror_left_to_right()
	canvas.highlight_top_left(body, _c("pal_1941", E_MID))
	canvas.outline(_c("pal_1941", E_OUTLINE))
	return canvas


## Four engines and a long wing: the one silhouette that has to read as "big
## and slow" from across the screen. 2 px Ink outline (5.7).
func _heavy_bomber(plating_only: bool) -> PixelCanvas:
	var canvas := PixelCanvas.new(96, 96)
	var body := _c("pal_1941", E_BODY)
	var plate := _c("pal_1941", E_MID)
	if plating_only:
		# The overlay: armour strips over the wing roots and the spine only, so
		# the silhouette underneath still reads.
		canvas.rect_centred(48, 30, 20, 26, plate)
		canvas.rect(20, 40, 18, 8, plate)
		canvas.mirror_left_to_right()
		canvas.outline(_c("pal_global", G_CREAM))
		return canvas

	canvas.rect_centred(48, 6, 12, 74, body)
	canvas.ellipse(48, 10, 7, 6, plate)
	canvas.rect_centred(48, 38, 92, 12, body)
	for dx: int in [20, 34]:
		canvas.rect(48 - dx - 4, 34, 8, 20, plate)
	canvas.rect_centred(48, 74, 34, 6, body)
	canvas.rect(48 - 17, 68, 4, 12, body)
	canvas.rect_centred(48, 22, 6, 8, _c("pal_1941", E_SHADOW))
	canvas.mirror_left_to_right()
	canvas.highlight_top_left(body, _c("pal_1941", E_MID))
	canvas.outline(_c("pal_1941", E_OUTLINE))
	canvas.outline(_c("pal_1941", E_OUTLINE))   # 2 px for a LARGE enemy
	return canvas


# --- boss (5.8, 8.3: hull 144-270 wide, SLICED into parts, 24 colours) -------

## The Flying Fortress, as a hull plus separate parts — never one huge sprite
## (8.3). The parts are what Boss (14) will attach, move and destroy one by
## one; the hull is only the body they sit on.
func _gen_boss_fortress() -> void:
	var hull := PixelCanvas.new(216, 136)
	var body := _c("pal_1941", E_BODY)
	var plate := _c("pal_1941", E_MID)
	var shadow := _c("pal_1941", E_SHADOW)
	# Centre hull with a blunt nose, then the WING_BAR hull type of 5.8.
	hull.rect_centred(108, 10, 56, 112, body)
	hull.ellipse(108, 18, 24, 14, plate)
	hull.rect_centred(108, 52, 212, 30, body)
	hull.rect_centred(108, 46, 180, 6, plate)
	hull.rect(108 - 96, 44, 22, 46, plate)
	hull.rect_centred(108, 106, 70, 16, body)
	hull.rect_centred(108, 34, 18, 22, shadow)
	hull.mirror_left_to_right()
	hull.highlight_top_left(body, plate)
	hull.outline(_c("pal_1941", E_OUTLINE))
	hull.outline(_c("pal_1941", E_OUTLINE))
	_check(hull, "boss", 216, "boss_fortress_hull_216")
	_save(hull, "%s/bosses/boss_fortress_hull_216.png" % OUT)

	var turret := PixelCanvas.new(48, 48)
	turret.ellipse(24, 28, 15, 13, body)
	turret.ellipse(24, 26, 9, 8, plate)
	turret.rect_centred(24, 4, 6, 22, body)
	turret.mirror_left_to_right()
	turret.highlight_top_left(body, plate)
	turret.outline(_c("pal_1941", E_OUTLINE))
	turret.outline(_c("pal_1941", E_OUTLINE))
	_check(turret, "boss", 48, "boss_fortress_turret_48")
	_save(turret, "%s/bosses/boss_fortress_turret_48.png" % OUT)

	var engine := PixelCanvas.new(36, 36)
	engine.rect_centred(18, 4, 18, 28, body)
	engine.rect_centred(18, 6, 12, 6, plate)
	engine.rect_centred(18, 30, 14, 4, _c("pal_global", G_TRACER))
	engine.mirror_left_to_right()
	engine.highlight_top_left(body, plate)
	engine.outline(_c("pal_1941", E_OUTLINE))
	engine.outline(_c("pal_1941", E_OUTLINE))
	_check(engine, "boss", 36, "boss_fortress_engine_36")
	_save(engine, "%s/bosses/boss_fortress_engine_36.png" % OUT)

	var core := PixelCanvas.new(56, 56)
	core.ellipse(28, 28, 22, 22, plate)
	core.ellipse(28, 28, 14, 14, _c("pal_1941", E_ACCENT))
	core.ellipse(28, 28, 7, 7, _c("pal_global", G_GOLD))
	core.outline(_c("pal_1941", E_OUTLINE))
	core.outline(_c("pal_1941", E_OUTLINE))
	_check(core, "boss", 56, "boss_fortress_core_56")
	_save(core, "%s/bosses/boss_fortress_core_56.png" % OUT)


# --- player shot and hitbox (4.4, 8.3: shot <= 9x18, 4 colours) --------------

func _gen_shots_and_hitbox() -> void:
	var shot := PixelCanvas.new(10, 18)
	var core := _c("pal_players", P_SHOT_CORE)
	var fill := _c("pal_players", P_SHOT_FILL)
	var edge := _c("pal_players", P_SHOT_EDGE)
	# A rounded streak, brightest in the middle, and NO dark outline (4.4).
	shot.capsule(5, 4, 5, 13, 3, edge)
	shot.capsule(5, 4, 5, 13, 2, fill)
	shot.capsule(5, 5, 5, 12, 1, core)
	_check(shot, "shot", 18, "shot_streak_10x18")
	_save(shot, "%s/shots_fx/shot_streak_10x18.png" % OUT)

	# The hitbox: a white 1 px dot and a 1 px ring in the player's colour, with
	# a different ring PATTERN per slot, because P3 and P4 have equal luma and
	# the pattern is the only non-hue separation (4.4).
	for slot: int in range(4):
		var ring := PixelCanvas.new(12, 12)
		var colour := _c("pal_players", slot)
		_ring_pattern(ring, 6, 6, 5, slot, colour)
		if slot == 3:
			_ring_pattern(ring, 6, 6, 3, 0, colour)   # double ring
		ring.px(5, 5, _c("pal_players", P_WHITE))
		ring.px(6, 5, _c("pal_players", P_WHITE))
		ring.px(5, 6, _c("pal_players", P_WHITE))
		ring.px(6, 6, _c("pal_players", P_WHITE))
		_check(ring, "icon", 12, "icon_hitbox_p%d_12" % (slot + 1))
		_save(ring, "%s/players/icon_hitbox_p%d_12.png" % [OUT, slot + 1])


## Solid, dashed, dotted or solid-again (for the double ring), drawn as a 1 px
## circle so it never needs `draw_circle`, which 8.1 bans.
func _ring_pattern(canvas: PixelCanvas, cx: int, cy: int, r: int, pattern: int, c: Color) -> void:
	var steps := 48
	for s: int in range(steps):
		var keep := true
		match pattern:
			1:
				keep = (s / 4) % 2 == 0      # dashed
			2:
				keep = s % 3 == 0            # dotted
			_:
				keep = true                  # solid
		if not keep:
			continue
		var a := (s * SimMath.TURN) / steps
		canvas.px(
			cx + roundi(SimMath.cos_bam(a) * float(r)),
			cy + roundi(SimMath.sin_bam(a) * float(r)),
			c
		)


# --- 1941 environment strips (6.2, 6.4, 8.3: 376 wide, 24 colours) ----------

## Two seamless parallax strips for a TOP-DOWN view.
##
## The camera looks straight down, so there is no sky: the FAR layer is the
## ground itself (river, paddy, coast) and the MID layer is what sits between
## the ground and the plane (cloud banks, jetties, boats), mostly transparent
## and scrolling faster. That difference in speed is the parallax.
##
## Both tile exactly: every repeating feature has a period that divides the
## strip height. Contrast stays inside the era value band, nothing has an
## outline, and the 2x2 dither only appears in the outer 60 px, because 6.3
## bans a dot grid inside the central lane.
func _gen_env_1941() -> void:
	var far := _ground_strip()
	_check(far, "env", 1280, "env_strip_far_1941_1280")
	_save(far, "%s/env/1941/strips/env_strip_far_1941_1280.png" % OUT)

	var mid := _cloud_strip()
	_check(mid, "env", 1920, "env_strip_mid_1941_1920")
	_save(mid, "%s/env/1941/strips/env_strip_mid_1941_1920.png" % OUT)


## The ground: a river delta seen from above. The channel runs down the middle
## because that is the quiet lane (3.4), so the busiest shapes stay at the
## edges where no bullet has to read against them.
func _ground_strip() -> PixelCanvas:
	var canvas := PixelCanvas.new(376, 1280)
	var ground := _c("pal_1941", E_GROUND)
	var mid := _c("pal_1941", E_MID)
	var far := _c("pal_1941", E_FAR)
	var accent := _c("pal_1941", E_ACCENT)
	var shadow := _c("pal_1941", E_SHADOW)
	canvas.rect(0, 0, 376, 1280, ground)

	# Tonal variation in the field, in clusters rather than speckle (6.3).
	for y0: int in range(0, 1280, 160):
		for k: int in range(7):
			var x := 10 + ((k * 53) % 330)
			var y := y0 + ((k * 37) % 150)
			canvas.rect(x, y, 26 + (k % 3) * 10, 14 + (k % 2) * 8, far)

	# The river, with a soft bank either side. One period of 640 over 1280.
	for y: int in range(1280):
		var t := float(y) / 640.0
		var drift := roundi(22.0 * SimMath.sin_bam(roundi(t * float(SimMath.TURN))))
		var cx := 188 + drift
		canvas.rect(cx - 60, y, 120, 1, mid)
		canvas.rect(cx - 64, y, 4, 1, shadow)
		canvas.rect(cx + 60, y, 4, 1, shadow)

	# Paddy terraces at the edges only, on a 320 px period.
	for y0: int in range(0, 1280, 320):
		for row: int in range(4):
			var y := y0 + 24 + row * 72
			for col: int in range(2):
				var w := 40 + col * 18
				canvas.rect(6 + col * 46, y, w, 40, far)
				canvas.rect(6 + col * 46, y + 40, w, 3, shadow)
				canvas.rect(376 - 6 - 46 * col - w, y + 36, w, 40, far)
				canvas.rect(376 - 6 - 46 * col - w, y + 76, w, 3, shadow)
		# One landmark per period: a godown with a tin roof.
		canvas.rect(300, y0 + 180, 56, 44, accent)
		canvas.rect(300, y0 + 224, 56, 5, shadow)

	# Haze, edge zone only.
	for band: int in range(0, 1280, 96):
		canvas.dither_rect(0, band, 56, 40, shadow)
		canvas.dither_rect(320, band, 56, 40, shadow)
	return canvas


## Between the ground and the plane: cloud banks and the odd boat. Mostly
## transparent, so the ground shows through, and faster-scrolling, which is
## what sells the height.
func _cloud_strip() -> PixelCanvas:
	var canvas := PixelCanvas.new(376, 1920)
	# NOT Cream: a cream cloud is as bright as the UI text and competes with
	# the bullets. The cloud sits in the era's own value band (4.2), one step
	# above the ground, and never enters the centre lane (3.4).
	var cloud := _c("pal_1941", E_MID)
	var cloud_shadow := _c("pal_1941", E_SHADOW)
	var accent := _c("pal_1941", E_ACCENT)
	var shadow := _c("pal_1941", E_SHADOW)

	# Cloud banks, on a 480 px period, kept off the centre lane.
	for y0: int in range(0, 1920, 480):
		# All of them outside the central 120 px, where the player dodges.
		var spots := [
			Vector2i(34, 60), Vector2i(342, 150), Vector2i(18, 300),
			Vector2i(356, 380), Vector2i(40, 430),
		]
		for k: int in range(spots.size()):
			var at: Vector2i = spots[k]
			var rx := 20 + (k % 3) * 8
			var ry := 11 + (k % 2) * 5
			canvas.ellipse(at.x, y0 + at.y + 4, rx, ry, cloud_shadow)
			canvas.ellipse(at.x, y0 + at.y, rx, ry, cloud)
			canvas.ellipse(at.x - rx / 2, y0 + at.y - ry / 2, rx / 2, ry / 2, cloud)
			canvas.ellipse(at.x + rx / 2, y0 + at.y - ry / 3, rx / 2, ry / 2, cloud)

		# A sampan on the river and a jetty reaching into it: the two props
		# that say "delta" without a word of text (6.7).
		canvas.rect(176, y0 + 220, 8, 26, accent)
		canvas.rect(178, y0 + 226, 4, 14, shadow)
		canvas.rect(120, y0 + 96, 48, 7, accent)
		canvas.rect(120, y0 + 103, 48, 2, shadow)
	return canvas


# --- checks and output -------------------------------------------------------

## Fails the run if a sprite is outside its size tier or over its colour cap.
func _check(canvas: PixelCanvas, category: String, max_axis: int, name: String) -> void:
	var box := canvas.bounds()
	if box.size.x > max_axis or box.size.y > max_axis:
		_problems.push_back(
			"%s: drawn %dx%d, tier allows %d" % [name, box.size.x, box.size.y, max_axis]
		)
	var cap: int = CAPS.get(category, 99)
	var used := canvas.colour_count()
	if used > cap:
		_problems.push_back("%s: %d colours, cap is %d (8.3)" % [name, used, cap])
	if canvas.w % 2 != 0 or canvas.h % 2 != 0:
		_problems.push_back("%s: frame cell %dx%d is not even (8.3)" % [name, canvas.w, canvas.h])
	print("  %-44s %3dx%-3d  %2d colours" % [name, box.size.x, box.size.y, used])


func _save(canvas: PixelCanvas, path: String) -> void:
	canvas.save(path)
	_written += 1
