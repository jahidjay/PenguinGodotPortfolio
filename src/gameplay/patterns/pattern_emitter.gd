class_name PatternEmitter
extends RefCounted
## A point that fires patterns (design/gdd/bullet-pattern-library.md Rule 2).
##
## The emitter is the OWNER-FACING half of the library: an enemy or a boss part
## moves it, sets its intensity, and starts or stops it. It does not decide
## when to fire — that belongs to its [PatternRunner]s, one per pattern in its
## list, which are independent and may fire on the same tick (Rule 3).
##
## What the emitter itself owns:
##
## - the **target cursor** (Rule 10, F4): which player the next burst aims at.
##   It is per-emitter and shared by the emitter's runners, so two stacked
##   patterns do not both pick the same player forever.
## - the **random stream** (Rule 15), seeded from `owner_id` and
##   `emitter_index`, so adding or reordering other emitters never shifts this
##   one's ring offsets, wall gaps or spray angles.
##
## Usage:
## [codeblock]
## var e := scene.add_emitter(part.id, 0, [spiral, rage_ring], world.game_tick)
## # every tick, before PatternScene.tick()
## e.update(part.muzzle, part.centre, boss.intensity)
## # when the part dies: a destroyed gun fires nothing more, fuses included
## e.stop(true)
## [/codeblock]

var scene: PatternScene
## Stable authored id of the owner (boss part id, or enemy
## `event_id * 16 + member_index`).
var owner_id := 0
## Index of this emitter within its owner.
var emitter_index := 0

## Spawn point, set by the owner every tick.
var origin := Vector2.ZERO
## Centre of the owner's body, for patterns that fire outward (Rule 2, F6e).
var centre := Vector2.ZERO
## 0-1, clamped. What it MEANS belongs to the owner (Rule 6).
var intensity := 0.0

## Final once set: a stopped emitter fires nothing more (Rule 9).
var stopped := false

## Previous target slot. -1 so the first burst picks the lowest Alive slot (F4).
var target_cursor := -1

var runners: Array[PatternRunner] = []
var rng: RandomNumberGenerator


func _init(
	p_scene: PatternScene,
	p_owner_id: int,
	p_emitter_index: int,
	patterns: Array,
	at_tick: int,
) -> void:
	scene = p_scene
	owner_id = p_owner_id
	emitter_index = p_emitter_index
	rng = SimRng.make(
		SimRng.EMITTER, [p_scene.run_seed, p_scene.stage_index, p_owner_id, p_emitter_index]
	)
	for i: int in range(patterns.size()):
		runners.push_back(PatternRunner.new(self, patterns[i], i, at_tick))


## The owner's per-tick report. Intensity outside 0-1 is clamped (Edge Cases).
func update(p_origin: Vector2, p_centre: Vector2, p_intensity: float) -> void:
	origin = p_origin
	centre = p_centre
	intensity = clampf(p_intensity, 0.0, 1.0)


func tick(t: int) -> void:
	for i: int in range(runners.size()):
		runners[i].tick(t)


## Stops every runner. `destroyed` true means the owner was destroyed, which
## also cancels its lit flak fuses: a dead gun fires nothing. A gun merely
## stopped (or gated out) still lets a lit fuse burst (States, Edge Cases).
func stop(destroyed: bool) -> void:
	if stopped:
		return
	stopped = true
	for i: int in range(runners.size()):
		runners[i].stop(destroyed)


## Drops this emitter's half of the scene/emitter/runner reference cycle, so
## the whole emitter frees as soon as its owner lets go of it. Called by
## [PatternScene] when it removes the emitter; final.
func dispose() -> void:
	stopped = true
	for i: int in range(runners.size()):
		runners[i].dispose()
	runners.clear()
	scene = null


func has_pending_fuses() -> bool:
	for i: int in range(runners.size()):
		if runners[i].pending_fuses() > 0:
			return true
	return false


## F4: advance to the next Alive slot after the previous target, wrapping.
## Returns the new target slot, or -1 when nobody is Alive (the cursor then
## stays where it was, so the rotation resumes in place).
func advance_target() -> int:
	for step: int in range(1, PatternScene.MAX_SLOTS + 1):
		var s := (target_cursor + step) % PatternScene.MAX_SLOTS
		if scene.is_alive(s):
			target_cursor = s
			return s
	return -1


## Ticks until the next volley over all of this emitter's runners, or -1 if
## none is scheduled. Read-only; Enemy (10) uses it to time its tells.
func next_volley_in(t: int) -> int:
	var best := -1
	for i: int in range(runners.size()):
		var d := runners[i].next_volley_in(t)
		if d < 0:
			continue
		if best < 0 or d < best:
			best = d
	return best


func hash_into(ctx: HashingContext) -> void:
	SimHash.add_int(ctx, owner_id)
	SimHash.add_int(ctx, emitter_index)
	SimHash.add_int(ctx, target_cursor)
	SimHash.add_bool(ctx, stopped)
	SimRng.hash_into(ctx, rng)
	for i: int in range(runners.size()):
		runners[i].hash_into(ctx)
