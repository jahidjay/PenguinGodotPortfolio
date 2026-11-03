class_name TickEventLog
extends RefCounted
## The preallocated per-tick event log from ADR-0002 Decision 5.
##
## Every simulation fact (player_died, boss_defeated, wave_started, ...) is
## appended here in arrival order during a tick. Consumers read it at their own
## step, which makes delivery deterministic:
##   consumer step AFTER the producer step   -> sees it this tick
##   consumer step AT or BEFORE the producer -> sees it next tick (`previous_*`)
##
## No simulation system connects to GameEvents. The bus is presentation-only and
## is emitted from this log at step 9, so presentation never runs mid-simulation
## and a headless verifier pays no signal cost (ADR-0002 D5).
##
## Zero allocations in the tick path: both buffers are sized once in _init and
## reused forever. `rotate()` swaps them and resets counters; it never frees or
## allocates. Growth happens only if a tick overflows the capacity, which is a
## degraded path, not the hot one (see `append`).
##
## Usage:
## [codeblock]
## # once, when the run is built
## var log := TickEventLog.new(256)
##
## # each tick, first thing SimWorld does
## log.rotate()
##
## # step 6: the collision referee records a fact
## log.append(TickEventLog.Kind.PLAYER_HIT, slot, 0)
##
## # step 8a: the chain tracker runs AFTER step 6, so it sees it this tick
## if log.has_for_slot(TickEventLog.Kind.PLAYER_HIT, slot):
##     chain_count = 0
##
## # step 3a: the director runs BEFORE step 6c, so boss_defeated is next tick
## if log.previous_has(TickEventLog.Kind.BOSS_DEFEATED):
##     start_next_wave()
##
## # step 9: presentation drains the log in arrival order
## for i: int in range(log.size()):
##     GameEvents.emit_from_log(log.kind_at(i), log.slot_at(i), log.value_at(i))
## [/codeblock]

## Event kinds. Append only — the numeric values are part of the replay format
## (ADR-0003), so never renumber or remove an existing entry.
enum Kind {
	RUN_STARTED,
	SLOT_JOINED,
	SLOT_LEFT,
	PLANE_FLY_IN_STARTED,
	PLANE_ACTIVATED,
	PLAYER_HIT,
	PLAYER_DIED,
	PLAYER_RESPAWNED,
	LIFE_LOST,
	GAME_OVER,
	CHAIN_HIT,
	CHAIN_EXPIRED,
	CHAIN_DROPPED,
	SCORE_AWARDED,
	EXTEND_EARNED,
	ENEMY_KILLED,
	PART_KILLED,
	BOSS_DEFEATED,
	CRITICAL_BREAK_LANDED,
	WAVE_STARTED,
	STAGE_STARTED,
	STAGE_CLEARED,
	BULLET_CANCEL_BURST,
	## Pattern library (9). `slot` is the burst's target slot, `value` the
	## emitter's owner id, except where noted.
	PATTERN_VOLLEY_FIRED,
	PATTERN_LOCK_STARTED,
	## `value` is 1 when the locked burst fired, 0 when it was cancelled.
	PATTERN_LOCK_ENDED,
	## `value` is the fuse length in ticks.
	PATTERN_FLAK_FUSE,
	PATTERN_FLAK_BURST,
	## Enemy (10). `value` is the enemy's unique spawn id.
	ENEMY_SPAWNED,
	## Left the field alive. No score, and it drops nothing.
	ENEMY_ESCAPED,
	## Wave and stage director (16). `value` is the wave index, 0-based.
	WAVE_CLEARED,
	BOSS_STARTED,
	## Bombs (12). `value` is the stock left.
	BOMB_USED,
	## Chain (7). A bomb toll: spent, not lost. `value` is the count after.
	CHAIN_REDUCED,
	## Powerups and drops (13). `value` is the [enum ItemField.Kind].
	ITEM_DROPPED,
	ITEM_COLLECTED,
	ITEM_EXPIRED,
	## `value` is the new drone count.
	DRONE_GAINED,
	## `value` is the new life count.
	EXTEND_AWARDED,
	## Critical Break (17). `value` is 1 when armed, 0 when it lapsed.
	CRITICAL_BREAK_ARMED,
	## The boss entered its critical window. `value` is the hp left.
	BOSS_CRITICAL,
}

const DEFAULT_CAPACITY := 256

## Flat triples (kind, slot, value), kept flat so the log hashes and serialises
## cheaply and appending touches only three array slots.
var _kind := PackedInt32Array()
var _slot := PackedInt32Array()
var _value := PackedInt32Array()
var _n := 0

var _prev_kind := PackedInt32Array()
var _prev_slot := PackedInt32Array()
var _prev_value := PackedInt32Array()
var _prev_n := 0

var _capacity: int
## Set once if a tick ever overflows, so the warning is not spammed per tick.
var _overflow_reported := false


func _init(capacity: int = DEFAULT_CAPACITY) -> void:
	_capacity = maxi(capacity, 16)
	_kind.resize(_capacity)
	_slot.resize(_capacity)
	_value.resize(_capacity)
	_prev_kind.resize(_capacity)
	_prev_slot.resize(_capacity)
	_prev_value.resize(_capacity)


## Records one fact. `slot` is the player slot it concerns, or -1 for run-wide
## events. `value` carries the single integer payload (score, chain count,
## enemy id, ...); richer payloads stay in the producing system.
##
## Writes into preallocated storage. If a single tick produces more events than
## the capacity, the buffers grow once rather than dropping events: losing an
## event would desynchronise a replay, which is worse than one late allocation.
func append(kind: int, slot: int = -1, value: int = 0) -> void:
	if _n >= _capacity:
		_grow()
	_kind[_n] = kind
	_slot[_n] = slot
	_value[_n] = value
	_n += 1


func _grow() -> void:
	_capacity *= 2
	_kind.resize(_capacity)
	_slot.resize(_capacity)
	_value.resize(_capacity)
	_prev_kind.resize(_capacity)
	_prev_slot.resize(_capacity)
	_prev_value.resize(_capacity)
	if not _overflow_reported:
		_overflow_reported = true
		push_warning(
			"TickEventLog overflowed its preallocated capacity and grew to %d. "
			% _capacity
			+ "Raise the capacity passed to TickEventLog.new() to keep the tick path allocation-free."
		)


## Called by SimWorld at the start of every tick: this tick's log becomes empty
## and last tick's becomes readable through the `previous_*` accessors.
## Swaps buffer references and resets counters — no allocation, no clearing.
func rotate() -> void:
	var k := _prev_kind
	var s := _prev_slot
	var v := _prev_value
	_prev_kind = _kind
	_prev_slot = _slot
	_prev_value = _value
	_prev_n = _n
	_kind = k
	_slot = s
	_value = v
	_n = 0


func size() -> int:
	return _n


func kind_at(i: int) -> int:
	return _kind[i]


func slot_at(i: int) -> int:
	return _slot[i]


func value_at(i: int) -> int:
	return _value[i]


## True if `kind` was logged this tick. For consumers at a later step.
func has(kind: int) -> bool:
	for i: int in range(_n):
		if _kind[i] == kind:
			return true
	return false


## True if `kind` was logged for `slot` this tick.
func has_for_slot(kind: int, slot: int) -> bool:
	for i: int in range(_n):
		if _kind[i] == kind and _slot[i] == slot:
			return true
	return false


## Number of times `kind` was logged this tick.
func count_of(kind: int) -> int:
	var n := 0
	for i: int in range(_n):
		if _kind[i] == kind:
			n += 1
	return n


## Sum of the payloads of every `kind` event this tick. Used by consumers that
## accumulate rather than react, e.g. scoring totalling a tick's hits.
func sum_of(kind: int) -> int:
	var total := 0
	for i: int in range(_n):
		if _kind[i] == kind:
			total += _value[i]
	return total


func previous_size() -> int:
	return _prev_n


func previous_kind_at(i: int) -> int:
	return _prev_kind[i]


func previous_slot_at(i: int) -> int:
	return _prev_slot[i]


func previous_value_at(i: int) -> int:
	return _prev_value[i]


## For consumers whose step runs at or before the producer's (ADR-0002 D5).
func previous_has(kind: int) -> bool:
	for i: int in range(_prev_n):
		if _prev_kind[i] == kind:
			return true
	return false


func previous_has_for_slot(kind: int, slot: int) -> bool:
	for i: int in range(_prev_n):
		if _prev_kind[i] == kind and _prev_slot[i] == slot:
			return true
	return false


## Resets both buffers without freeing them. For starting a fresh run.
func clear_all() -> void:
	_n = 0
	_prev_n = 0
