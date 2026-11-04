class_name PatternMetrics
extends Object
## The pattern library's formulas as PURE functions
## (design/gdd/bullet-pattern-library.md F1, F3, F8, F9).
##
## They live here, not inside [PatternRunner], for two reasons the GDD is
## explicit about:
##
## 1. The runner and the fairness validator must agree. If the validator
##    reimplemented `interval_eff`, a pattern could pass authoring checks and
##    then behave differently in the game.
## 2. Boss power budget (15) calls `PatternMetrics` for its power score and
##    lints "rather than copying them" (F9 note, 2026-11-03).
##
## [method validate] is the F8 fairness validator: authoring checks only. It
## NEVER clamps anything at runtime — the runtime clamps are listed in F8's
## "Runtime does only these" and live in the runner.
##
## Usage:
## [codeblock]
## var problems := PatternMetrics.validate(pattern, rules, bullet_rules)
## for p: String in problems:
##     if p.begins_with("ERROR"):
##         push_error(p)
## [/codeblock]

## Guards float equality at a gate bound, so 3 parts of 3 destroyed really
## does read as intensity 1.0 (F3).
const GATE_EPSILON := 1.0e-6

const TICKS_PER_SECOND := 60.0


# --- F1: field minimums ------------------------------------------------------

## F1 conversion, used only by the one-time seconds-to-ticks migration (F10).
## New patterns are authored directly in ticks.
static func seconds_to_ticks(sec: float, min_t: int) -> int:
	return maxi(min_t, roundi(sec * TICKS_PER_SECOND))


## F1 field minimums, applied at load and again at runtime so a value changed
## after load cannot break the schedule. `lock_ticks` is NOT clamped: 0 is
## valid and means "no lock".
static func clamp_interval(v: int) -> int:
	return maxi(1, v)


static func clamp_burst_count(v: int) -> int:
	return maxi(1, v)


static func clamp_start_delay(v: int) -> int:
	return maxi(1, v)


static func clamp_flak_delay(v: int) -> int:
	return maxi(1, v)


# --- F3: intensity -----------------------------------------------------------

## F3: is the gate open at intensity `i`? Inclusive at both ends, with an
## epsilon so a bound reached by exact division still counts.
static func gate_open(def: PatternDef, i: float) -> bool:
	var clamped := clampf(i, 0.0, 1.0)
	return (
		clamped >= def.min_intensity - GATE_EPSILON
		and clamped <= def.max_intensity + GATE_EPSILON
	)


## F3: `interval_eff = max(1, roundi(lerp(interval, interval_full, I)))`.
## A negative `interval_at_full` means no scaling.
static func interval_eff(def: PatternDef, i: float) -> int:
	var base := clamp_interval(def.interval)
	if def.interval_at_full < 0:
		return base
	var full := clamp_interval(def.interval_at_full)
	var clamped := clampf(i, 0.0, 1.0)
	return maxi(1, roundi(lerpf(float(base), float(full), clamped)))


## F3: `count_eff = max(1, roundi(lerp(count, count_full, I)))`.
## A negative `count_at_full` means no scaling.
static func count_eff(def: PatternDef, i: float) -> int:
	var base := maxi(1, def.count)
	if def.count_at_full < 0:
		return base
	var full := maxi(1, def.count_at_full)
	var clamped := clampf(i, 0.0, 1.0)
	return maxi(1, roundi(lerpf(float(base), float(full), clamped)))


## F2 runtime fallback: a burst must never lose a volley, so an interval
## shorter than the burst it contains is pushed later instead.
static func interval_with_overlap_fallback(def: PatternDef, scaled: int) -> int:
	var span := (clamp_burst_count(def.burst_count) - 1) * clamp_interval(def.burst_gap) + 1
	return maxi(scaled, span)


# --- F6: geometry ------------------------------------------------------------
#
# These are the shapes themselves, as pure functions of integer angles and the
# random draw `u`. They live here for the same reason the timing formulas do:
# the runner, the validator and the tests must all agree on one copy. A second
# copy inside the runner is how a pattern starts behaving differently from the
# shape it was authored and checked as.
#
# Angles are binary angle units (ADR-0003 D3), so every one of these is exact
# integer arithmetic and wraps without error.

## F6a: the i-th bullet of an aimed fan, `spread_bam` apart, centred on the aim.
static func fan_angle_bam(i: int, count: int, aim_bam: int, spread_bam: int) -> int:
	if count <= 1:
		return aim_bam  # Edge Cases: count 1 fires one aimed bullet, spread ignored
	# The doubled offset is halved with truncating division, so +k and -k stay
	# mirror images of each other however the division rounds.
	return aim_bam + ((2 * i - (count - 1)) * spread_bam) / 2


## F6b: the angle between neighbouring ring bullets.
static func ring_step_bam(count: int) -> int:
	return SimMath.TURN / maxi(1, count)


## F6b: a seeded ring rotation, `u * step`. Never more than ONE gap, so the
## lanes a player learned stay where they were.
static func ring_offset_bam(u: float, count: int) -> int:
	return int(u * float(ring_step_bam(count)))


## F6b: the i-th bullet of a ring. `(i * TURN) / n` rather than
## `i * (TURN / n)`: the division happens once, on the exact product, so the
## rounding error never accumulates round the ring.
static func ring_angle_bam(i: int, count: int, offset_bam: int) -> int:
	return offset_bam + (i * SimMath.TURN) / maxi(1, count)


## F6c: the `arm`-th bullet of spiral volley `counter`. The angle comes from
## the integer volley counter, so a spiral cannot drift however long it runs.
static func spiral_angle_bam(
	angle_offset_bam: int, counter: int, step_bam: int, arm: int, arms: int
) -> int:
	var n := maxi(1, arms)
	return (angle_offset_bam + counter * step_bam + (arm * SimMath.TURN) / n) & SimMath.MASK


## F6d: the x of wall slot `i`, centred on the emitter.
static func wall_slot_x(i: int, count: int, origin_x: float, spacing: float) -> float:
	return origin_x + (float(i) - float(count - 1) * 0.5) * spacing


## F6d: which valid gap start the draw `u` picks. -1 when nothing is valid, so
## the caller applies the "nearest the middle" fallback.
static func wall_gap_choice(u: float, valid: PackedInt32Array) -> int:
	var n := valid.size()
	if n == 0:
		return -1
	return valid[mini(int(u * float(n)), n - 1)]


## F6g: the i-th spray angle. Each bullet owns a slot of the arc and may
## wander `jitter` of it, so with jitter below 1 two bullets can never meet and
## a lane always stays open.
static func spray_angle_bam(
	i: int, count: int, u: float, arc_bam: int, base_bam: int, jitter: float
) -> int:
	var n := maxi(1, count)
	var slot_width := float(arc_bam) / float(n)
	return base_bam + int((float(i) + 0.5 + (u - 0.5) * jitter) * slot_width)


## F6g: the i-th spray speed, drawn after its angle.
static func spray_speed(u: float, speed_min: float, speed_max: float) -> float:
	return speed_min + u * (speed_max - speed_min)


# --- F8: fairness measures ---------------------------------------------------

## F8 fan lane: the gap between neighbouring fan bullets at `d_ref`, minus the
## bullet diameter. Must stay at or above `lane_min_clear`.
static func fan_lane_clear(spread_rad: float, d_ref: float, r_b: float) -> float:
	return spread_rad * d_ref - 2.0 * r_b


## F8 ring lane: how many bullets a ring may have before its lanes close at
## the measuring distance.
static func ring_count_limit(distance: float, lane_min_clear: float, r_b: float) -> int:
	return int(TAU * distance / (lane_min_clear + 2.0 * r_b))


## F8 spiral arm gap: the distance between successive arms after one interval,
## minus the bullet diameter.
static func spiral_arm_gap(
	speed: float, interval_ticks: int, step_rad: float, arms: int, r_b: float
) -> float:
	var turn := absf(step_rad) * float(maxi(1, arms))
	if turn <= 0.0:
		return INF  # a step of 0 is a fixed stream, not a spiral: no arm gap
	return speed * (float(interval_ticks) / TICKS_PER_SECOND) * TAU / turn - 2.0 * r_b


## F8 wall corridor: the clear width of a wall's gap.
static func wall_corridor(gap_width: int, spacing: float, r_b: float) -> float:
	return float(gap_width + 1) * spacing - 2.0 * r_b


## F8 spray count limit: how many bullets fit in the arc without closing a lane.
static func spray_count_limit(
	arc_rad: float, jitter: float, d_ref: float, lane_min_clear: float, r_b: float
) -> int:
	return int((1.0 - jitter) * arc_rad * d_ref / (lane_min_clear + 2.0 * r_b))


## F7 required spawn-safe radius: hitbox + bullet + how far the bullet travels
## in the player's reaction window.
static func required_safe_radius(
	r_p: float, r_b: float, speed: float, react_ticks: int
) -> float:
	return r_p + r_b + speed * float(react_ticks) / TICKS_PER_SECOND


# --- F9: density budget ------------------------------------------------------

## F9: bullets per second one runner puts on the field.
static func runner_rate(count_effective: int, gap_slots: int, burst_count: int, interval: int) -> float:
	var fired := maxi(0, count_effective - gap_slots)
	return float(fired) * float(burst_count) * TICKS_PER_SECOND / float(maxi(1, interval))


## F9: live bullets one runner sustains, `rate * path_length / speed`.
static func runner_density(rate: float, path_length: float, effective_speed: float) -> float:
	if effective_speed <= 0.0:
		return INF
	return rate * path_length / effective_speed


## F9 effective speed per behaviour: Straight and Curve keep their speed,
## Accelerate averages its start and its cap, and Warp uses the authored
## estimate (a Warp bullet spends 0.4 s frozen on the field).
static func effective_speed(
	behaviour: int, speed: float, accel_cap: float, warp_estimate: float = 66.0
) -> float:
	if behaviour == BulletField.Beh.ACCEL:
		return (speed + accel_cap) * 0.5
	if behaviour == BulletField.Beh.WARP:
		return warp_estimate
	return speed


## F9 path length: patterns that cross the screen travel further than patterns
## that spread from a point.
static func path_length(kind: int, rules: PatternRules) -> float:
	match kind:
		PatternDef.Kind.RING, PatternDef.Kind.SPIRAL, PatternDef.Kind.FLAK_BURST:
			return rules.path_length_radial
		_:
			return rules.path_length_crossing


## F9 for one pattern at a given intensity: the live bullets it sustains.
static func pattern_density(def: PatternDef, rules: PatternRules, bullet_rules: BulletRules, i: float) -> float:
	# Bullets per volley is NOT always `count`: a spiral fires one per arm and
	# ignores `count`, and a wall skips its gap slots. Using `count` for a
	# spiral would under-report a boss core by a factor of `arms`.
	var n := bullets_per_volley(def, i)
	var eff_interval := interval_with_overlap_fallback(def, interval_eff(def, i))
	var rate := runner_rate(n, 0, clamp_burst_count(def.burst_count), eff_interval)
	var v := effective_speed(
		def.behaviour, volley_speed(def), bullet_rules.max_accel_speed,
		rules.warp_effective_speed
	)
	return runner_density(rate, path_length(def.kind, rules), v)


## How many bullets one volley of `def` actually puts on the field at
## intensity `i` (F9's `count_eff - gap_slots`, generalised per kind).
static func bullets_per_volley(def: PatternDef, i: float) -> int:
	match def.kind:
		PatternDef.Kind.SPIRAL:
			return maxi(1, def.arms)
		PatternDef.Kind.WALL:
			return maxi(0, count_eff(def, i) - maxi(1, def.gap_width))
		_:
			return count_eff(def, i)


## The speed F9 should credit a volley with. A spray authors a band rather
## than one speed, so its density uses the middle of that band.
static func volley_speed(def: PatternDef) -> float:
	if def.kind == PatternDef.Kind.SPRAY:
		return (def.speed_min + def.speed_max) * 0.5
	return def.speed


# --- F8: the validator -------------------------------------------------------

## Runs every F8 check over one pattern. Returns a list of strings, each
## starting with "ERROR" (fails the authoring test) or "WARN" (reported).
## An empty list means the pattern is fair by every check the GDD defines.
static func validate(def: PatternDef, rules: PatternRules, bullet_rules: BulletRules) -> Array[String]:
	var out: Array[String] = []
	var name := String(def.id) if String(def.id) != "" else "<unnamed>"
	var r_b := bullet_rules.shape_hit_radii[def.shape] if def.shape < bullet_rules.shape_hit_radii.size() else bullet_rules.hit_radius
	var r_p := rules.player_hitbox_radius
	var lane := rules.lane_min_clear

	# Burst overlap (F2), on both the authored and the scaled interval.
	var span := (clamp_burst_count(def.burst_count) - 1) * clamp_interval(def.burst_gap)
	if span >= clamp_interval(def.interval):
		out.push_back(
			"ERROR %s: burst spans %d ticks but interval is %d (F2)"
			% [name, span, clamp_interval(def.interval)]
		)
	if def.interval_at_full >= 0 and span >= clamp_interval(def.interval_at_full):
		out.push_back(
			"ERROR %s: burst spans %d ticks but interval_at_full is %d (F2)"
			% [name, span, clamp_interval(def.interval_at_full)]
		)

	# Speed clamps (owned by Bullet manager).
	if def.speed < bullet_rules.min_speed or def.speed > bullet_rules.max_speed:
		out.push_back(
			"ERROR %s: speed %.1f is outside the bullet manager clamp %.0f-%.0f"
			% [name, def.speed, bullet_rules.min_speed, bullet_rules.max_speed]
		)

	# Spawn safety (F7).
	var safe := def.spawn_safe_radius if def.spawn_safe_radius >= 0.0 else rules.spawn_safe_radius
	if def.spawn_safe_radius >= 0.0 and def.spawn_safe_radius < rules.spawn_safe_radius:
		out.push_back(
			"ERROR %s: spawn_safe_radius %.1f is below the library default %.1f (a pattern may only raise it)"
			% [name, def.spawn_safe_radius, rules.spawn_safe_radius]
		)
	var fastest := def.speed_max if def.kind == PatternDef.Kind.SPRAY else def.speed
	var needed := required_safe_radius(r_p, r_b, fastest, rules.react_ticks)
	if safe < needed:
		out.push_back(
			"ERROR %s: spawn_safe_radius %.1f is below the %.1f a %.0f px/s bullet needs (F7)"
			% [name, safe, needed, fastest]
		)

	# Lock (F5).
	if def.lock_ticks != 0:
		if def.reaim_each_volley:
			out.push_back("ERROR %s: aim lock and reaim_each_volley cannot be combined (F5)" % name)
		if def.lock_ticks >= clamp_interval(def.interval):
			out.push_back(
				"ERROR %s: lock_ticks %d must be below interval %d (F5)"
				% [name, def.lock_ticks, clamp_interval(def.interval)]
			)
		if def.lock_ticks < 18 or def.lock_ticks > 60:
			out.push_back(
				"WARN %s: lock_ticks %d is outside 18-60 (under 18 the tell is unreadable, over 60 it is a free dodge)"
				% [name, def.lock_ticks]
			)
		if clamp_start_delay(def.start_delay) < def.lock_ticks:
			out.push_back(
				"WARN %s: start_delay %d is shorter than lock_ticks %d, so the first tell is short"
				% [name, clamp_start_delay(def.start_delay), def.lock_ticks]
			)

	# Per-kind geometry.
	match def.kind:
		PatternDef.Kind.AIMED_FAN:
			var n_max := maxi(count_eff(def, 0.0), count_eff(def, 1.0))
			if n_max >= 2:
				if def.spread_rad < 0.12:
					out.push_back(
						"ERROR %s: fan spread %.3f rad is below 0.12 (F6a)" % [name, def.spread_rad]
					)
				var clear := fan_lane_clear(def.spread_rad, rules.d_ref, r_b)
				if clear < lane:
					out.push_back(
						"ERROR %s: fan lane %.1f px at d_ref is below lane_min_clear %.1f (F8)"
						% [name, clear, lane]
					)
		PatternDef.Kind.RING:
			var limit := ring_count_limit(rules.lane_measure_distance, lane, r_b)
			var n_max := maxi(count_eff(def, 0.0), count_eff(def, 1.0))
			if n_max > limit:
				out.push_back(
					"ERROR %s: ring count %d exceeds the %d that keep lanes open at %.0f px (F8)"
					% [name, n_max, limit, rules.lane_measure_distance]
				)
		PatternDef.Kind.SPIRAL:
			var gap := spiral_arm_gap(
				def.speed, clamp_interval(def.interval), def.step_rad, def.arms, r_b
			)
			if gap < lane:
				out.push_back(
					"ERROR %s: spiral arm gap %.1f px is below lane_min_clear %.1f (F8)"
					% [name, gap, lane]
				)
			if def.arms < 1 or def.arms > 6:
				out.push_back("ERROR %s: spiral arms %d is outside 1-6" % [name, def.arms])
		PatternDef.Kind.WALL:
			var corridor := wall_corridor(def.gap_width, def.spacing, r_b)
			if corridor < lane:
				out.push_back(
					"ERROR %s: wall corridor %.1f px is below lane_min_clear %.1f (F8)"
					% [name, corridor, lane]
				)
			elif corridor < rules.wall_corridor_warn:
				out.push_back(
					"WARN %s: wall corridor %.1f px is below the %.1f px comfort warning"
					% [name, corridor, rules.wall_corridor_warn]
				)
			if def.speed > rules.wall_speed_max:
				out.push_back(
					"ERROR %s: wall speed %.1f exceeds wall_speed_max %.1f (F8)"
					% [name, def.speed, rules.wall_speed_max]
				)
			var reach := (
				float(rules.validator_react_ticks)
				+ rules.canvas_width / rules.player_speed_per_tick
			)
			var shortest := clamp_interval(def.interval)
			if def.interval_at_full >= 0:
				shortest = mini(shortest, clamp_interval(def.interval_at_full))
			if float(shortest) < reach:
				out.push_back(
					"ERROR %s: wall interval %d ticks is below the %.0f needed to cross to the gap (F8)"
					% [name, shortest, reach]
				)
			if def.spacing < 8.0:
				out.push_back("ERROR %s: wall spacing %.1f is below 8 px" % [name, def.spacing])
			if maxi(count_eff(def, 0.0), count_eff(def, 1.0)) < 3:
				out.push_back("ERROR %s: a wall needs at least 3 slots" % name)
		PatternDef.Kind.RADIAL_CURVE:
			if absf(def.spin) > bullet_rules.max_curve_rate:
				out.push_back(
					"ERROR %s: spin %.2f exceeds the bullet manager clamp %.2f (F6e)"
					% [name, def.spin, bullet_rules.max_curve_rate]
				)
		PatternDef.Kind.FLAK_BURST:
			if def.flak_delay < 18:
				out.push_back(
					"ERROR %s: flak_delay %d is below the 18-tick minimum tell (F8)"
					% [name, def.flak_delay]
				)
			if def.standoff < safe + 8.0:
				out.push_back(
					"ERROR %s: standoff %.1f is below spawn_safe_radius + 8 = %.1f (F8)"
					% [name, def.standoff, safe + 8.0]
				)
			var ring_limit := ring_count_limit(def.standoff, lane, r_b)
			var n_max := maxi(count_eff(def, 0.0), count_eff(def, 1.0))
			if n_max > ring_limit:
				out.push_back(
					"ERROR %s: flak ring count %d exceeds the %d that keep lanes open at standoff %.0f (F8)"
					% [name, n_max, ring_limit, def.standoff]
				)
			if def.flak_distance < 80.0 or def.flak_distance > 400.0:
				out.push_back(
					"WARN %s: flak_distance %.0f is outside 80-400" % [name, def.flak_distance]
				)
		PatternDef.Kind.SPRAY:
			var limit := spray_count_limit(def.arc_rad, def.jitter, rules.d_ref, lane, r_b)
			var n_max := maxi(count_eff(def, 0.0), count_eff(def, 1.0))
			if n_max > limit:
				out.push_back(
					"ERROR %s: spray count %d exceeds the %d that keep lanes open (F8)"
					% [name, n_max, limit]
				)
			if def.arc_rad < 0.3 or def.arc_rad > 1.6:
				out.push_back("WARN %s: spray arc %.2f rad is outside 0.3-1.6" % [name, def.arc_rad])
			if def.jitter < 0.0 or def.jitter >= 1.0:
				out.push_back(
					"ERROR %s: spray jitter %.2f must be in [0, 1): jitter 1 can close a lane (F6g)"
					% [name, def.jitter]
				)
			if def.speed_min < bullet_rules.min_speed:
				out.push_back(
					"ERROR %s: spray speed_min %.1f is below the %.0f floor"
					% [name, def.speed_min, bullet_rules.min_speed]
				)
			if def.speed_max < def.speed_min:
				out.push_back("ERROR %s: spray speed_max is below speed_min" % name)

	# F9 density, checked at both gate ends.
	var worst := maxf(
		pattern_density(def, rules, bullet_rules, def.min_intensity),
		pattern_density(def, rules, bullet_rules, def.max_intensity)
	)
	if worst > rules.scene_density_budget:
		out.push_back(
			"ERROR %s: one runner sustains %.0f bullets, over the %.0f scene budget (F9)"
			% [name, worst, rules.scene_density_budget]
		)
	elif worst > rules.runner_density_warn:
		out.push_back(
			"WARN %s: runner sustains %.0f bullets, over the %.0f warning (F9)"
			% [name, worst, rules.runner_density_warn]
		)

	return out
