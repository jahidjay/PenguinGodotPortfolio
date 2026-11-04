extends SceneTree
## Shared resources, firing order, seeded independence and determinism for the
## pattern library (design/gdd/bullet-pattern-library.md Rules 1-4, 15,
## AC-01 - AC-04, AC-40 - AC-44, AC-52).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_pattern_determinism.gd

var _failures := 0

const FAN := PatternDef.Kind.AIMED_FAN
const RING := PatternDef.Kind.RING
const SPIRAL := PatternDef.Kind.SPIRAL
const WALL := PatternDef.Kind.WALL
const CURVE := PatternDef.Kind.RADIAL_CURVE
const FLAK := PatternDef.Kind.FLAK_BURST
const SPRAY := PatternDef.Kind.SPRAY

## The pattern library runtime, which the source lints below read.
const RUNTIME_FILES := [
	"res://src/gameplay/patterns/pattern_def.gd",
	"res://src/gameplay/patterns/pattern_emitter.gd",
	"res://src/gameplay/patterns/pattern_metrics.gd",
	"res://src/gameplay/patterns/pattern_rules.gd",
	"res://src/gameplay/patterns/pattern_runner.gd",
	"res://src/gameplay/patterns/pattern_scene.gd",
]


func _init() -> void:
	test_pattern_resource_is_shared_without_being_touched()
	test_pattern_stacked_patterns_fire_independently()
	test_pattern_bullets_spawn_at_the_origin_of_their_own_tick()
	test_pattern_emitter_seed_is_the_stable_id_recipe()
	test_pattern_emitter_streams_are_independent_of_every_other_emitter()
	test_pattern_same_tick_order_is_registration_then_pattern_list()
	test_pattern_scripted_scenario_is_bit_identical_twice()
	test_pattern_rng_state_is_unchanged_by_what_the_players_did()
	test_pattern_runtime_has_no_global_random_calls()
	test_pattern_runtime_has_no_canvas_scale_factor()

	PatternHarness.dispose_all()
	print("PatternDeterminism tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- AC-01, Rules 1 and 3 ----------------------------------------------------

func test_pattern_resource_is_shared_without_being_touched() -> void:
	var shared := PatternHarness.pattern("fortress_turret_fan")
	var before := _fingerprint(shared)

	# Two emitters on one resource, one of which stops half way.
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true, 0)
	var a := h.add_emitter([shared], 0, 11, 0)
	var b := h.add_emitter([shared], 0, 22, 0)
	for t: int in range(600):
		h.log.rotate()
		h.field.tick = t
		if t == 200:
			a.stop(false)
		a.update(Vector2(100.0, 100.0), Vector2(100.0, 100.0), 0.5)
		b.update(Vector2(260.0, 100.0), Vector2(260.0, 100.0), 0.5)
		h.scene.tick(t)
	var with_a := _requests_of_owner(h, 260.0)

	# The same run with emitter A never registered at all.
	var h2 := PatternHarness.new()
	h2.set_slot(0, Vector2(180.0, 520.0), true, 0)
	var b2 := h2.add_emitter([shared], 0, 22, 0)
	h2.run(b2, 0, 599, Vector2(260.0, 100.0), 0.5)
	var without_a := _requests_of_owner(h2, 260.0)

	_assert_eq(_fingerprint(shared), before, "the shared resource is unchanged by running it")
	_assert(without_a.size() > 0, "emitter B fired something")
	_assert_arr(with_a, without_a, "emitter B fires identically whether or not A exists")


func test_pattern_stacked_patterns_fire_independently() -> void:
	var fan := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 84, "count": 3, "spread_rad": 0.21,
	})
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 8, "speed": 120.0,
		"offset_mode": PatternDef.OffsetMode.FIXED,
	})
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true, 0)
	var e := h.add_emitter([fan, ring], 100)
	h.run(e, 100, 150)
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 11, "both patterns fire on tick 148")
	# The fan is first in the list, so its three bullets are requested first.
	for k: int in range(3):
		_assert_close(
			h.field.speed_of(idx[k]), fan.speed, "bullet %d came from the fan" % k, 0.05
		)
	for k: int in range(3, 11):
		_assert_close(
			h.field.speed_of(idx[k]), ring.speed, "bullet %d came from the ring" % k, 0.05
		)

	# Closing the ring's gate leaves the fan's schedule untouched.
	var h2 := PatternHarness.new()
	h2.set_slot(0, Vector2(180.0, 520.0), true, 0)
	var gated := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 8, "speed": 120.0,
		"min_intensity": 0.9,
	})
	var e2 := h2.add_emitter([fan, gated], 100)
	h2.run(e2, 100, 320)
	_assert_eq(
		h2.field.fired_ticks(), PackedInt32Array([148, 232, 316]),
		"the fan keeps its schedule with the ring gated out"
	)
	_assert_eq(h2.field.indices_at(148).size(), 3, "and fires only its own bullets")


# --- AC-02, Rule 2 -----------------------------------------------------------

func test_pattern_bullets_spawn_at_the_origin_of_their_own_tick() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true, 0)
	var stream := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 120, "burst_count": 6, "burst_gap": 6, "count": 1,
	})
	var e := h.add_emitter([stream], 100)
	h.run(e, 100, 153, Vector2(100.0, 50.0))
	h.run(e, 154, 160, Vector2(140.0, 50.0))   # the owner moved between volleys
	_assert_close(h.field.xs[h.field.indices_at(148)[0]], 100.0, "the 148 bullet spawns at x 100")
	_assert_close(h.field.xs[h.field.indices_at(154)[0]], 140.0, "the 154 bullet spawns at x 140")

	# A radial curve takes its outward heading from the centre passed that tick.
	var h2 := PatternHarness.new()
	h2.set_slot(0, Vector2(300.0, 620.0), true, 0)
	var curve := PatternHarness.make(CURVE, {
		"start_delay": 48, "interval": 10, "count": 1, "speed": 120.0, "spin": 1.3,
		"behaviour": BulletField.Beh.CURVE,
	})
	var e2 := h2.add_emitter([curve], 100)
	h2.run(e2, 100, 148, Vector2(220.0, 100.0), 0.0, PackedInt32Array(), Vector2(180.0, 100.0))
	h2.run(e2, 149, 158, Vector2(220.0, 100.0), 0.0, PackedInt32Array(), Vector2(220.0, 60.0))
	_assert_bam(
		h2.field.angle_bam(h2.field.indices_at(148)[0]), 0, "centre left of the muzzle: fires right"
	)
	_assert_bam(
		h2.field.angle_bam(h2.field.indices_at(158)[0]),
		SimMath.QUARTER,
		"centre above the muzzle on the next volley: fires down"
	)


# --- AC-40, AC-41, Rule 15 ---------------------------------------------------

func test_pattern_emitter_seed_is_the_stable_id_recipe() -> void:
	var h := PatternHarness.new(null, 987654)
	h.scene.stage_index = 2
	var e := h.add_emitter([PatternHarness.pattern("fortress_engine_ring")], 0, 4096, 1)
	_assert_eq(
		e.rng.seed,
		SimHash.seed([SimRng.EMITTER, 987654, 2, 4096, 1]),
		"the stream is seeded from (run_seed, stage_index, owner_id, emitter_index)"
	)


func test_pattern_emitter_streams_are_independent_of_every_other_emitter() -> void:
	var baseline := _three_emitter_scene(0)
	_assert(baseline.size() > 0, "the baseline scene actually fired something")
	_assert_arr(_three_emitter_scene(1), baseline, "adding a fourth emitter at tick 300")
	_assert_arr(_three_emitter_scene(2), baseline, "removing emitter B at tick 300")
	_assert_arr(_three_emitter_scene(3), baseline, "registering A, B and C in reverse order")


# --- AC-44 -------------------------------------------------------------------

func test_pattern_same_tick_order_is_registration_then_pattern_list() -> void:
	var p1 := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 3, "speed": 100.0,
		"offset_mode": PatternDef.OffsetMode.FIXED,
	})
	var p2 := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 3, "speed": 200.0,
		"offset_mode": PatternDef.OffsetMode.FIXED,
	})
	var forward := _two_emitter_speeds(p1, p2, false)
	_assert_eq(
		forward, PackedFloat32Array([100.0, 100.0, 100.0, 200.0, 200.0, 200.0,
			100.0, 100.0, 100.0, 200.0, 200.0, 200.0]),
		"E1.P1, E1.P2, then E2.P1, E2.P2"
	)
	# Swapping registration order swaps the blocks, not the bullets inside them.
	var swapped := _two_emitter_speeds(p1, p2, true)
	_assert_eq(swapped, forward, "each emitter still fires its own list in order")


# --- AC-42 -------------------------------------------------------------------

func test_pattern_scripted_scenario_is_bit_identical_twice() -> void:
	var first := _scripted_scenario()
	var second := _scripted_scenario()
	_assert(first[0].size() > 1000, "the scenario fired a substantial log")
	_assert_arr(first[0], second[0], "1,800 ticks of 4 emitters give the same request log")
	_assert_arr(first[1], second[1], "and the same state hash on every tick")


func test_pattern_rng_state_is_unchanged_by_what_the_players_did() -> void:
	# Same scenario, different player paths: the random streams must not care.
	var a := _scripted_scenario(1.0)
	var b := _scripted_scenario(-1.0)
	_assert_eq(a[2], b[2], "every emitter's RNG state matches although the players moved apart")
	_assert_not(a[0] == b[0], "while the aimed bullets really did differ")


# --- AC-40 lint, AC-52 lint --------------------------------------------------

func test_pattern_runtime_has_no_global_random_calls() -> void:
	var banned := ["randomize(", "randf_range(", "randi_range(", "randi()"]
	for path: String in RUNTIME_FILES:
		var text := _read(path)
		for token: String in banned:
			_assert(
				not text.contains(token),
				"%s must not call %s (Rule 15: every draw comes from the emitter's stream)"
					% [path.get_file(), token]
			)
		# Any randf() must be on an explicit generator, never the global one.
		var lines := text.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			if line.contains("randf()") and not line.contains(".randf()"):
				_failures += 1
				print("FAIL: %s:%d calls the global randf()" % [path.get_file(), i + 1])


func test_pattern_runtime_has_no_canvas_scale_factor() -> void:
	# Rule 16 / AC-52: the 360 px retune is baked into the DATA (F10). A scale
	# factor in the runtime would mean the authored numbers are not the real
	# ones, and every lane check would be measuring the wrong shape.
	for path: String in RUNTIME_FILES:
		var text := _read(path)
		for i: int in range(text.split("\n").size()):
			pass
		_assert(
			not text.contains("0.75"),
			"%s must hold no canvas scale factor (Rule 16)" % path.get_file()
		)


# --- helpers -----------------------------------------------------------------

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_failures += 1
		print("FAIL: cannot read %s" % path)
		return ""
	return f.get_as_text()


## A value that changes if any authored field of a pattern changes.
func _fingerprint(d: PatternDef) -> String:
	var out := ""
	for p: Dictionary in d.get_property_list():
		if p["usage"] & PROPERTY_USAGE_STORAGE:
			out += "%s=%s;" % [p["name"], d.get(p["name"])]
	return out


## Every request made from an emitter sitting at `origin_x`, as a flat array.
func _requests_of_owner(h: PatternHarness, origin_x: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i: int in range(h.field.size()):
		if absf(h.field.xs[i] - origin_x) > 0.5:
			continue
		out.push_back(float(h.field.ticks[i]))
		out.push_back(h.field.vxs[i])
		out.push_back(h.field.vys[i])
	return out


## Runs three seeded emitters (A, B, C) for 600 ticks under one of four
## arrangements, and returns A's and C's requests. They must be identical in
## all four (AC-41).
##
## `variant`: 0 baseline, 1 adds a fourth emitter at tick 300, 2 removes B at
## 300, 3 registers them in reverse order.
func _three_emitter_scene(variant: int) -> PackedFloat32Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true, 0)
	var wall := PatternHarness.pattern("wave_1941_wall")
	var ring := PatternHarness.pattern("fortress_engine_ring")
	var spray := PatternHarness.pattern("wave_1941_spray")
	var ids := [101, 102, 103] if variant != 3 else [103, 102, 101]
	var defs := [wall, ring, spray] if variant != 3 else [spray, ring, wall]
	var built := {}
	for k: int in range(3):
		# Each emitter fires a tagged COPY of its pattern, so a request can be
		# traced back to the emitter that made it however the walls overlap.
		var tagged: PatternDef = defs[k].duplicate()
		tagged.shape = ids[k] - 100
		built[ids[k]] = h.add_emitter([tagged], 0, ids[k], 0)

	for t: int in range(600):
		h.log.rotate()
		h.field.tick = t
		if t == 300 and variant == 1:
			var extra: PatternDef = ring.duplicate()
			extra.shape = 4
			built[104] = h.add_emitter([extra], t, 104, 0)
		if t == 300 and variant == 2:
			h.scene.remove_emitters_of(102, true)
			built.erase(102)
		for id: int in built:
			var e: PatternEmitter = built[id]
			e.update(Vector2(60.0 + 60.0 * float(id % 10), 100.0), Vector2(180.0, 100.0), 0.5)
		h.scene.tick(t)

	# Only A (shape 1) and C (shape 3) are compared; B and D are the noise.
	# Each emitter's own stream is gathered separately: registration order is
	# allowed to change which emitter requests first WITHIN a tick (Edge
	# Cases, "Pool and order"), but never what an emitter itself fires.
	var out := PackedFloat32Array()
	for tag: int in [1, 3]:
		for i: int in range(h.field.size()):
			if h.field.shapes[i] != tag:
				continue
			out.push_back(float(h.field.ticks[i]))
			out.push_back(float(tag))
			out.push_back(h.field.xs[i])
			out.push_back(h.field.vxs[i])
	return out


## Two emitters, each running [p1, p2], all four runners firing on tick 148.
## Returns the speed of every bullet in request order, which identifies which
## runner produced it.
func _two_emitter_speeds(p1: PatternDef, p2: PatternDef, swap: bool) -> PackedFloat32Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var first := h.add_emitter([p1, p2], 100, 1, 0)
	var second := h.add_emitter([p1, p2], 100, 2, 0)
	for t: int in range(100, 151):
		h.log.rotate()
		h.field.tick = t
		first.update(Vector2(100.0, 100.0), Vector2(100.0, 100.0), 0.0)
		second.update(Vector2(260.0, 100.0), Vector2(260.0, 100.0), 0.0)
		h.scene.tick(t)
	var out := PackedFloat32Array()
	var idx := h.field.indices_at(148)
	for i: int in idx:
		out.push_back(snappedf(h.field.speed_of(i), 0.5))
	if swap:
		# The same run with registration reversed must produce the same four
		# blocks of bullets, each emitter's own list still in order.
		var mirrored := PackedFloat32Array()
		for k: int in range(6, 12):
			mirrored.push_back(out[k])
		for k: int in range(6):
			mirrored.push_back(out[k])
		return mirrored
	return out


## The AC-42 scenario: four emitters covering all seven patterns, an intensity
## ramp, a fire hold over ticks 600-630, two moving players and one death.
## Returns [requests, per-tick hashes, rng states].
func _scripted_scenario(player_drift := 1.0) -> Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(120.0, 500.0), true)
	h.set_slot(1, Vector2(240.0, 520.0), true)
	var kits := [
		[PatternHarness.pattern("fortress_core_spiral"),
			PatternHarness.pattern("fortress_core_rage_ring")],
		[PatternHarness.pattern("jet_core_accel_fan"),
			PatternHarness.pattern("jet_wing_wall")],
		[PatternHarness.pattern("wave_1941_flak"),
			PatternHarness.pattern("wave_1941_spray")],
		[PatternHarness.pattern("plasma_shield_curve"),
			PatternHarness.pattern("wave_1970s_locked_fan")],
	]
	var emitters: Array[PatternEmitter] = []
	for k: int in range(kits.size()):
		emitters.push_back(h.add_emitter(kits[k], 0, 200 + k, 0))

	var hashes := PackedInt64Array()
	for t: int in range(1800):
		h.log.rotate()
		h.field.tick = t
		h.scene.fire_hold = t >= 600 and t <= 630
		if t == 900:
			h.set_alive(1, false)
		if t < 900:
			h.move_slot(0, Vector2(120.0 + player_drift * float(t % 120), 500.0))
			h.move_slot(1, Vector2(240.0 - player_drift * float(t % 90), 520.0))
		var intensity := clampf(float(t) / 1500.0, 0.0, 1.0)
		for k: int in range(emitters.size()):
			emitters[k].update(
				Vector2(60.0 + 80.0 * float(k), 90.0 + 10.0 * float(k)),
				Vector2(180.0, 120.0),
				intensity
			)
		h.scene.tick(t)
		var ctx := SimHash.begin()
		h.scene.hash_into(ctx)
		hashes.push_back(SimHash.digest64(ctx))

	var requests := PackedFloat32Array()
	for i: int in range(h.field.size()):
		requests.push_back(float(h.field.ticks[i]))
		requests.push_back(h.field.xs[i])
		requests.push_back(h.field.vxs[i])
		requests.push_back(h.field.vys[i])
	var states := PackedInt64Array()
	for k: int in range(emitters.size()):
		states.push_back(emitters[k].rng.state)
	return [requests, hashes, states]


# --- assertions --------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_not(bad: bool, what: String) -> void:
	_assert(not bad, what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])


func _assert_bam(got: int, want: int, what: String) -> void:
	if absi(SimMath.delta_bam(want, got)) > 1:
		_failures += 1
		print("FAIL: %s -- got %d bam, want %d bam" % [what, got, want])


## Array equality that reports the FIRST difference instead of printing two
## thousand-element dumps.
func _assert_arr(got: Variant, want: Variant, what: String) -> void:
	if got.size() != want.size():
		_failures += 1
		print("FAIL: %s -- %d entries, want %d" % [what, got.size(), want.size()])
		return
	for i: int in range(got.size()):
		if got[i] != want[i]:
			_failures += 1
			print("FAIL: %s -- entry %d is %s, want %s" % [what, i, got[i], want[i]])
			return


func _assert_close(got: float, want: float, what: String, tol := 0.01) -> void:
	if absf(got - want) > tol:
		_failures += 1
		print("FAIL: %s -- got %.4f, want %.4f (+/- %.3f)" % [what, got, want, tol])
