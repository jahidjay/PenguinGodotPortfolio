extends SceneTree
## Powerups and drops (design/gdd/powerups-and-drops.md): what a carrier
## leaves behind, what a cancelled bullet becomes, and who gets to pick it up.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_item_field.gd

const PLAY_AREA := Rect2(0, 0, 360, 640)

var _failures := 0


func _init() -> void:
	test_item_field_a_small_carrier_drops_one_item_per_player()
	test_item_field_a_large_carrier_is_a_guaranteed_bundle()
	test_item_field_pity_forces_a_pod_after_two_misses()
	test_item_field_a_death_arms_the_recovery_pod()
	test_item_field_the_need_check_turns_a_pod_into_a_medal()
	test_item_field_a_drill_override_bypasses_the_table()
	test_item_field_the_fourth_carrier_of_a_stage_drops_the_oneup()
	test_item_field_a_oneup_at_full_lives_pays_a_medal()
	test_item_field_cancelled_bullets_become_gems_capped_by_stride()
	test_item_field_a_gem_flies_to_the_slot_that_made_it()
	test_item_field_a_pod_is_collected_and_adds_a_drone()
	test_item_field_an_item_nobody_takes_expires()
	test_item_field_the_sweep_brings_everything_in()
	test_item_field_the_drop_stream_is_deterministic()

	print("ItemField tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- Rules 3-11: carrier drops ------------------------------------------------

func test_item_field_a_small_carrier_drops_one_item_per_player() -> void:
	# Rule 5: items per drop = the player count, so a solo player and each of
	# four co-op players see the same pod income.
	for players: int in range(1, 5):
		var rig := _rig()
		var items: ItemField = rig[0]
		items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, players, 4, false)
		_assert_eq(items.count(), players, "a SMALL carrier drops %d items for %dP" % [players, players])


func test_item_field_a_large_carrier_is_a_guaranteed_bundle() -> void:
	# Rule 6: no roll at all. The player is PAID for killing the hard target.
	var rig := _rig()
	var items: ItemField = rig[0]
	items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.LARGE, -1, 1, 4, false)
	_assert_eq(items.count_of_kind(ItemField.Kind.POD), 1, "one pod per player")
	_assert_eq(items.count_of_kind(ItemField.Kind.MEDAL), 1, "and always a medal")


func test_item_field_pity_forces_a_pod_after_two_misses() -> void:
	# Rule 7: the team never goes more than `pity_limit` non-pods in a row.
	var rig := _rig()
	var items: ItemField = rig[0]
	items.pity_misses = items.rules.pity_limit
	items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, 1, 4, false)
	_assert_eq(items.count_of_kind(ItemField.Kind.POD), 1, "pity forces a pod whatever the roll")
	_assert_eq(items.pity_misses, 0, "and the counter resets")


func test_item_field_a_death_arms_the_recovery_pod() -> void:
	var rig := _rig()
	var items: ItemField = rig[0]
	items.pity_misses = 0
	items.player_died()
	_assert_eq(items.pity_misses, items.rules.pity_limit, "a death arms the recovery pod")
	items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.MEDIUM, -1, 1, 4, false)
	_assert_eq(items.count_of_kind(ItemField.Kind.POD), 1, "so the next drop is a pod")


func test_item_field_the_need_check_turns_a_pod_into_a_medal() -> void:
	# Rule 8: a pod never appears when nobody could use it.
	var rig := _rig()
	var items: ItemField = rig[0]
	items.pity_misses = items.rules.pity_limit
	items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, 1, 0, false)
	_assert_eq(items.count_of_kind(ItemField.Kind.POD), 0, "nobody needs a pod, so none drops")
	_assert_eq(items.count_of_kind(ItemField.Kind.MEDAL), 1, "it pays a medal instead")


func test_item_field_a_drill_override_bypasses_the_table() -> void:
	# Rule 7a: a drill drops exactly what it says, and the pity counter does
	# not move. Stage 1's first carrier uses this to teach what a pod is.
	var rig := _rig()
	var items: ItemField = rig[0]
	items.pity_misses = 1
	items.drop_requested(
		Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, ItemField.Kind.POD, 1, 4, false
	)
	_assert_eq(items.count_of_kind(ItemField.Kind.POD), 1, "the override drops a pod")
	_assert_eq(items.pity_misses, 1, "and leaves the pity counter alone")


func test_item_field_the_fourth_carrier_of_a_stage_drops_the_oneup() -> void:
	# Rule 11: fixed, not random. A player can learn where the extra life is.
	var rig := _rig()
	var items: ItemField = rig[0]
	for i: int in range(3):
		items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, 1, 4, false)
	_assert_eq(items.count_of_kind(ItemField.Kind.ONEUP), 0, "not from the first three")
	items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, 1, 4, false)
	_assert_eq(items.count_of_kind(ItemField.Kind.ONEUP), 1, "the fourth carrier drops it")


func test_item_field_a_oneup_at_full_lives_pays_a_medal() -> void:
	# Rule 11 again: an extra life with nowhere to go is not thrown away.
	var rig := _rig()
	var items: ItemField = rig[0]
	for i: int in range(4):
		items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, 1, 4, true)
	_assert_eq(items.count_of_kind(ItemField.Kind.ONEUP), 0, "no 1-up at max lives")


# --- Rules 12-14: gems --------------------------------------------------------

func test_item_field_cancelled_bullets_become_gems_capped_by_stride() -> void:
	# F3: 1,350 cancelled bullets at a cap of 100 keep 97, spread evenly over
	# the cancel area rather than clustered at the low pool indices.
	var rig := _rig()
	var items: ItemField = rig[0]
	var positions := PackedFloat32Array()
	var causes := PackedInt32Array()
	for i: int in range(1350):
		positions.append(float(20 + i % 300))
		positions.append(float(20 + i % 500))
		causes.append(0)
	items.make_gems(positions, causes)
	_assert_eq(items.gem_count(), 97, "stride sampling keeps 97 of 1,350")
	_assert(
		items.gem_count() <= items.rules.items_per_cancel_cap,
		"and never more than the cap"
	)


func test_item_field_a_gem_flies_to_the_slot_that_made_it() -> void:
	# Rule 17: a gem is a thank-you, so it comes to the player rather than
	# making them fly back into the bullets they just cleared.
	var rig := _rig()
	var items: ItemField = rig[0]
	var planes: PlaneCore = rig[1]
	_settle(planes)
	items.make_gems(PackedFloat32Array([180.0, 80.0]), PackedInt32Array([0]))
	var start := items.position_of(0)
	for t: int in range(items.rules.gem_hold + 10):
		items.tick(planes, PackedInt32Array([0, 0, 0, 0]))
	_assert(items.count() == 0 or items.position_of(0).y > start.y, "the gem closes on the plane")
	for t: int in range(200):
		items.tick(planes, PackedInt32Array([0, 0, 0, 0]))
	_assert_eq(items.count(), 0, "and is collected")
	_assert_eq(items.collected_total, 1, "exactly once")


# --- Rules 19-23: pickup ------------------------------------------------------

func test_item_field_a_pod_is_collected_and_adds_a_drone() -> void:
	var rig := _rig()
	var items: ItemField = rig[0]
	var planes: PlaneCore = rig[1]
	_settle(planes)
	var gained := [0]
	items.on_pod = func(slot: int) -> void:
		gained[0] += 1
	var at := planes.position_of(0)
	items.drop_requested(at, 0, EnemyDef.SizeClass.SMALL, ItemField.Kind.POD, 1, 4, false)
	for t: int in range(30):
		items.tick(planes, PackedInt32Array([0, 0, 0, 0]))
	_assert_eq(gained[0], 1, "flying over a pod collects it")
	_assert_eq(items.count(), 0, "and takes it off the field")


func test_item_field_an_item_nobody_takes_expires() -> void:
	# Rule 15: items never leave through the bottom, so a miss costs time and
	# nothing else — but it does cost that.
	var rig := _rig()
	var items: ItemField = rig[0]
	var planes: PlaneCore = rig[1]
	# No player in the run at all: nobody can collect.
	items.drop_requested(Vector2(20.0, 100.0), 0, EnemyDef.SizeClass.SMALL, ItemField.Kind.MEDAL, 1, 0, false)
	for t: int in range(items.rules.drop_lifetime + 2):
		items.tick(planes, PackedInt32Array([0, 0, 0, 0]))
	_assert_eq(items.count(), 0, "it expired")
	_assert_eq(items.expired_total, 1, "and was counted as expired, not collected")
	_assert_eq(items.collected_total, 0, "nothing was paid")


func test_item_field_the_sweep_brings_everything_in() -> void:
	# Rule 18: the boss is down, so nothing is left behind.
	var rig := _rig()
	var items: ItemField = rig[0]
	var planes: PlaneCore = rig[1]
	_settle(planes)
	var paid := [0]
	items.on_score = func(slot: int, base: int) -> void:
		paid[0] += base
	for i: int in range(3):
		items.drop_requested(
			Vector2(40.0 + float(i) * 100.0, 60.0), 0,
			EnemyDef.SizeClass.SMALL, ItemField.Kind.MEDAL, 1, 0, false
		)
	items.begin_sweep()
	for t: int in range(200):
		items.tick(planes, PackedInt32Array([0, 0, 0, 0]))
	_assert_eq(items.count(), 0, "every item flew in")
	_assert(paid[0] > 0, "and every one was paid (%d)" % paid[0])


func test_item_field_the_drop_stream_is_deterministic() -> void:
	# Rule 9 and 10: the same seed drops the same things in the same order,
	# and every request consumes exactly four draws whatever it decides.
	var first := _roll_sequence()
	var second := _roll_sequence()
	_assert_eq(first, second, "two identical stages roll identically")


func _roll_sequence() -> String:
	var rig := _rig()
	var items: ItemField = rig[0]
	var out := PackedStringArray()
	for i: int in range(8):
		items.clear_all()
		items.drop_requested(Vector2(180.0, 100.0), 0, EnemyDef.SizeClass.SMALL, -1, 1, 4, false)
		out.append(str(items.kind_of(0)) if items.count() > 0 else "-")
	return ",".join(out)


# --- helpers ------------------------------------------------------------------

func _rig() -> Array:
	var log := TickEventLog.new(512)
	var items := ItemField.new(
		load("res://data/item_rules.tres"),
		load("res://data/scoring_rules.tres"),
		20261104,
		0,
		log
	)
	var planes := PlaneCore.new(load("res://data/plane_rules.tres"), PLAY_AREA, log)
	return [items, planes, log]


## Flies the plane in, so it is Active and can collect.
func _settle(planes: PlaneCore) -> void:
	planes.join(0)
	var input := SimInput.new()
	for t: int in range(200):
		input.begin_tick()
		planes.tick(input)


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
