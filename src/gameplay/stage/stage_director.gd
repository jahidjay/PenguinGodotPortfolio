class_name StageDirector
extends RefCounted
## Runs one stage: five waves, then the boss
## (design/gdd/wave-and-stage-director.md; the stage shape is the game
## concept's). Step 3a of the ADR-0002 tick.
##
## It is the only thing that decides WHAT is on the field. The enemies it sends
## own their own movement and guns, so the director holds no per-enemy state —
## only which wave it is on and how long that wave has run.
##
## Scope: the MVP spine. The GDD's scroll clock, carrier events, boss
## foreshadowing, the per-wave density caps and the `StageValidator` lints are
## not here yet; what is here is the loop the player actually feels — waves
## arrive, clear, and the boss comes.
##
## Usage:
## [codeblock]
## var director := StageDirector.new(stage, enemies, events)
## # step 3a, every tick
## director.tick(world.game_tick)
## if director.is_stage_clear():
##     ...
## [/codeblock]

enum Phase { WAVES, BOSS_WAIT, BOSS, CLEARED }

var stage: StageDef
var enemies: EnemyManager
var _log: TickEventLog

var phase := Phase.WAVES
## Index of the wave running now, 0-based.
var wave_index := 0
## Ticks the current wave or wait has run.
var wave_ticks := 0
## Id of the boss enemy while it is alive, else 0.
var boss_id := 0

## Which spawn events of the current wave have already sent every member.
var _fired := PackedInt32Array()
## Members of each spawn event already sent.
var _spawned := PackedInt32Array()
## True once the current wave has put at least one enemy on the field, so an
## empty field on tick 1 is not read as "cleared".
var _wave_spawned := false


func _init(p_stage: StageDef, p_enemies: EnemyManager, p_log: TickEventLog) -> void:
	assert(p_stage != null, "StageDirector needs a StageDef (data/stages/*.tres)")
	stage = p_stage
	enemies = p_enemies
	_log = p_log
	_begin_wave(0)


func tick(t: int) -> void:
	match phase:
		Phase.WAVES:
			_tick_waves(t)
		Phase.BOSS_WAIT:
			wave_ticks += 1
			if wave_ticks >= stage.boss_delay:
				_begin_boss(t)
		Phase.BOSS:
			wave_ticks += 1
			# The boss is an enemy like any other, so it is cleared the moment
			# it is no longer on the field.
			if boss_id != 0 and not _is_alive(boss_id):
				boss_id = 0
				phase = Phase.CLEARED
				_log.append(TickEventLog.Kind.STAGE_CLEARED, -1, wave_index)
		Phase.CLEARED:
			pass


func _tick_waves(t: int) -> void:
	if wave_index >= stage.waves.size():
		_begin_boss_wait()
		return
	var wave := stage.waves[wave_index]

	for e: int in range(wave.events.size()):
		if _fired[e] != 0:
			continue
		var event := wave.events[e]
		if wave_ticks < event.at_tick:
			continue
		# A group with a stagger sends one member per `stagger` ticks; without
		# one the whole group arrives at once.
		var due := event.count
		if event.stagger > 0:
			due = mini(event.count, (wave_ticks - event.at_tick) / event.stagger + 1)
		while _spawned[e] < due:
			var member := _spawned[e]
			var id := enemies.spawn(
				event.enemy,
				event.origin + event.step * float(member),
				event.mirror,
				event.intensity,
				wave_index * 64 + e,
				member,
				event.carrier,
				event.drop_override,
				event.count
			)
			if id == 0:
				break   # the field is full: this member is retried next tick
			_wave_spawned = true
			_spawned[e] = member + 1
		if _spawned[e] >= event.count:
			_fired[e] = 1

	wave_ticks += 1
	var all_fired := true
	for e: int in range(wave.events.size()):
		if _fired[e] == 0:
			all_fired = false
	# A wave ends only when every enemy it sent has been SHOT DOWN: one that
	# flies off the field comes back around (EnemyRules.respawn_on_escape).
	var cleared := (
		all_fired and _wave_spawned and enemies.alive_count() == 0 and wave_ticks >= wave.min_ticks
	)
	if cleared:
		_log.append(TickEventLog.Kind.WAVE_CLEARED, -1, wave_index)
		if wave_index + 1 < stage.waves.size():
			_begin_wave(wave_index + 1)
		else:
			_begin_boss_wait()


func _begin_wave(index: int) -> void:
	wave_index = index
	wave_ticks = 0
	_wave_spawned = false
	phase = Phase.WAVES
	var count := stage.waves[index].events.size() if index < stage.waves.size() else 0
	_fired.resize(count)
	_fired.fill(0)
	_spawned.resize(count)
	_spawned.fill(0)
	_log.append(TickEventLog.Kind.WAVE_STARTED, -1, index)


func _begin_boss_wait() -> void:
	phase = Phase.BOSS_WAIT
	wave_ticks = 0
	# Anything still flying when the waves end leaves with the wave; the boss
	# arrives to a clear field.
	enemies.clear_all()


func _begin_boss(t: int) -> void:
	if stage.boss == null:
		phase = Phase.CLEARED
		_log.append(TickEventLog.Kind.STAGE_CLEARED, -1, wave_index)
		return
	boss_id = enemies.spawn(stage.boss, stage.boss_origin, false, 0.0, 9999, 0)
	phase = Phase.BOSS
	wave_ticks = 0
	_log.append(TickEventLog.Kind.BOSS_STARTED, -1, boss_id)


func _is_alive(id: int) -> bool:
	for i: int in range(enemies.count()):
		if enemies.id_of(i) == id:
			return true
	return false


func is_boss_alive() -> bool:
	return phase == Phase.BOSS and boss_id != 0


func is_stage_clear() -> bool:
	return phase == Phase.CLEARED


## Label for the debug readout and (later) the wave banner.
func status_text() -> String:
	match phase:
		Phase.WAVES:
			var wave: WaveDef = stage.waves[mini(wave_index, stage.waves.size() - 1)]
			return "%s  %s %d/%d" % [
				stage.label, wave.label, wave_index + 1, stage.waves.size()
			]
		Phase.BOSS_WAIT:
			return "%s  WARNING" % stage.label
		Phase.BOSS:
			return "%s  BOSS" % stage.label
		_:
			return "%s  CLEAR" % stage.label


func state_hash() -> int:
	var h := 1469598103934665603
	h = (h ^ phase) * 1099511628211
	h = (h ^ wave_index) * 1099511628211
	h = (h ^ wave_ticks) * 1099511628211
	h = (h ^ boss_id) * 1099511628211
	return h
