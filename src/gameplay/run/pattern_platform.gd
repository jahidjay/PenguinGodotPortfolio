class_name PatternPlatform
extends RefCounted
## SCAFFOLDING — a step-4 owner that holds real [PatternEmitter]s and moves
## them, so the run scene has authored patterns to dodge before Enemy (10) and
## Boss (14) exist.
##
## What it is NOT: it is not an enemy, it has no hit points, it cannot be shot,
## and it does not model a boss's parts or phases. It does exactly the one job
## an owner owes the pattern library (design/gdd/bullet-pattern-library.md
## Rule 2): every tick, tell each emitter where it is (`origin`, `centre`) and
## how hard it is pushing (`intensity`).
##
## Delete it when the Enemy and Boss epics land. The emitters, the patterns and
## the [PlatformDef] offsets it installs are the real data and move across.
##
## Deterministic by construction: the position comes from the integer tick as a
## triangle wave, never from `delta` or the platform `sin` (ADR-0001 D5,
## ADR-0003 D3). All tuning comes from its [PlatformDef].
##
## Usage:
## [codeblock]
## var def := load("res://data/run/platform_fortress_1941.tres") as PlatformDef
## world.emitters.append(PatternPlatform.new(world, def))
## [/codeblock]

var def: PlatformDef

var _emitters: Array[PatternEmitter] = []


## Registers one emitter per gun. `owner_base` separates this platform's
## random streams from every other owner's (GDD Rule 15).
func _init(world: SimWorld, p_def: PlatformDef, owner_base := 9000) -> void:
	assert(world.patterns != null, "PatternPlatform needs a world with a PatternScene")
	assert(p_def != null, "PatternPlatform needs a PlatformDef (data/run/*.tres)")
	def = p_def
	for i: int in range(def.guns.size()):
		var gun := def.guns[i]
		_emitters.push_back(
			world.patterns.add_emitter(owner_base + i, 0, gun.patterns, world.game_tick)
		)


func tick(world: SimWorld) -> void:
	var t := world.game_tick
	var centre := Vector2(def.anchor.x + def.sway_x * _sway(t), def.anchor.y)
	var intensity := (
		clampf(float(t) / float(def.ramp_ticks), 0.0, 1.0) if def.ramp_ticks > 0 else 1.0
	)
	for i: int in range(_emitters.size()):
		_emitters[i].update(centre + def.guns[i].offset, centre, intensity)


## A triangle wave in [-1, 1] from the integer tick: no trig, no drift, and the
## same path on every platform and every machine.
func _sway(t: int) -> float:
	if def.sway_period <= 1:
		return 0.0
	var phase := t % def.sway_period
	var half := def.sway_period / 2
	var up := float(phase if phase < half else def.sway_period - phase) / float(half)
	return up * 2.0 - 1.0


## Ticks until the next volley from any of its guns, or -1 if none is
## scheduled. What Enemy (10) reads to time its tells.
func next_volley_in(t: int) -> int:
	var best := -1
	for i: int in range(_emitters.size()):
		var d := _emitters[i].next_volley_in(t)
		if d < 0:
			continue
		if best < 0 or d < best:
			best = d
	return best


## Where each gun is right now, for the run scene to draw a muzzle.
func muzzles() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in range(_emitters.size()):
		out.push_back(_emitters[i].origin)
	return out
