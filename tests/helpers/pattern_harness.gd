class_name PatternHarness
extends RefCounted
## Test rig for the pattern library (design/gdd/bullet-pattern-library.md,
## "Test setup"): one [PatternScene] over a [FakeBulletField], with the player
## slot snapshot, the fire hold and the tick loop under the test's control.
##
## It exists so each test states only what it is about. Everything a test does
## not mention keeps the GDD default: slot 0 Alive and Active at (180, 500),
## no fire hold, `run_seed` 12345.

const DEFAULT_SEED := 12345

## Every harness built in this process. The scene/emitter/runner links are a
## RefCounted cycle while an emitter is live, so a test suite that simply drops
## its harnesses would report leaked objects at exit and hide a real leak.
## Call [method dispose_all] at the end of the suite.
static var _built: Array = []

var rules: PatternRules
var field: FakeBulletField
var log: TickEventLog
var scene: PatternScene

## Every event the scene logged, with the tick it was logged on. The log
## itself only keeps one tick, so a test that asserts "lock_started at 118"
## needs this.
var event_ticks := PackedInt32Array()
var event_kinds := PackedInt32Array()
var event_slots := PackedInt32Array()
var event_values := PackedInt32Array()

var _xs := PackedFloat32Array([180.0, 60.0, 300.0, 120.0])
var _ys := PackedFloat32Array([500.0, 520.0, 520.0, 560.0])
var _alive := PackedInt32Array([1, 0, 0, 0])
var _active := PackedInt32Array([1, 0, 0, 0])


func _init(p_rules: PatternRules = null, seed_value: int = DEFAULT_SEED) -> void:
	rules = p_rules if p_rules != null else load("res://data/pattern_rules.tres")
	field = FakeBulletField.new()
	log = TickEventLog.new(512)
	scene = PatternScene.new(rules, field, log)
	scene.run_seed = seed_value
	_built.push_back(self)
	_push_slots()


## Disposes every harness built in this process. Run it as the last line of a
## suite: a leak reported after this really is a leak.
static func dispose_all() -> void:
	for i: int in range(_built.size()):
		var h: PatternHarness = _built[i]
		if h.scene != null:
			h.scene.dispose()
	_built.clear()


## Places one slot and sets its state. `active` defaults to `alive`.
func set_slot(slot: int, pos: Vector2, alive: bool, active: int = -1) -> void:
	_xs[slot] = pos.x
	_ys[slot] = pos.y
	_alive[slot] = 1 if alive else 0
	_active[slot] = (1 if alive else 0) if active < 0 else active
	_push_slots()


func set_alive(slot: int, alive: bool) -> void:
	_alive[slot] = 1 if alive else 0
	_active[slot] = _alive[slot]
	_push_slots()


## Alive but not Active: a plane flying in after a respawn. It can be targeted
## and aimed at, but spawn safety ignores it (Rules 10 and 14).
func set_flying_in(slot: int, pos: Vector2) -> void:
	_xs[slot] = pos.x
	_ys[slot] = pos.y
	_alive[slot] = 1
	_active[slot] = 0
	_push_slots()


func set_nobody_alive() -> void:
	for s: int in range(PatternScene.MAX_SLOTS):
		_alive[s] = 0
		_active[s] = 0
	_push_slots()


func move_slot(slot: int, pos: Vector2) -> void:
	_xs[slot] = pos.x
	_ys[slot] = pos.y
	_push_slots()


func _push_slots() -> void:
	scene.set_slots(_xs, _ys, _alive, _active)


func add_emitter(patterns: Array, at_tick: int, owner_id: int = 1, index: int = 0) -> PatternEmitter:
	var e := scene.add_emitter(owner_id, index, patterns, at_tick)
	# Building an emitter can log at once (a pattern whose lock tick falls on
	# its activation tick, F5). In the game that happens inside a tick, after
	# the log rotated; here the test builds it before calling `run`, so the
	# record takes those events now or loses them to the first rotate.
	collect(at_tick)
	return e


## Runs ticks `from` .. `to` inclusive, holding every emitter at `origin` and
## `intensity`. `hold_range` is an inclusive [start, end] fire hold, or empty.
func run(
	emitter: PatternEmitter,
	from: int,
	to: int,
	origin := Vector2(180.0, 100.0),
	intensity := 0.0,
	hold_range := PackedInt32Array(),
	centre := Vector2.INF,
) -> void:
	for t: int in range(from, to + 1):
		log.rotate()
		field.tick = t
		scene.fire_hold = (
			hold_range.size() == 2 and t >= hold_range[0] and t <= hold_range[1]
		)
		emitter.update(origin, origin if centre == Vector2.INF else centre, intensity)
		scene.tick(t)
		collect(t)


## Copies this tick's events into the running record. Call it after
## `scene.tick(t)` in a test that drives the loop itself.
func collect(t: int) -> void:
	for i: int in range(log.size()):
		event_ticks.push_back(t)
		event_kinds.push_back(log.kind_at(i))
		event_slots.push_back(log.slot_at(i))
		event_values.push_back(log.value_at(i))


## Every recorded event of one kind, as (tick, slot, value).
func recorded(kind: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for i: int in range(event_kinds.size()):
		if event_kinds[i] == kind:
			out.push_back(Vector3i(event_ticks[i], event_slots[i], event_values[i]))
	return out


## Events of one kind logged on the tick that just ran.
func events_of(kind: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in range(log.size()):
		if log.kind_at(i) == kind:
			out.push_back(Vector2i(log.slot_at(i), log.value_at(i)))
	return out


func has_event(kind: int) -> bool:
	return log.has(kind)


## Loads a pattern authored in `data/patterns/`.
static func pattern(name: String) -> PatternDef:
	return load("res://data/patterns/%s.tres" % name) as PatternDef


## A pattern built in code, for the cases the acceptance criteria specify
## directly rather than through authored data.
static func make(kind: int, props: Dictionary = {}) -> PatternDef:
	var d := PatternDef.new()
	d.kind = kind
	d.id = &"test"
	for key: String in props:
		d.set(key, props[key])
	return d
