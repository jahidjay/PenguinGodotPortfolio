class_name Run
extends Node2D
## The playable run scene for the ADR-0002 architecture: builds SimWorld,
## drives it with GameLoop, and draws it.
##
## This is the presentation layer and nothing more. It reads simulation state
## after each tick and never writes to it except through documented entry
## points (add_player, set_paused). Step 9 of the tick order.
##
## Planes: the run flies whatever the Lobby committed
## (`GameSession.selections`, menus GDD Rule 23) — plane per slot, colourway
## per slot. A run entered without the Lobby (a headless probe, or F5 in the
## editor) falls back to slot 0 on the simulation default.
##
## Local co-op: a slot that did not come through the Lobby joins by pressing
## its Fire button at any time (drop-in). P1 is KB1 or gamepad 0; P2 is KB2 or
## gamepad 1; P3-P4 are gamepads 2-3, per InputSetup.
##
## Art: sprites come from `data/art/run_visuals_1941.tres` and each enemy's
## own `sprite` field, generated on-spec by `tools/gen_placeholder_art.gd`.
## Anything still null falls back to a primitive, so the scene runs with an
## empty `assets/art/`. Enemy bullets still draw as tinted MultiMesh quads
## until the bullet atlas lands (ADR-0001 D4).
##
## Content: `data/stages/stage_1_1941.tres` — five waves of 1941 enemies, then
## the Flying Fortress. Enemies, patterns and waves are all authored data; the
## only stand-in is the ART, which is primitives until `assets/art/` has
## sprites in it.

const PLAY_AREA := Rect2(0, 0, 360, 640)
## Per-slot plane colours, matching the slot identity colours in the art bible.
const SLOT_COLORS := [
	Color(1.00, 0.70, 0.20),
	Color(0.45, 0.80, 1.00),
	Color(0.60, 1.00, 0.55),
	Color(1.00, 0.55, 0.85),
]
## Fallback bullet tints for a run with no RunVisuals. On-palette (4.3): the
## fill hue is locked to 225-265 degrees in every era.
static var BULLET_COLORS := PackedColorArray([
	Color.html("#4A5CFF"),
	Color.html("#6A6CFF"),
	Color.html("#9AA8FF"),
	Color.html("#5A4CFF"),
])

## Fallback body colours, used only for an enemy with no sprite.
const ENEMY_FILL := Color(0.42, 0.37, 0.30)
const ENEMY_EDGE := Color(0.14, 0.12, 0.16)
const ENEMY_ARMOUR := Color(0.72, 0.74, 0.80)
const BOSS_FILL := Color(0.50, 0.40, 0.28)
const SHOT_COLOR := Color(1.00, 0.95, 0.70)

## The flak fuse tell and the bomb effects, until FX sprites exist.
const FUSE_SMOKE := Color(0.18, 0.16, 0.14, 0.85)
const FUSE_SPARK := Color(1.00, 0.69, 0.00)
const BOMB_COLUMN := Color(1.00, 0.54, 0.12, 0.35)
## The Breaker erase net. Drawn UNDER the enemy bullets (art bible 6.8 layer
## 5), because a bullet disappearing has to have a visible cause.
const NET_ZONE := Color(0.62, 0.78, 1.00, 0.22)
const NET_EDGE := Color(0.80, 0.90, 1.00, 0.55)

## Fallback item tints, indexed by [enum ItemField.Kind]. Warm and cream, so
## an item is never mistaken for a bullet.
const ITEM_FALLBACK := [
	Color(1.00, 0.95, 0.80),
	Color(1.00, 0.69, 0.00),
	Color(1.00, 0.84, 0.30),
	Color(0.70, 1.00, 0.70),
	Color(1.00, 0.90, 0.55),
]

## Plane names for the readout, in [enum KitRules.Kind] order.
const KIT_NAMES := ["LANCER", "LEECH", "SENTRY", "BREAKER"]

const VISUALS_PATH := "res://data/art/run_visuals_1941.tres"
## Sky behind the parallax strips, for any frame a strip has not covered.
const SKY := Color(0.431, 0.510, 0.392)

var world: SimWorld
var loop: GameLoop
var bullet_renderer: BulletRenderer

var _readout: Label
## The big centred call-out: WAVE 2, WARNING, BOSS, STAGE CLEAR, GAME OVER.
var _banner: Label
var _banner_text := ""
var _banner_ticks := 0
var _last_wave := -1
var _last_phase := -1
## The colourway each slot's plane is drawn in, from the Lobby. It is the slot
## index unless something overrides it, which is what tells two players on the
## same plane apart (menus GDD Rule 20a).
var _colourway := PackedInt32Array([0, 1, 2, 3])
## The last drone press that the kit did not act on, and why, so the player is
## told instead of being left to wonder (plane kits Rule 30).
var _drone_notice := ""
var _drone_notice_ticks := 0
var _item_layer: Node2D
var _planes_layer: Node2D
var _world_layer: Node2D
var _enemy_layer: Node2D
var visuals: RunVisuals


func _ready() -> void:
	world = SimWorld.new(SimWorld.Config.from_data())
	visuals = load(VISUALS_PATH) as RunVisuals

	# Child order IS draw order, and the art bible's one inviolable rule is
	# that a bullet always draws on top of what it might be mistaken for:
	#   world -> enemies -> player shots -> ENEMY BULLETS -> planes.
	# The plane goes above the bullets so the hitbox is never buried, which is
	# the other half of the same rule (4.4).
	_world_layer = _add_layer("World", _draw_world)
	_enemy_layer = _add_layer("Enemies", _draw_enemy_layer)
	# Score items sit on the player-shot layer (6), above the enemies and
	# below the enemy bullets: a gem must never hide a bullet.
	_item_layer = _add_layer("Items", _draw_items)

	bullet_renderer = BulletRenderer.new()
	var tints := BULLET_COLORS
	if visuals != null and visuals.bullet_colors.size() >= 4:
		tints = visuals.bullet_colors
	bullet_renderer.setup(
		world.enemy_bullets.capacity,
		7.0,
		tints,
		visuals.bullet_atlas if visuals != null else null,
		visuals.bullet_atlas_cells if visuals != null else 4
	)
	add_child(bullet_renderer)

	_planes_layer = _add_layer("Planes", _draw_plane_layer)

	loop = GameLoop.new()
	loop.name = "GameLoop"
	loop.world = world
	# The sampler autoload feeds SimInput; absent in a headless smoke run.
	if Engine.has_singleton("InputSampler") or has_node("/root/InputSampler"):
		loop.sampler = get_node_or_null("/root/InputSampler")
	loop.tick_ran.connect(_on_tick_ran)
	add_child(loop)

	_build_readout()
	_build_banner()

	_join_selected_players()


## Rule 23: every slot the Lobby locked starts in the run, on its chosen
## plane. With no Lobby selections (headless probe, or the run scene opened
## straight from the editor) slot 0 joins on the simulation's default kit, so
## the scene is still playable on its own.
func _join_selected_players() -> void:
	var slots := GameSession.joined_slots()
	if slots.is_empty():
		world.add_player(0)
		return
	for slot: int in slots:
		var kind := GameSession.kind_of(slot)
		if kind >= 0:
			world.set_slot_kit(slot, kind)
		_colourway[slot] = GameSession.colourway_of(slot)
		world.add_player(slot)
	_claim_kb2_if_slot_1_is_in()


## Slot 0 answers WASD as well as the arrows for a solo player, but slot 1's
## keyboard scheme IS WASD — so once slot 1 is in the run, one W press would
## move both planes. The lobby does this when slot 1 joins there; a drop-in
## join has to do it too (InputSetup, input GDD "Default bindings").
func _claim_kb2_if_slot_1_is_in() -> void:
	if not world.planes.is_in_run(1):
		return
	var setup := get_node_or_null("/root/InputSetup")
	if setup != null and setup.has_method("release_wasd_from_kb1"):
		setup.release_wasd_from_kb1()


func _exit_tree() -> void:
	# The pattern scene and its emitters hold each other, so the run has to be
	# let go of explicitly or it outlives the scene (see SimWorld.dispose).
	world.dispose()


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(6, 4)
	_readout.add_theme_font_size_override("font_size", 10)
	_readout.add_theme_color_override("font_color", Color(1, 1, 1))
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_readout.add_theme_constant_override("outline_size", 3)
	layer.add_child(_readout)


## The stage's own voice. Until this existed a player had no way to tell wave
## 2 from wave 4, or to know the boss was coming — which is what made the
## stage feel as though it never progressed.
func _build_banner() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_banner = Label.new()
	_banner.size = Vector2(PLAY_AREA.size.x, 40.0)
	_banner.position = Vector2(0.0, 232.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.09))
	_banner.add_theme_constant_override("outline_size", 5)
	layer.add_child(_banner)


func _show_banner(text: String, ticks: int) -> void:
	_banner_text = text
	_banner_ticks = ticks


func _update_banner() -> void:
	var director := world.director
	if director != null:
		if director.phase == StageDirector.Phase.WAVES and director.wave_index != _last_wave:
			_last_wave = director.wave_index
			var wave: WaveDef = director.stage.waves[director.wave_index]
			_show_banner(
				"%s  %d/%d" % [
					wave.label, director.wave_index + 1, director.stage.waves.size()
				],
				120
			)
		if director.phase != _last_phase:
			_last_phase = director.phase
			if director.phase == StageDirector.Phase.BOSS_WAIT:
				_show_banner(UiStrings.text("run.warning"), 120)
			elif director.phase == StageDirector.Phase.BOSS:
				_show_banner(UiStrings.text("run.boss"), 90)

	# The two endings outrank everything and never time out.
	if world.run_state == SimWorld.RunState.GAME_OVER:
		_banner_text = UiStrings.text("run.game_over")
		_banner_ticks = 1
	elif world.run_state == SimWorld.RunState.STAGE_CLEAR:
		_banner_text = UiStrings.text("run.stage_clear")
		_banner_ticks = 1

	if _banner_ticks <= 0:
		_banner.text = ""
		return
	if world.run_state == SimWorld.RunState.PLAYING:
		_banner_ticks -= 1
	_banner.text = _banner_text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		loop.set_paused(not loop.is_paused())
		return
	if event.is_action_pressed("restart"):
		_restart()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_Q:
			# Pause's "Quit to title": the run is abandoned, nothing is saved
			# (menus GDD Rule 50). The Lobby's selections go with it.
			GameSession.clear_run()
			get_tree().change_scene_to_file("res://src/ui/menu/title.tscn")
			return
	# Drop-in co-op: a slot joins on its own Fire press.
	for slot: int in range(1, PlaneCore.MAX_SLOTS):
		if event.is_action_pressed(StringName("p%d_fire" % (slot + 1))):
			if not world.planes.is_in_run(slot):
				world.add_player(slot)
				_claim_kb2_if_slot_1_is_in()


func _restart() -> void:
	get_tree().reload_current_scene()


## Step 9: presentation, after the simulation has settled.
func _on_tick_ran(_tick: int) -> void:
	_world_layer.queue_redraw()
	_enemy_layer.queue_redraw()
	_item_layer.queue_redraw()
	_planes_layer.queue_redraw()
	_update_banner()
	_update_drone_notice()
	_update_readout()


## Answers the commonest "nothing happened" in the game: the Drone button.
## A press is buffered for 6 ticks (Input Rule 17), so a press made just
## before the ability came back still fires — but a press with NO drones, or
## one made well inside the cooldown, cannot, and the player is told which it
## was instead of being left to guess.
func _update_drone_notice() -> void:
	if _drone_notice_ticks > 0:
		_drone_notice_ticks -= 1
		if _drone_notice_ticks == 0:
			_drone_notice = ""
	if world.kits == null:
		return
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not world.planes.is_in_run(slot):
			continue
		if not world.input.pressed(slot, SimInput.Action.DRONE):
			continue
		if world.kits.drone_count(slot) < 1:
			_set_drone_notice(slot, UiStrings.text("run.no_drones"))
		elif world.kits.cooldown_left(slot) > world.input.buffer_ticks:
			_set_drone_notice(
				slot,
				UiStrings.text("run.drone_recharging").format(
					[(world.kits.cooldown_left(slot) + 59) / 60]
				)
			)


func _set_drone_notice(slot: int, text: String) -> void:
	_drone_notice = "P%d  %s" % [slot + 1, text]
	_drone_notice_ticks = 150


func _process(_delta: float) -> void:
	# Render frame: pack the bullet pool into the MultiMesh (one assignment).
	bullet_renderer.sync_from(world.enemy_bullets)


## One immediate-draw layer. Nothing is a Sprite2D node: a bullet-hell field
## redraws everything every tick anyway, and a draw call per sprite beats a
## node per sprite for churn.
func _add_layer(layer_name: String, callback: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.draw.connect(callback.bind(layer))
	add_child(layer)
	return layer


## The scrolling world (art bible 6.4, 6.5). Each strip is drawn twice, a
## height apart, so the loop never shows a gap; positions are floored to whole
## pixels, because sub-pixel scrolling shimmers on a pixel canvas.
func _draw_world(on: Node2D) -> void:
	on.draw_rect(PLAY_AREA, SKY)
	if visuals == null:
		return
	_draw_strip(on, visuals.strip_far, visuals.far_scroll_per_tick)
	_draw_strip(on, visuals.strip_mid, visuals.mid_scroll_per_tick)


func _draw_strip(on: Node2D, strip: Texture2D, speed: float) -> void:
	if strip == null:
		return
	var h := float(strip.get_height())
	var offset := fmod(float(world.game_tick) * speed, h)
	# Strips are authored 376 wide for an 8 px overscan either side, so a
	# world shake never shows an empty edge (parallax GDD).
	var x := floorf((PLAY_AREA.size.x - float(strip.get_width())) * 0.5)
	on.draw_texture(strip, Vector2(x, floorf(offset) - h))
	on.draw_texture(strip, Vector2(x, floorf(offset)))


## Under the bullets: the enemies, and the player's own shots (a player shot
## is never mistaken for an enemy bullet, and it must not hide one).
func _draw_enemy_layer(on: Node2D) -> void:
	_draw_enemies(on)
	_draw_fuse_tells(on)
	_draw_bombs(on)
	_draw_bomb_shapes(on)
	_draw_net_zones(on)
	_draw_shots(on)


## The flak fuse marker (pattern library V3). Without it a ring of twelve
## bullets appears 240 px from the gun with no warning, which is exactly the
## "fires from nowhere" the tell exists to prevent. It grows as the fuse burns
## and its spark blinks faster near the end.
func _draw_fuse_tells(on: Node2D) -> void:
	if world.patterns == null:
		return
	for fuse: Vector3 in world.patterns.collect_fuses(world.game_tick):
		var at := Vector2(fuse.x, fuse.y)
		var left := int(fuse.z)
		var grown := clampf(1.0 - float(left) / 36.0, 0.0, 1.0)
		var r := 3.0 + 4.0 * grown
		on.draw_rect(Rect2(at.x - r, at.y - r, r * 2.0, r * 2.0), FUSE_SMOKE)
		# Blinks every 12 ticks, every 6 in the last 12, solid for the last 6.
		var period := 12 if left > 12 else 6
		var lit := left <= 6 or (left / period) % 2 == 0
		if lit:
			on.draw_rect(Rect2(at.x - 1.5, at.y - 1.5, 3.0, 3.0), FUSE_SPARK)


## The Lancer bomb: a column that holds where it was cast, then splits and
## sweeps to both edges (bombs GDD Rules 19-22).
func _draw_bombs(on: Node2D) -> void:
	if world.bombs == null:
		return
	for slot: int in range(PlaneCore.MAX_SLOTS):
		var columns := world.bombs.columns_of(slot)
		if columns.size() == 0:
			continue
		var half := world.bombs.half_width()
		for cx: float in columns:
			on.draw_rect(
				Rect2(cx - half, PLAY_AREA.position.y, half * 2.0, PLAY_AREA.size.y),
				BOMB_COLUMN
			)


## The Sentry Bastion dome and the Breaker Backlash wall (GDD 29 Rules 31-32).
func _draw_bomb_shapes(on: Node2D) -> void:
	if world.bombs == null:
		return
	for slot: int in range(PlaneCore.MAX_SLOTS):
		var dome := world.bombs.dome_of(slot)
		if dome.size() == 3:
			var c := Vector2(dome[0], dome[1])
			var r := dome[2]
			on.draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), BOMB_COLUMN)
			on.draw_arc(c, r, 0.0, TAU, 32, FUSE_SPARK, 1.0)
		var wall := world.bombs.wall_of(slot)
		if wall >= 0.0:
			var h := world.bombs.wall_half_height()
			on.draw_rect(
				Rect2(PLAY_AREA.position.x, wall - h, PLAY_AREA.size.x, h * 2.0),
				BOMB_COLUMN
			)


## The Breaker erase net: the zones the drones are deleting bullets inside.
## GDD 29 Rule 34 is explicit that the net must be drawn, or a bullet
## vanishing has no visible cause.
func _draw_net_zones(on: Node2D) -> void:
	if world.kits == null:
		return
	var r := world.kits.net_radius()
	for slot: int in range(PlaneCore.MAX_SLOTS):
		var zones := world.kits.net_zones(slot)
		var z := 0
		while z + 1 < zones.size():
			var c := Vector2(zones[z], zones[z + 1])
			on.draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), NET_ZONE)
			on.draw_arc(c, r, 0.0, TAU, 24, NET_EDGE, 1.0)
			z += 2


## Pods, chain pickups, medals, 1-ups and the gems a cancelled bullet left.
## They pulse in their last two seconds, which is the only warning a pod is
## about to expire (powerups Rule 15).
func _draw_items(on: Node2D) -> void:
	if world.items == null:
		return
	var sprites: Array[Texture2D] = (
		visuals.item_sprites if visuals != null else [] as Array[Texture2D]
	)
	for i: int in range(world.items.count()):
		var kind := world.items.kind_of(i)
		var at := world.items.position_of(i)
		if world.items.is_pulsing(i) and (world.game_tick / 4) % 2 == 0:
			continue
		if kind < sprites.size() and sprites[kind] != null:
			_draw_centred(on, sprites[kind], at)
			continue
		var r := 3.0 if kind == ItemField.Kind.GEM else 6.0
		on.draw_rect(Rect2(at.x - r, at.y - r, r * 2.0, r * 2.0), ITEM_FALLBACK[kind])


## Over the bullets: the planes and their hitboxes.
func _draw_plane_layer(on: Node2D) -> void:
	_draw_lasers(on)
	_draw_planes(on)
	_draw_drones(on)


## The Lancer beam: a column from the nose to whatever stopped it, or to the
## top of the field when nothing did (plane kits Rule 19).
func _draw_lasers(on: Node2D) -> void:
	if world.kits == null:
		return
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not world.kits.is_laser_active(slot):
			continue
		var at := world.planes.position_of(slot)
		var top := world.kits.beam_top(slot)
		if top < 0.0:
			top = PLAY_AREA.position.y
		var half := world.kits.rules.laser_half_width
		var colour: Color = _slot_color(slot)
		on.draw_rect(Rect2(at.x - half, top, half * 2.0, at.y - 14.0 - top), colour)
		on.draw_rect(
			Rect2(at.x - half * 0.4, top, half * 0.8, at.y - 14.0 - top), Color.WHITE
		)


func _draw_drones(on: Node2D) -> void:
	if world.kits == null:
		return
	var sprite: Texture2D = visuals.drone_sprite if visuals != null else null
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not world.planes.is_in_run(slot):
			continue
		for d: int in range(world.kits.drone_count(slot)):
			var at := world.kits.drone_position(slot, d)
			if sprite != null:
				_draw_centred(on, sprite, at)
			else:
				on.draw_rect(Rect2(at.x - 4.0, at.y - 4.0, 8.0, 8.0), _slot_color(slot))
			# A drone that is doing something has to look like it is doing it.
			match world.kits.drone_state(slot, d):
				PlaneKits.Drone.SHIELD:
					# A Lancer shield drone: its blocking circle, so the
					# player can see what it covers.
					var r := world.kits.rules.shield_r
					on.draw_circle(at, r, Color(_slot_color(slot), 0.18))
					on.draw_arc(at, r, 0.0, TAU, 20, Color(_slot_color(slot), 0.8), 1.0)
				PlaneKits.Drone.EMPLACED:
					# A Sentry turret is planted: a base plate under the pod.
					on.draw_rect(
						Rect2(at.x - 7.0, at.y + 4.0, 14.0, 3.0), _slot_color(slot)
					)
				PlaneKits.Drone.LATCHED:
					# A Leech drone is biting: a bright ring on its host.
					on.draw_arc(at, 9.0, 0.0, TAU, 16, _slot_color(slot), 1.0)
				_:
					pass


func _draw_enemies(on: Node2D) -> void:
	if world.enemies == null:
		return
	for i: int in range(world.enemies.count()):
		var def := world.enemies.def_of(i)
		var p := world.enemies.position_of(i)
		var r := def.body_radius
		var fill := BOSS_FILL if def.size_class == EnemyDef.SizeClass.LARGE else ENEMY_FILL
		if world.enemies.is_armoured(i):
			fill = fill.lerp(ENEMY_ARMOUR, 0.45)

		if def.sprite != null:
			_draw_centred(on, def.sprite, p)
			# Plating is an overlay on top of the body, not a tint, so the
			# silhouette underneath still reads (art bible 5.7).
			if def.plating_sprite != null and world.enemies.is_armoured(i):
				_draw_centred(on, def.plating_sprite, p)
			continue

		if def.layer == EnemyDef.Layer.GROUND:
			# A squat emplacement: the player flies over it, so it has to read
			# as something on the ground rather than something in the air.
			var half := Vector2(r + def.spine_half, r * 0.7)
			on.draw_rect(Rect2(p - half, half * 2.0), fill)
			on.draw_rect(Rect2(p - half, half * 2.0), ENEMY_EDGE, false, 1.0)
			on.draw_circle(p, r * 0.35, ENEMY_EDGE)
			continue

		# An aircraft from above, nose down. Wings span the spine, so a bomber
		# reads as bigger than a scout at a glance.
		var span := r + def.spine_half
		var wing := Vector2(span * 1.1, r * 0.3)
		on.draw_rect(Rect2(p - wing, wing * 2.0), fill)
		on.draw_rect(Rect2(p - wing, wing * 2.0), ENEMY_EDGE, false, 1.0)
		var body := PackedVector2Array([
			p + Vector2(0.0, span * 0.9),
			p + Vector2(-r, -span * 0.2),
			p + Vector2(-r * 0.45, -span * 0.75),
			p + Vector2(r * 0.45, -span * 0.75),
			p + Vector2(r, -span * 0.2),
		])
		on.draw_colored_polygon(body, fill)
		on.draw_polyline(body + PackedVector2Array([body[0]]), ENEMY_EDGE, 1.0)
		if def.size_class == EnemyDef.SizeClass.LARGE:
			on.draw_circle(p, r * 0.3, ENEMY_EDGE)


func _draw_shots(on: Node2D) -> void:
	if world.kits == null:
		return
	var field := world.kits.field
	var xs := field.x_array()
	var ys := field.y_array()
	var sprite: Texture2D = visuals.shot_sprite if visuals != null else null
	# Another player's shots are dimmed by player count, so four players firing
	# never buries the field (bullet manager V3).
	var dim := 1.0
	if world.player_count() == 2:
		dim = 0.75
	elif world.player_count() > 2:
		dim = 0.5
	for i: int in range(field.count()):
		var at := Vector2(xs[i], ys[i])
		if sprite != null:
			var tint := Color(1.0, 1.0, 1.0, 1.0)
			if world.kits.shooter_of(i) != 0:
				tint.a = dim
			_draw_centred(on, sprite, at, tint)
			continue
		var fallback: Color = SHOT_COLOR.lerp(_slot_color(world.kits.shooter_of(i)), 0.35)
		on.draw_rect(Rect2(at.x - 1.0, at.y - 5.0, 2.0, 10.0), fallback)


## Draws a sprite centred on a world position, snapped to whole pixels: a
## half-pixel sprite on a 360x640 canvas shimmers and softens its outline.
func _draw_centred(on: Node2D, tex: Texture2D, at: Vector2, tint := Color.WHITE) -> void:
	on.draw_texture(
		tex,
		Vector2(
			floorf(at.x - float(tex.get_width()) * 0.5),
			floorf(at.y - float(tex.get_height()) * 0.5)
		),
		tint
	)


func _draw_planes(on: Node2D) -> void:
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not world.planes.is_in_run(slot):
			continue
		var state := world.planes.state_of(slot)
		if state == PlaneCore.State.DEAD or state == PlaneCore.State.GAME_OVER:
			continue
		var p := world.planes.position_of(slot)
		var color: Color = _slot_color(slot)

		# Invulnerable planes blink, so the state is readable without a HUD.
		# The hitbox dot never blinks (art bible: it is always visible).
		var invuln := world.planes.invuln_of(slot)
		var visible_body := invuln <= 0 or (world.game_tick / 6) % 2 == 0
		if visible_body:
			var plane := _plane_sprite(slot)
			if plane != null:
				_draw_centred(on, plane, p)
			else:
				var body := PackedVector2Array([
					p + Vector2(0, -9), p + Vector2(-7, 6), p + Vector2(7, 6),
				])
				on.draw_colored_polygon(body, color)

		# The hitbox never blinks (art bible 4.4: it is always visible).
		var ring := _hitbox_sprite(slot)
		if ring != null:
			_draw_centred(on, ring, p)
		else:
			on.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 2.0, 2.0), Color.WHITE)


## The plane this slot picked, in this slot's colourway. `plane_sprites` holds
## four colourways per plane, flattened as `kind * 4 + colourway`
## (art bible 3.1), so two players who both chose the Lancer fly the same
## airframe in two different palettes.
func _plane_sprite(slot: int) -> Texture2D:
	if visuals == null or visuals.plane_sprites.size() < 16:
		return null
	var kind := world.kits.kind_of(slot) if world.kits != null else slot
	var index := kind * 4 + _colourway[slot]
	if index < 0 or index >= visuals.plane_sprites.size():
		return null
	return visuals.plane_sprites[index]


func _hitbox_sprite(slot: int) -> Texture2D:
	if visuals == null or visuals.hitbox_sprites.size() < 4:
		return null
	return visuals.hitbox_sprites[_colourway[slot]]


## The slot's identity colour. Everything this slot owns — plane, hitbox,
## laser, drones, shots — is drawn in it (art bible 4.4).
func _slot_color(slot: int) -> Color:
	return SLOT_COLORS[_colourway[slot]]


func _update_readout() -> void:
	var lines := PackedStringArray()
	lines.append(
		"tick %d   bullets %d   tick_ms %.2f%s"
		% [
			world.game_tick,
			world.enemy_bullets.count(),
			loop.last_tick_ms(),
			"   %s" % UiStrings.text("run.paused") if loop.is_paused() else "",
		]
	)
	lines.append(
		"%s   enemies %d   killed %d   runners %d"
		% [
			world.director.status_text() if world.director != null else "no stage",
			world.enemies.count() if world.enemies != null else 0,
			world.enemies.killed_total if world.enemies != null else 0,
			world.patterns.active_runners,
		]
	)
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not world.planes.is_in_run(slot):
			lines.append("P%d  -  %s" % [slot + 1, UiStrings.text("run.press_to_join")])
			continue
		var names: PackedStringArray = [
			"EMPTY", "FLY IN", "ACTIVE", "DOWN", "GAME OVER",
		]
		var state_name: String = names[world.planes.state_of(slot)]
		# The hit counter IS the multiplier: every counted hit raises it, and
		# a hit is worth `hit_base + count`. Showing it as HIT xN is what
		# makes the chain legible as the scoring engine it is (scoring F1).
		# The > marker is the last quarter of the window, where it is about
		# to reset to zero (chain F6).
		var count := world.chain.count_of(slot)
		var chain_text := "%s %d" % [UiStrings.text("run.hit"), count]
		if count > 0:
			chain_text += "  x%d" % (world.scoring.rules.hit_base + count)
			if world.chain.is_in_red_zone(slot):
				chain_text += " >"
		lines.append(
			"P%d  lives %d  score %d  %s  %s%s"
			% [
				slot + 1,
				world.planes.lives_of(slot),
				world.scoring.display_score(slot),
				chain_text,
				state_name,
				"  INV" if world.planes.invuln_of(slot) > 0 else "",
			]
		)
		# The kit gets its own line: at 10 px on a 360 px canvas one long line
		# runs off the right edge and the player loses the end of it.
		lines.append("    %s" % _kit_text(slot).strip_edges())
	if world.chain.is_team_chain():
		lines.append("TEAM CHAIN")
	if world.items != null and world.items.count() > 0:
		lines.append(
			"items %d (%d pods, %d gems)  collected %d" % [
				world.items.count(),
				world.items.count_of_kind(ItemField.Kind.POD),
				world.items.gem_count(),
				world.items.collected_total,
			]
		)
	if world.core_is_critical():
		lines.append("BOSS CRITICAL - charge the core, then BOMB")
	if not _drone_notice.is_empty():
		lines.append(_drone_notice)
	_readout.text = "\n".join(lines)


## The kit line: what this plane is, what its charge is doing, and the three
## resources a player has to track (drones, bombs, and the kit's own meter).
func _kit_text(slot: int) -> String:
	if world.kits == null:
		return ""
	var kind := world.kits.kind_of(slot)
	var out := "  %s" % KIT_NAMES[kind]
	match kind:
		KitRules.Kind.LANCER:
			out += " laser %d%%%s" % [
				roundi(world.kits.meter_ratio(slot) * 100.0),
				" FIRING" if world.kits.is_laser_active(slot) else (
					" READY" if (
						world.kits.meter_of(slot) >= world.kits.rules.laser_min_meter
					) else ""
				),
			]
		KitRules.Kind.BREAKER:
			out += " stock %d" % world.kits.stock_of(slot)
		KitRules.Kind.SENTRY:
			out += " ENTRENCHED" if world.kits.is_charging(slot) else ""
		_:
			out += " FOCUS" if world.kits.is_charging(slot) else ""
	out += "  drones %d%s  bombs %d" % [
		world.kits.drone_count(slot),
		" OUT" if world.kits.ability_state(slot) == PlaneKits.Ability.ACTIVE else (
			" CD" if world.kits.cooldown_left(slot) > 0 else ""
		),
		world.bombs.stock_of(slot) if world.bombs != null else 0,
	]
	if world.critical != null:
		match world.critical.cue_of(slot):
			CriticalBreakCore.Cue.ARMED:
				out += "  BREAK ARMED"
			CriticalBreakCore.Cue.COMMITTED:
				out += "  BREAK COMMITTED"
			CriticalBreakCore.Cue.DONE:
				out += "  BROKEN"
			_:
				pass
	return out
