extends SceneTree
## Pattern library performance (design/gdd/bullet-pattern-library.md AC-53,
## AC-54, AC-55; budget row in ADR-0001).
##
## Run headless from the project folder:
##   godot --headless --script res://tests/perf/pattern_bench.gd
##
## Budgets:
##   AC-53 pattern tick, p99    <= 0.2 ms   (mean <= 0.1 ms)
##   AC-54 pattern + bullets    <= 1.7 ms p99
##   AC-55 10 min of the bench  < 1 MB static growth, object count stable +/-5
##
## Exit code 0 = every budget met on this machine, 1 = not.
##
## This measures the machine it runs on. The ACs accept on REF-PC and REF-WEB;
## REF-WEB is slower than a desktop, so a desktop pass is necessary and not
## sufficient. AC-55's full ten minutes is run only with --soak, because it
## costs ten minutes; the short form still catches a per-volley allocation.

const PLAY_AREA := Rect2(0, 0, 360, 640)
## AC-53: 40 emitters and 120 runners covering all seven patterns.
const EMITTERS := 40
const RUNNERS_PER_EMITTER := 3
const WARMUP_TICKS := 300
const MEASURED_TICKS := 1800
## AC-55 short form. `--soak` raises it to ten minutes of ticks.
const ALLOC_TICKS := 6000
const SOAK_TICKS := 36000

var _failures := 0


func _init() -> void:
	print("=".repeat(68))
	print("Pattern library benchmark — AC-53, AC-54, AC-55")
	print("Godot %s | %s" % [Engine.get_version_info().string, OS.get_name()])
	print("=".repeat(68))

	var rules: PatternRules = load("res://data/pattern_rules.tres")
	var bullet_rules: BulletRules = load("res://data/bullet_rules.tres")
	if rules == null or bullet_rules == null:
		print("FAIL: could not load the rules resources")
		quit(1)
		return

	test_pattern_tick_within_budget(rules)
	test_pattern_tick_within_budget_at_the_f9_scene_budget(rules, bullet_rules)
	test_pattern_and_bullet_update_within_combined_budget(rules, bullet_rules)
	test_pattern_tick_allocates_nothing_per_volley(rules)

	print("=".repeat(68))
	print(
		"RESULT: %s" % ("PASS - every budget met on this machine" if _failures == 0
		else "FAIL - %d budget(s) missed" % _failures)
	)
	print("=".repeat(68))
	quit(1 if _failures > 0 else 0)


# --- AC-53 -------------------------------------------------------------------

func test_pattern_tick_within_budget(rules: PatternRules) -> void:
	var sink := CountingSink.new()
	var scene := _build_scene(rules, sink)
	var players := MovingPlayers.new()

	for t: int in range(WARMUP_TICKS):
		_step(scene, players, t)

	var samples := PackedFloat64Array()
	samples.resize(MEASURED_TICKS)
	for i: int in range(MEASURED_TICKS):
		var t := WARMUP_TICKS + i
		_place(scene, players, t)       # the owner's work, not the library's
		var start := Time.get_ticks_usec()
		scene.tick(t)
		samples[i] = float(Time.get_ticks_usec() - start) / 1000.0

	var stats := _summarise(samples)
	var p99: float = stats["p99"]
	var mean: float = stats["mean"]
	print("[1] Pattern tick @ %d emitters / %d runners" % [
		scene.emitters.size(), EMITTERS * RUNNERS_PER_EMITTER,
	])
	print("      requests %d | volleys %d | safety skips %d" % [
		sink.accepted, scene.total_volleys_fired, scene.total_spawn_safety_skips,
	])
	print("      mean %.4f ms | median %.4f ms | p99 %.4f ms | max %.4f ms" % [
		mean, stats["median"], p99, stats["max"],
	])
	if p99 <= 0.2 and mean <= 0.1:
		print("      verdict: PASS (p99 <= 0.2 ms, mean <= 0.1 ms)")
	else:
		print("      verdict: FAIL (budget p99 0.2 ms, mean 0.1 ms)")
		_failures += 1
	scene.dispose()


# --- AC-53, second rig -------------------------------------------------------

## The same measurement on content the design would actually pass.
##
## AC-53's rig (40 emitters x 3 boss runners, all armed on the same tick) asks
## for about twice the 1,700 live bullets F9 allows a scene, and fires every
## gun in phase. This rig instead adds emitters until F9's own scene budget is
## reached and arms them on staggered ticks, the way Enemy (10) does when an
## enemy enters the fire zone. It is reported alongside the AC so the gap
## between the two is visible rather than hidden in one verdict.
func test_pattern_tick_within_budget_at_the_f9_scene_budget(
	rules: PatternRules, bullet_rules: BulletRules
) -> void:
	var sink := CountingSink.new()
	var scene := PatternScene.new(rules, sink)
	scene.run_seed = 20261104
	var defs := _pattern_defs()
	var density := 0.0
	var runners := 0
	var i := 0
	while true:
		var d: PatternDef = defs[i % defs.size()]
		var cost := PatternMetrics.pattern_density(d, rules, bullet_rules, 1.0)
		if density + cost > rules.scene_density_budget:
			break
		density += cost
		runners += 1
		# Staggered arming: a gun joins the scene when its owner arrives.
		var kit: Array[PatternDef] = [d]
		scene.add_emitter(2000 + i, 0, kit, i * 7)
		i += 1
		if i > 400:
			break

	var players := MovingPlayers.new()
	for t: int in range(WARMUP_TICKS):
		_step(scene, players, t)

	var samples := PackedFloat64Array()
	samples.resize(MEASURED_TICKS)
	for k: int in range(MEASURED_TICKS):
		var t := WARMUP_TICKS + k
		_place(scene, players, t)
		var start := Time.get_ticks_usec()
		scene.tick(t)
		samples[k] = float(Time.get_ticks_usec() - start) / 1000.0

	var stats := _summarise(samples)
	var p99: float = stats["p99"]
	var mean: float = stats["mean"]
	print("[1b] Pattern tick at the F9 scene budget")
	print("      %d emitters / %d runners | F9 density %.0f of %.0f bullets" % [
		scene.emitters.size(), runners, density, rules.scene_density_budget,
	])
	print("      mean %.4f ms | median %.4f ms | p99 %.4f ms | max %.4f ms" % [
		mean, stats["median"], p99, stats["max"],
	])
	if p99 <= 0.2 and mean <= 0.1:
		print("      verdict: PASS (p99 <= 0.2 ms, mean <= 0.1 ms)")
	else:
		print("      verdict: FAIL (budget p99 0.2 ms, mean 0.1 ms)")
		_failures += 1
	scene.dispose()


# --- AC-54 -------------------------------------------------------------------

func test_pattern_and_bullet_update_within_combined_budget(
	rules: PatternRules, bullet_rules: BulletRules
) -> void:
	var field := BulletField.new(bullet_rules, PLAY_AREA, bullet_rules.enemy_cap)
	var scene := _build_scene(rules, field)
	var players := MovingPlayers.new()
	var peak_requests := 0

	for t: int in range(WARMUP_TICKS):
		_step_with_field(scene, field, players, t)

	var samples := PackedFloat64Array()
	samples.resize(MEASURED_TICKS)
	var peak_bullets := 0
	for i: int in range(MEASURED_TICKS):
		var t := WARMUP_TICKS + i
		_place(scene, players, t)
		var before := field.count()
		var start := Time.get_ticks_usec()
		scene.tick(t)
		field.set_targets(
			players.xs, players.ys, players.prev_xs, players.prev_ys,
			players.radii, players.hittable, players.alive
		)
		field.tick()
		samples[i] = float(Time.get_ticks_usec() - start) / 1000.0
		peak_bullets = maxi(peak_bullets, field.count())
		peak_requests = maxi(peak_requests, maxi(0, field.count() - before))

	var stats := _summarise(samples)
	var p99: float = stats["p99"]
	print("[2] Pattern tick + bullet update")
	print("      peak %d bullets | peak %d requests in a tick | %d refused" % [
		peak_bullets, peak_requests, field.spawn_rejected,
	])
	print("      mean %.4f ms | median %.4f ms | p99 %.4f ms | max %.4f ms" % [
		stats["mean"], stats["median"], p99, stats["max"],
	])
	if p99 <= 1.7:
		print("      verdict: PASS (p99 %.4f ms <= 1.7 ms)" % p99)
	else:
		print("      verdict: FAIL (p99 %.4f ms over 1.7 ms)" % p99)
		_failures += 1
	scene.dispose()


# --- AC-55 -------------------------------------------------------------------

func test_pattern_tick_allocates_nothing_per_volley(rules: PatternRules) -> void:
	var soak := OS.get_cmdline_user_args().has("--soak")
	var ticks := SOAK_TICKS if soak else ALLOC_TICKS
	var sink := CountingSink.new()
	var scene := _build_scene(rules, sink)
	var players := MovingPlayers.new()

	for t: int in range(WARMUP_TICKS):
		_step(scene, players, t)

	var mem_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i: int in range(ticks):
		_step(scene, players, WARMUP_TICKS + i)
	var grew_kb := (Performance.get_monitor(Performance.MEMORY_STATIC) - mem_before) / 1024.0
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT) - objects_before)

	print("[3] Allocation over %d ticks%s" % [ticks, " (soak)" if soak else ""])
	print("      %d volleys | static memory %+.1f KiB | objects %+d" % [
		scene.total_volleys_fired, grew_kb, objects,
	])
	if absf(grew_kb) < 1024.0 and absi(objects) <= 5:
		print("      verdict: PASS (< 1 MiB growth, object count stable)")
	else:
		print("      verdict: FAIL (budget < 1 MiB growth and +/-5 objects)")
		_failures += 1
	if not soak:
		print("      note: AC-55's full ten minutes needs `-- --soak`")
	scene.dispose()


# --- rig ---------------------------------------------------------------------

## Counts requests without simulating them (AC-53's "counting sink"), so the
## measured time is the library's and nothing else.
class CountingSink extends RefCounted:
	var accepted := 0

	func request_spawn(
		_x: float, _y: float, _vx: float, _vy: float,
		_beh: int = 0, _shape: int = 0, _param: float = 0.0, _slot: int = 0
	) -> bool:
		accepted += 1
		return true


## Four players weaving across the lower field, so aim, targeting and spawn
## safety all do real work every tick.
class MovingPlayers extends RefCounted:
	var xs := PackedFloat32Array([80.0, 180.0, 280.0, 180.0])
	var ys := PackedFloat32Array([520.0, 560.0, 520.0, 600.0])
	var prev_xs := PackedFloat32Array([80.0, 180.0, 280.0, 180.0])
	var prev_ys := PackedFloat32Array([520.0, 560.0, 520.0, 600.0])
	var radii := PackedFloat32Array([3.0, 3.0, 3.0, 3.0])
	var alive := PackedInt32Array([1, 1, 1, 1])
	var hittable := PackedInt32Array([1, 1, 1, 1])

	func place(t: int) -> void:
		for s: int in range(4):
			prev_xs[s] = xs[s]
			prev_ys[s] = ys[s]
			var phase := (t * (s + 2)) % 480
			var up := float(phase if phase < 240 else 480 - phase) / 240.0
			xs[s] = 30.0 + 300.0 * up
			ys[s] = 440.0 + 40.0 * float(s)


## 40 emitters, three runners each, covering all seven patterns.
## Every authored pattern, so a rig covers all seven kinds.
func _pattern_defs() -> Array[PatternDef]:
	var names := [
		"fortress_core_spiral", "fortress_core_rage_ring", "fortress_turret_fan",
		"fortress_engine_ring", "jet_core_accel_fan", "jet_pod_stream", "jet_wing_wall",
		"plasma_core_shielded_warp_ring", "plasma_core_exposed_warp_ring",
		"plasma_core_exposed_fan", "plasma_shield_curve", "wave_1941_aimed_fan",
		"wave_1941_flak", "wave_1941_wall", "wave_1941_spray", "wave_1970s_locked_fan",
	]
	var out: Array[PatternDef] = []
	for name: String in names:
		out.push_back(load("res://data/patterns/%s.tres" % name) as PatternDef)
	return out


func _build_scene(rules: PatternRules, field) -> PatternScene:
	var scene := PatternScene.new(rules, field)
	scene.run_seed = 20261104
	var defs := _pattern_defs()
	for i: int in range(EMITTERS):
		var kit: Array[PatternDef] = []
		for k: int in range(RUNNERS_PER_EMITTER):
			kit.push_back(defs[(i * RUNNERS_PER_EMITTER + k) % defs.size()])
		scene.add_emitter(1000 + i, 0, kit, 0)
	return scene


## The owner's per-tick work: move the players, then move every emitter. Kept
## out of the timed region, because it belongs to Enemy (10) and Boss (14).
func _place(scene: PatternScene, players: MovingPlayers, t: int) -> void:
	players.place(t)
	scene.set_slots(players.xs, players.ys, players.alive, players.hittable)
	var intensity := clampf(float(t % 1800) / 1500.0, 0.0, 1.0)
	for i: int in range(scene.emitters.size()):
		var e := scene.emitters[i]
		var phase := (t + i * 13) % 300
		var up := float(phase if phase < 150 else 300 - phase) / 150.0
		var centre := Vector2(40.0 + 280.0 * up, 60.0 + 4.0 * float(i % 10))
		e.update(centre, centre, intensity)


func _step(scene: PatternScene, players: MovingPlayers, t: int) -> void:
	_place(scene, players, t)
	scene.tick(t)


func _step_with_field(
	scene: PatternScene, field: BulletField, players: MovingPlayers, t: int
) -> void:
	_place(scene, players, t)
	scene.tick(t)
	field.set_targets(
		players.xs, players.ys, players.prev_xs, players.prev_ys,
		players.radii, players.hittable, players.alive
	)
	field.tick()


func _summarise(samples: PackedFloat64Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v: float in sorted:
		total += v
	var p99_index := mini(int(floor(float(n) * 0.99)), n - 1)
	return {
		"mean": total / float(n),
		"median": sorted[n / 2],
		"p99": sorted[p99_index],
		"max": sorted[n - 1],
	}
