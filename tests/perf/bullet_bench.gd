extends SceneTree
## ADR-0001 Validation Criterion V1 — the benchmark that decides whether
## gameplay stays in GDScript or needs the C++ GDExtension fallback.
##
## Run headless from the project folder:
##   godot --headless --script res://tests/perf/bullet_bench.gd
##
## Accept thresholds (ADR-0001 "Budgets"):
##   bullet update, p99   <= 1.5 ms to ACCEPT   (2.5 ms hard ceiling)
##   MultiMesh pack       <= 1.0 ms per render frame
##
## Exit code 0 = ADR-0001 V1 passes on this machine, 1 = it does not.
##
## This measures the machine it runs on. ADR-0001 accepts on REF-WEB, which is
## slower than a desktop; a desktop pass is necessary, not sufficient.

const RULES_PATH := "res://data/bullet_rules.tres"
const PLAY_AREA := Rect2(0, 0, 360, 640)
const WARMUP_TICKS := 60
const MEASURED_TICKS := 600
const TARGET_SLOTS := 4

var _failures := 0
var _skipped := 0


func _init() -> void:
	print("=".repeat(68))
	print("ADR-0001 V1 — bullet benchmark")
	print("Godot %s | %s" % [
		Engine.get_version_info().string,
		OS.get_name(),
	])
	print("=".repeat(68))

	var rules: BulletRules = load(RULES_PATH)
	if rules == null:
		print("FAIL: could not load %s" % RULES_PATH)
		quit(1)
		return

	test_bullet_renderer_buffer_layout_matches_adr_0001()
	var field := _build_saturated_field(rules)
	test_bullet_field_tick_at_cap_within_budget(field)
	test_bullet_renderer_pack_within_budget(rules, field)
	test_bullet_field_same_seed_produces_same_state_hash(rules)

	print("=".repeat(68))
	if _failures == 0 and _skipped == 0:
		print("RESULT: PASS — ADR-0001 V1 satisfied on this machine")
	elif _failures == 0:
		print("RESULT: PASS with %d check(s) SKIPPED — V1 not fully settled" % _skipped)
	else:
		print("RESULT: FAIL — %d criterion/criteria not met" % _failures)
	print("=".repeat(68))
	quit(1 if _failures > 0 else 0)


## Verification item 1 in the ADR: the MultiMesh buffer layout in 4.7, which
## the ADR itself marks UNVERIFIED.
func test_bullet_renderer_buffer_layout_matches_adr_0001() -> void:
	# Arrange / Act
	var problem := BulletRenderer.verify_buffer_layout()
	# Assert
	if problem.is_empty():
		print("[1] MultiMesh TRANSFORM_2D buffer layout ....... OK (16 floats/instance)")
	elif problem.begins_with("SKIP:"):
		print("[1] MultiMesh buffer layout ................... SKIPPED, STILL UNVERIFIED")
		print("      %s" % problem.trim_prefix("SKIP: "))
		print("      re-run without --headless to settle ADR-0001 verification item 1")
		_skipped += 1
	else:
		print("[1] MultiMesh buffer layout ................... MISMATCH: %s" % problem)
		_failures += 1


## Fills the pool to the cap with a realistic behaviour mix and keeps it there,
## so every measured tick does full work. Bullets are aimed to cross the play
## area rather than leave it immediately.
func _build_saturated_field(rules: BulletRules) -> BulletField:
	var field := BulletField.new(rules, PLAY_AREA, rules.enemy_cap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103

	field.set_targets(
		_floats([80.0, 180.0, 280.0, 180.0]),
		_floats([560.0, 580.0, 560.0, 600.0]),
		_floats([80.0, 180.0, 280.0, 180.0]),
		_floats([561.0, 581.0, 561.0, 601.0]),
		_floats([3.0, 3.0, 3.0, 3.0]),
		PackedInt32Array([1, 1, 1, 1]),
	)

	for i: int in range(rules.enemy_cap):
		_spawn_one(field, rng)
	print("[2] Pool saturated ............................ %d bullets, %d target slots" % [
		field.count(), TARGET_SLOTS,
	])
	return field


func _spawn_one(field: BulletField, rng: RandomNumberGenerator) -> void:
	# Spawn across the upper field, heading downward at a spread of angles, so
	# bullets stay on screen for many ticks and exercise the swept test.
	var x := rng.randf_range(10.0, PLAY_AREA.size.x - 10.0)
	var y := rng.randf_range(10.0, PLAY_AREA.size.y * 0.5)
	var angle := rng.randf_range(0.35 * PI, 0.65 * PI)
	var speed := rng.randf_range(90.0, 220.0)
	# Behaviour mix: mostly linear, as a real pattern set is.
	var roll := rng.randf()
	var beh := BulletField.Beh.LINEAR
	if roll > 0.85:
		beh = BulletField.Beh.CURVE
	elif roll > 0.70:
		beh = BulletField.Beh.ACCEL
	field.request_spawn(
		x, y, cos(angle) * speed, sin(angle) * speed, beh, rng.randi_range(0, 3)
	)


## The headline number: whole bullet update per tick at the cap.
func test_bullet_field_tick_at_cap_within_budget(field: BulletField) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731

	for _i: int in range(WARMUP_TICKS):
		_tick_and_refill(field, rng)

	var samples := PackedFloat64Array()
	samples.resize(MEASURED_TICKS)
	for i: int in range(MEASURED_TICKS):
		var start := Time.get_ticks_usec()
		field.tick()
		var elapsed := Time.get_ticks_usec() - start
		samples[i] = float(elapsed) / 1000.0
		# Refill outside the timed region so spawn cost is not double counted.
		_refill(field, rng)

	var stats := _summarise(samples)
	var p99: float = stats["p99"]
	print("[3] Bullet update per tick @ %d bullets" % field.count())
	print("      mean %.3f ms | median %.3f ms | p99 %.3f ms | max %.3f ms" % [
		stats["mean"], stats["median"], p99, stats["max"],
	])
	if p99 <= 1.5:
		print("      verdict: PASS (p99 %.3f ms <= 1.5 ms accept threshold)" % p99)
	elif p99 <= 2.5:
		print("      verdict: CONCERN (p99 %.3f ms over 1.5 ms accept, under 2.5 ms hard)" % p99)
		_failures += 1
	else:
		print("      verdict: FAIL (p99 %.3f ms over the 2.5 ms hard ceiling)" % p99)
		_failures += 1


func _tick_and_refill(field: BulletField, rng: RandomNumberGenerator) -> void:
	field.tick()
	_refill(field, rng)


func _refill(field: BulletField, rng: RandomNumberGenerator) -> void:
	var missing := field.capacity - field.count()
	for _i: int in range(missing):
		_spawn_one(field, rng)


## MultiMesh pack cost per render frame.
func test_bullet_renderer_pack_within_budget(rules: BulletRules, field: BulletField) -> void:
	var renderer := BulletRenderer.new()
	renderer.setup(
		rules.enemy_cap,
		7.0,
		PackedColorArray([
			Color(0.40, 0.85, 1.00),
			Color(0.60, 0.60, 1.00),
			Color(1.00, 0.60, 1.00),
			Color(0.30, 1.00, 0.85),
		]),
	)
	var buffer := PackedFloat32Array()
	buffer.resize(rules.enemy_cap * BulletRenderer.FLOATS_PER_INSTANCE)

	for _i: int in range(30):
		renderer.pack(field, buffer)

	var frames := 300
	var samples := PackedFloat64Array()
	samples.resize(frames)
	for i: int in range(frames):
		var start := Time.get_ticks_usec()
		renderer.pack(field, buffer)
		samples[i] = float(Time.get_ticks_usec() - start) / 1000.0

	var stats := _summarise(samples)
	var p99: float = stats["p99"]
	print("[4] MultiMesh pack per frame @ %d instances" % field.count())
	print("      mean %.3f ms | p99 %.3f ms | max %.3f ms" % [
		stats["mean"], p99, stats["max"],
	])
	if p99 <= 1.0:
		print("      verdict: PASS (p99 %.3f ms <= 1.0 ms budget)" % p99)
	else:
		print("      verdict: FAIL (p99 %.3f ms over the 1.0 ms budget)" % p99)
		_failures += 1
	renderer.free()


## ADR-0003 relies on the fixed-step sim being reproducible: same seed and the
## same tick count must give the same state hash.
func test_bullet_field_same_seed_produces_same_state_hash(rules: BulletRules) -> void:
	var a := _run_scripted(rules)
	var b := _run_scripted(rules)
	if a == b:
		print("[5] Determinism (same seed, 120 ticks) ........ OK (hash %d)" % a)
	else:
		print("[5] Determinism ............................... FAIL (%d vs %d)" % [a, b])
		_failures += 1


func _run_scripted(rules: BulletRules) -> int:
	var field := BulletField.new(rules, PLAY_AREA, rules.enemy_cap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	field.set_targets(
		_floats([180.0]), _floats([560.0]),
		_floats([180.0]), _floats([561.0]),
		_floats([3.0]), PackedInt32Array([1]),
	)
	for _t: int in range(120):
		for _i: int in range(8):
			_spawn_one(field, rng)
		field.tick()
	return field.state_hash()


func _floats(values: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for i: int in range(values.size()):
		out[i] = values[i]
	return out


func _summarise(samples: PackedFloat64Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v: float in sorted:
		total += v
	var p99_index := int(floor(float(n) * 0.99))
	if p99_index >= n:
		p99_index = n - 1
	return {
		"mean": total / float(n),
		"median": sorted[n / 2],
		"p99": sorted[p99_index],
		"max": sorted[n - 1],
	}
