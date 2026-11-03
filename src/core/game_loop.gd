class_name GameLoop
extends Node
## The thin driver from ADR-0002 Decision 1. Each physics step it runs the
## admission gates, then SimWorld.tick(), then presentation step 9.
##
## PROCESS_MODE_ALWAYS: the loop itself must keep receiving _physics_process
## while the tree is paused, because it decides for itself whether a step
## becomes a game tick. The simulation never depends on SceneTree.paused
## (ADR-0002 Decision 4) — pause is a gate here, so pausing can never leave a
## tick half-run.
##
## Owns the integer game tick and the tick guard. Holds no gameplay rules.
##
## Usage:
## [codeblock]
## var loop := GameLoop.new()
## loop.world = SimWorld.new(SimWorld.Config.from_data())
## loop.sampler = input_sampler          # optional; a test can omit it
## add_child(loop)
## loop.world.add_player(0)
##
## loop.set_paused(true)                 # gate closes, no ticks run
## loop.tick_ran.connect(_on_tick)       # presentation hook, step 9
## [/codeblock]

## Emitted after each admitted game tick, once the simulation is settled.
## Presentation only — never used to change simulation state.
signal tick_ran(tick: int)
## Emitted when a game tick exceeds the guard budget (ADR-0002 Decision 8).
signal tick_overran(tick: int, milliseconds: float)

## ADR-0002 Decision 8: a game tick over this is logged with its timing.
const TICK_GUARD_MS := 8.0

var world: SimWorld
## Optional input sampler. Must expose service_step() and commit_sim_tick().
var sampler: Node

var _paused := false
var _ticks_run := 0
var _overruns := 0
var _last_tick_ms := 0.0
## Guards against service_step() running twice in one physics frame, per
## ADR-0002 Decision 2 (the call is idempotent per physics frame).
var _serviced_frame := -1


func _ready() -> void:
	# The loop must run while paused so its own gate decides what happens.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Lowest priority so any autoload sampler with a lower one runs first;
	# if 4.7 orders these differently, the explicit service_step() call below
	# makes the loop correct regardless (ADR-0002 verification item 1).
	process_physics_priority = 0


func _physics_process(_delta: float) -> void:
	if world == null:
		return

	# Step 0: service input in real time, every physics step, paused or not.
	_service_input()

	# Admission gates, in ADR-0002 Decision 4 order.
	if not _should_tick():
		return

	# Step 1: commit this physics step's input into the tick's SimInput.
	if sampler != null and sampler.has_method("commit_sim_tick"):
		sampler.commit_sim_tick(world.input)

	var started := Time.get_ticks_usec()
	world.tick(world.game_tick)
	_last_tick_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_ticks_run += 1

	# Step 9: presentation. Emitted after the simulation is settled, so a
	# listener can never observe a partial tick.
	tick_ran.emit(world.game_tick)

	if _last_tick_ms > TICK_GUARD_MS:
		_overruns += 1
		tick_overran.emit(world.game_tick, _last_tick_ms)
		push_warning(
			"Game tick %d took %.2f ms, over the %.1f ms guard."
			% [world.game_tick, _last_tick_ms, TICK_GUARD_MS]
		)


## Idempotent per physics frame, so it is safe whether the sampler autoload
## ran first by priority or not (ADR-0002 Decision 2 fallback).
func _service_input() -> void:
	if sampler == null or not sampler.has_method("service_step"):
		return
	var frame := Engine.get_physics_frames()
	if frame == _serviced_frame:
		return
	_serviced_frame = frame
	sampler.service_step()


## (a) pause, (b) load-discard window (ADR-0004), (c) game-speed gate
## (ADR-0005). Only the pause gate exists until those epics land.
func _should_tick() -> bool:
	if _paused:
		return false
	return true


## Pause takes effect on the physics step it arrives on: no game tick runs on
## that step. SceneTree.paused is also set so pausable presentation nodes
## freeze, but the simulation does not read it.
func set_paused(value: bool) -> void:
	if _paused == value:
		return
	_paused = value
	var tree := get_tree()
	if tree != null:
		tree.paused = value


func is_paused() -> bool:
	return _paused


func ticks_run() -> int:
	return _ticks_run


func last_tick_ms() -> float:
	return _last_tick_ms


func overrun_count() -> int:
	return _overruns
