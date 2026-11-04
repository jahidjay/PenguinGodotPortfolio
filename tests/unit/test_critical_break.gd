extends SceneTree
## The Critical Break (design/gdd/critical-break.md): charge the wounded boss,
## then bomb it, and the chain is multiplied instead of halved.
##
## This is the game's highest-value play, so the tests care most about the two
## ways it must NOT happen: without a charge, and twice on one boss.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_critical_break.gd

const PLAY_AREA := Rect2(0, 0, 360, 640)
const CORE := 7

var _failures := 0


func _init() -> void:
	test_critical_break_is_not_armed_without_a_charge()
	test_critical_break_is_not_armed_outside_the_critical_window()
	test_critical_break_is_not_armed_when_the_charge_hit_another_target()
	test_critical_break_arms_with_a_long_charge_on_the_core()
	test_critical_break_survives_letting_go_of_fire()
	test_critical_break_fires_when_a_bomb_lands_on_the_core()
	test_critical_break_a_bomb_with_no_charge_is_counted_as_a_miss()
	test_critical_break_happens_once_per_boss()
	test_critical_break_a_committed_bomb_no_longer_needs_the_charge()
	test_critical_break_a_new_boss_arms_it_again()
	test_critical_break_the_bomb_waives_the_chain_toll_when_armed()

	print("CriticalBreak tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- Rules 5-9: what counts as armed -----------------------------------------

func test_critical_break_is_not_armed_without_a_charge() -> void:
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]

	# Act: critical, active, but the player never charged.
	_charge(rig, 0)

	# Assert
	_assert(not cb.is_armed(0, 100, CORE, true, true), "no charge, no break")


func test_critical_break_is_not_armed_outside_the_critical_window() -> void:
	# Rule 3: the break exists only while the core is Critical.
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]

	# Act
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])

	# Assert
	_assert(not cb.is_armed(0, rig[3], CORE, false, true), "a healthy boss cannot be broken")
	_assert(cb.is_armed(0, rig[3], CORE, true, true), "the same charge works once it is critical")


func test_critical_break_is_not_armed_when_the_charge_hit_another_target() -> void:
	# Rule 8: the charge has to be ON THE CORE, not on an escort.
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]

	# Act
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE + 99, rig[3])

	# Assert
	_assert(not cb.is_armed(0, rig[3], CORE, true, true), "charging an escort does not arm it")


func test_critical_break_arms_with_a_long_charge_on_the_core() -> void:
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]

	# Act
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])

	# Assert
	_assert(cb.is_armed(0, rig[3], CORE, true, true), "a long charge landing on the core arms it")
	# The cue is published by tick(), so it reports the state as of the last
	# tick: one more tick after the hit is when the HUD learns about it.
	cb.tick(rig[3], rig[1], rig[2], CORE, true, rig[4])
	_assert_eq(cb.cue_of(0), CriticalBreakCore.Cue.ARMED, "and the HUD is told")


func test_critical_break_survives_letting_go_of_fire() -> void:
	# Rule 7: the lenience window, so releasing Fire and tapping Bomb works.
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])
	var at: int = rig[3]

	# Assert
	_assert(
		cb.is_armed(0, at + cb.rules.charge_lenience, CORE, true, true),
		"still armed inside the lenience"
	)
	_assert(
		not cb.is_armed(0, at + cb.rules.charge_lenience + 1, CORE, true, true),
		"and not a tick past it"
	)


# --- Rules 11-13: the trigger -------------------------------------------------

func test_critical_break_fires_when_a_bomb_lands_on_the_core() -> void:
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]
	var broke: Array = []
	cb.on_break = func(slot: int, core: int) -> void:
		broke.append(slot)
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])

	# Act
	var t: int = rig[3] + 1
	cb.note_bomb_landed(0, CORE, t, CORE)
	cb.tick(t, rig[1], rig[2], CORE, true, rig[4])

	# Assert
	_assert_eq(broke, [0], "the break fired for the charging slot")
	_assert(cb.consumed, "and is consumed")
	_assert_eq(cb.breaks_this_run, 1, "counted once")


func test_critical_break_a_bomb_with_no_charge_is_counted_as_a_miss() -> void:
	# Rule 19: it still does its bomb damage; it just earns no bonus. The
	# count exists so a playtest can tell "broken" from "done wrong".
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]
	var broke: Array = []
	cb.on_break = func(slot: int, core: int) -> void:
		broke.append(slot)

	# Act
	cb.note_bomb_landed(0, CORE, 100, CORE)
	cb.tick(100, rig[1], rig[2], CORE, true, rig[4])

	# Assert
	_assert_eq(broke, [], "no break")
	_assert_eq(cb.misses_no_charge, 1, "and the miss is counted")
	_assert(not cb.consumed, "the break is still available")


func test_critical_break_happens_once_per_boss() -> void:
	# Rule 4.
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]
	var breaks := [0]
	cb.on_break = func(slot: int, core: int) -> void:
		breaks[0] += 1
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])
	var t: int = rig[3] + 1
	cb.note_bomb_landed(0, CORE, t, CORE)
	cb.tick(t, rig[1], rig[2], CORE, true, rig[4])

	# Act: charge and bomb the same boss again.
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])
	var t2: int = rig[3] + 1
	cb.note_bomb_landed(0, CORE, t2, CORE)
	cb.tick(t2, rig[1], rig[2], CORE, true, rig[4])

	# Assert
	_assert_eq(breaks[0], 1, "one break per boss, however many bombs follow")
	_assert(not cb.is_armed(0, t2, CORE, true, true), "and nobody can arm after it")


func test_critical_break_a_committed_bomb_no_longer_needs_the_charge() -> void:
	# Rule 10: this is how the Leech works at all — press Bomb while the
	# focused shot is landing, then let go and wait for the hooks.
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]
	var broke: Array = []
	cb.on_break = func(slot: int, core: int) -> void:
		broke.append(slot)
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])

	# Act: commit now, then land the bomb long after the charge has lapsed.
	cb.note_bomb_started(0, rig[3], true, true)
	_assert(cb.is_committed(0), "the bomb is committed")
	var late: int = rig[3] + 300
	cb.note_bomb_landed(0, CORE, late, CORE)
	cb.tick(late, rig[1], rig[2], CORE, true, rig[4])

	# Assert
	_assert_eq(broke, [0], "a committed bomb breaks even with the charge long gone")


func test_critical_break_a_new_boss_arms_it_again() -> void:
	# Arrange
	var rig := _rig()
	var cb: CriticalBreakCore = rig[0]
	cb.on_break = func(slot: int, core: int) -> void:
		pass
	_charge(rig, 40)
	cb.note_charge_hit(0, CORE, rig[3])
	var t: int = rig[3] + 1
	cb.note_bomb_landed(0, CORE, t, CORE)
	cb.tick(t, rig[1], rig[2], CORE, true, rig[4])
	_assert(cb.consumed, "consumed on this boss")

	# Act
	cb.on_core_spawned()

	# Assert
	_assert(not cb.consumed, "the next boss can be broken too")


# --- Bombs Rule 12: the toll is waived ---------------------------------------

func test_critical_break_the_bomb_waives_the_chain_toll_when_armed() -> void:
	# Arrange: a real BombCores wired to a cb_armed query, which is exactly
	# how SimWorld wires it.
	var log := TickEventLog.new(256)
	var chain := ChainCore.new(load("res://data/chain_rules.tres"), log)
	var planes := PlaneCore.new(load("res://data/plane_rules.tres"), PLAY_AREA, log)
	planes.join(0)
	var input := SimInput.new()
	for t: int in range(200):
		input.begin_tick()
		planes.tick(input)
	var bombs := BombCores.new(load("res://data/bomb_rules.tres"), log)
	var armed := [false]
	bombs.cb_armed = func(slot: int) -> bool:
		return armed[0]
	chain.add_bonus(0, 100)

	# Act: an ordinary bomb first.
	input.begin_tick()
	input.set_button(0, SimInput.Action.BOMB, true)
	planes.tick(input)
	bombs.tick(planes, input, null, null, chain)
	var after_plain := chain.count_of(0)

	# Assert
	_assert_eq(after_plain, 50, "an ordinary bomb costs half the chain")

	# Act: and an armed one.
	chain.add_bonus(0, 50)
	armed[0] = true
	for t: int in range(200):
		input.begin_tick()
		planes.tick(input)
		bombs.tick(planes, input, null, null, chain)
	var before := chain.count_of(0)
	input.begin_tick()
	input.set_button(0, SimInput.Action.BOMB, true)
	planes.tick(input)
	bombs.tick(planes, input, null, null, chain)

	# Assert
	_assert_eq(
		chain.count_of(0), before,
		"an armed bomb pays no toll: the chain is about to be multiplied"
	)


# --- helpers ------------------------------------------------------------------

## [cb, planes, kits, tick, chain]
func _rig() -> Array:
	var log := TickEventLog.new(256)
	var chain_rules: ChainRules = load("res://data/chain_rules.tres")
	var cb := CriticalBreakCore.new(
		load("res://data/critical_break_rules.tres"), chain_rules, log
	)
	var planes := PlaneCore.new(load("res://data/plane_rules.tres"), PLAY_AREA, log)
	planes.join(0)
	var kits := PlaneKits.new(
		load("res://data/kit_rules.tres"), load("res://data/bullet_rules.tres"), PLAY_AREA
	)
	var input := SimInput.new()
	for t: int in range(200):
		input.begin_tick()
		planes.tick(input)
	return [cb, planes, kits, 0, ChainCore.new(chain_rules, log), input, log]


## Runs `ticks` ticks of the Lancer holding Fire with a full meter, so the
## laser (its charge source) is running, and advances the rig's clock.
func _charge(rig: Array, ticks: int) -> void:
	var cb: CriticalBreakCore = rig[0]
	var planes: PlaneCore = rig[1]
	var kits: PlaneKits = rig[2]
	var chain: ChainCore = rig[4]
	var input: SimInput = rig[5]
	for i: int in range(300):
		kits.report_shot_hit(0)
	var t: int = rig[3]
	for i: int in range(ticks):
		t += 1
		input.begin_tick()
		input.set_button(0, SimInput.Action.FIRE, true)
		planes.tick(input)
		kits.tick(planes, input, null, null)
		cb.tick(t, planes, kits, CORE, true, chain)
	rig[3] = t


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
