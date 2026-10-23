class_name ChainTracker
extends RefCounted
## Per-player hit chain. Pure logic, no nodes, so it is easy to unit test.
## Every hit refreshes a strict window. When the window runs out (or the player
## is hit), the chain resets to 0. No partial decay.
## Implements: design/gdd/game-concept.md §4 (Chain System).
##
## Usage:
##   var chain := ChainTracker.new(rules)
##   chain.add_hits()          # on every accepted hit
##   chain.tick(delta)         # every physics frame
##   chain.apply_critical_break()

signal chain_dropped(final_count: int)

var count := 0
var max_count := 0
var last_dropped := 0
var time_left := 0.0

var _rules: CombatRules


func _init(rules: CombatRules) -> void:
	_rules = rules


func add_hits(amount: int = 1) -> void:
	count += amount
	time_left = _rules.chain_window
	max_count = maxi(max_count, count)


func tick(delta: float) -> void:
	if count == 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		drop()


func drop() -> void:
	if count == 0:
		return
	last_dropped = count
	chain_dropped.emit(count)
	count = 0
	time_left = 0.0


## Multiplies the chain for a Critical Break. Returns the new count.
func apply_critical_break() -> int:
	count = count * _rules.break_mult + _rules.break_add
	max_count = maxi(max_count, count)
	time_left = _rules.chain_window
	return count


## 0..1 remaining window, for the HUD bar.
func window_ratio() -> float:
	if count == 0:
		return 0.0
	return clampf(time_left / _rules.chain_window, 0.0, 1.0)
