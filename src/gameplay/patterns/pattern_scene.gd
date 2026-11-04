class_name PatternScene
extends RefCounted
## Step-4 owner of every live emitter (design/gdd/bullet-pattern-library.md).
##
## Node-free, like the rest of the simulation. It holds the state that is
## shared by all emitters and must NOT be duplicated per emitter:
##
## - the player slot snapshot every runner aims and spawn-checks against;
## - the `death_fire_hold` flag (Collision 6) that silences volleys;
## - the scene-wide lit-flak-fuse count, capped at `flak_fuse_max` across ALL
##   emitters together (Rule in "Flak burst", decided 2026-11-03 wave 4);
## - the debug counters the density work reads.
##
## It also fixes the firing ORDER, which the GDD pins down because it decides
## which requests are refused when the pool is full, and therefore the state
## hash: emitter registration order, then pattern-list order, then bullet index
## (Edge Cases, "Pool and order").
##
## Usage:
## [codeblock]
## var scene := PatternScene.new(rules, world.enemy_bullets, world.events)
## scene.run_seed = run_seed
## var emitter := scene.add_emitter(&"wave_3_bomber", 0, [fan, wall], world.game_tick)
##
## # each tick, before step 4
## scene.set_slots(planes.xs(), planes.ys(), alive_flags, active_flags)
## scene.fire_hold = collision.death_fire_hold
## emitter.update(muzzle_pos, body_centre, 0.0)
## scene.tick(world.game_tick)
## [/codeblock]

const MAX_SLOTS := 4

var rules: PatternRules
## Anything with the BulletField `request_spawn` signature. Tests pass a fake
## that records every request, which is how the geometry ACs are checked.
var field
## Optional. Volley, lock and flak events are appended here for audio and VFX.
var events: TickEventLog

## Chosen once per run by Session and recorded in the replay (ADR-0003 D4).
var run_seed := 0
## Which stage this scene belongs to, part of every emitter seed.
var stage_index := 0

## Top of the play area in canvas px, used by the flak clamp (F6f step 3).
## 48 for 1-2 players, 72 for 3-4: the HUD strip grows when the third player
## joins, so the clamp floor follows it. Set through [method set_player_count].
var play_top: float

## True while Collision's `death_fire_hold` is on. Runners keep counting but
## their volleys fire nothing (Rule 8).
var fire_hold := false

## Lit flak fuses across the whole scene (Rule: `flak_fuse_max`).
var lit_fuses := 0

var emitters: Array[PatternEmitter] = []

# Debug counters (GDD "Debug counters"), reset by `begin_tick()`.
var volleys_fired := 0
var volleys_skipped := 0
var spawn_safety_skips := 0
var active_runners := 0
## Cumulative totals, for the end-of-run report.
var total_volleys_fired := 0
var total_spawn_safety_skips := 0

## The ACTIVE players' positions, compacted: `active_x[0 .. active_count)`.
##
## Spawn safety is the pattern library's hottest loop — it runs once per bullet
## per slot — so the per-tick slot snapshot is flattened here, once, instead of
## being read back through four accessors per bullet (AC-53 budget).
var active_x := PackedFloat32Array()
var active_y := PackedFloat32Array()
var active_count := 0

var _slot_x := PackedFloat32Array()
var _slot_y := PackedFloat32Array()
var _slot_alive := PackedInt32Array()
var _slot_active := PackedInt32Array()

var _tick := -1


func _init(p_rules: PatternRules, p_field, p_events: TickEventLog = null) -> void:
	assert(p_rules != null, "PatternScene needs a PatternRules (data/pattern_rules.tres)")
	assert(p_field != null, "PatternScene needs a bullet field to request spawns from")
	rules = p_rules
	field = p_field
	events = p_events
	play_top = p_rules.play_top_solo
	_slot_x.resize(MAX_SLOTS)
	_slot_y.resize(MAX_SLOTS)
	_slot_alive.resize(MAX_SLOTS)
	_slot_active.resize(MAX_SLOTS)
	active_x.resize(MAX_SLOTS)
	active_y.resize(MAX_SLOTS)


## Per-tick player snapshot. `alive` decides who can be TARGETED (it includes a
## plane flying in after a respawn); `active` decides who spawn safety protects
## (Rules 10-14). Both are read straight from PlaneCore, so the pattern library
## never second-guesses plane state.
func set_slots(
	xs: PackedFloat32Array,
	ys: PackedFloat32Array,
	alive: PackedInt32Array,
	active: PackedInt32Array,
) -> void:
	var n := 0
	for s: int in range(MAX_SLOTS):
		_slot_x[s] = xs[s]
		_slot_y[s] = ys[s]
		_slot_alive[s] = alive[s]
		_slot_active[s] = active[s]
		if active[s] != 0:
			active_x[n] = xs[s]
			active_y[n] = ys[s]
			n += 1
	active_count = n


## Picks the flak clamp floor from the player count (HUD strip 48 vs 72 px).
## The latched play_top is the HUD's (hud.md Rule 1); this follows the same
## value so a shell never bursts behind the strip.
func set_player_count(count: int) -> void:
	play_top = rules.play_top_coop if count >= 3 else rules.play_top_solo


func slot_x(slot: int) -> float:
	return _slot_x[slot]


func slot_y(slot: int) -> float:
	return _slot_y[slot]


func is_alive(slot: int) -> bool:
	return _slot_alive[slot] != 0


func is_active(slot: int) -> bool:
	return _slot_active[slot] != 0


func any_alive() -> bool:
	for s: int in range(MAX_SLOTS):
		if _slot_alive[s] != 0:
			return true
	return false


## Registers an emitter and gives it its own seeded random stream, keyed by
## `owner_id` and `emitter_index` so adding, removing or reordering any other
## emitter never changes this one's draws (Rule 15).
##
## `owner_id` is the owner's stable AUTHORED id: a boss part id, or for a wave
## enemy `event_id * 16 + member_index` (ADR-0003 Decision 4).
func add_emitter(
	owner_id: int,
	emitter_index: int,
	patterns: Array,
	at_tick: int,
) -> PatternEmitter:
	var emitter := PatternEmitter.new(self, owner_id, emitter_index, patterns, at_tick)
	emitters.push_back(emitter)
	return emitter


## Drops every emitter and cancels every lit fuse: the stage ended, so no gun
## fires a late shot (Edge Cases, "Stopping").
func remove_all_emitters() -> void:
	for i: int in range(emitters.size()):
		emitters[i].stop(true)
		emitters[i].dispose()
	emitters.clear()
	lit_fuses = 0


## Drops the emitters a single owner registered. Used when an enemy or a boss
## part dies, so `stop(destroyed)` decides whether its lit fuses still burst.
func remove_emitters_of(owner_id: int, destroyed: bool) -> void:
	var kept: Array[PatternEmitter] = []
	for i: int in range(emitters.size()):
		var e := emitters[i]
		if e.owner_id == owner_id:
			e.stop(destroyed)
			if e.has_pending_fuses():
				kept.push_back(e)  # a lit fuse on a merely-stopped gun still bursts
			else:
				e.dispose()
		else:
			kept.push_back(e)
	emitters = kept


## Runs every emitter for tick `t`, in registration order.
func tick(t: int) -> void:
	volleys_fired = 0
	volleys_skipped = 0
	spawn_safety_skips = 0
	active_runners = 0
	_tick = t
	for i: int in range(emitters.size()):
		emitters[i].tick(t)
	# A stopped emitter stays registered only while a fuse of its is still
	# burning; once it is spent it is dropped so the list cannot grow.
	var i_del := emitters.size() - 1
	while i_del >= 0:
		var e := emitters[i_del]
		if e.stopped and not e.has_pending_fuses():
			emitters.remove_at(i_del)
			e.dispose()
		i_del -= 1


func tick_index() -> int:
	return _tick


## Every lit flak fuse in the scene, as (x, y, ticks_remaining). Read by VFX
## after the tick; the simulation never looks at it.
func collect_fuses(now: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e: int in range(emitters.size()):
		var emitter := emitters[e]
		for r: int in range(emitter.runners.size()):
			var runner := emitter.runners[r]
			for f: int in range(runner.pending_fuses()):
				var at := runner.fuse_position(f)
				out.push_back(Vector3(at.x, at.y, float(runner.fuse_due_tick(f) - now)))
	return out


## End of the run: drops every emitter (which breaks the reference cycles) and
## lets go of the field and the event log. A scene that is not disposed keeps
## itself alive through its emitters, so a second run would leak the first.
func dispose() -> void:
	remove_all_emitters()
	field = null
	events = null


## True while another fuse may be lit (Rule: at most `flak_fuse_max` across the
## whole scene). A volley that cannot light one is skipped, but still counts as
## fired and still makes its random draws, so the stream stays stable.
func can_light_fuse() -> bool:
	return lit_fuses < rules.flak_fuse_max


func _append_event(kind: int, slot: int, value: int) -> void:
	if events != null:
		events.append(kind, slot, value)


## Order-dependent hash of every emitter's simulation state (ADR-0003 D5).
func hash_into(ctx: HashingContext) -> void:
	SimHash.add_int(ctx, emitters.size())
	SimHash.add_int(ctx, lit_fuses)
	for i: int in range(emitters.size()):
		emitters[i].hash_into(ctx)
