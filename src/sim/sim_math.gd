class_name SimMath
extends Object
## Platform-independent trigonometry for the simulation (ADR-0003 Decision 3).
##
## WHY THIS EXISTS: `sin`, `cos` and `atan2` are implemented by the platform
## libm. Windows, Linux and the wasm Web build do not agree on their last bits,
## so a bullet aimed with `atan2` would travel a slightly different path on a
## different machine, the two runs would diverge, and every replay and
## leaderboard claim would be unverifiable. ADR-0003 therefore BANS those
## calls inside `SimWorld` and routes all angle work through this class, which
## reads a shipped table (`data/sim/trig_table.tres`) instead.
##
## ANGLES ARE INTEGERS. One turn is [constant TURN] = 65,536 **binary angle
## units** (bam), so angles wrap exactly with a mask and never accumulate
## float error. 0 bam points right (+x) and [constant QUARTER] points down
## (+y), matching the GDD convention (0 = right, pi/2 = down).
##
## Designer data is authored in radians; convert it ONCE at load with
## [method rad_to_bam], never inside a tick.
##
## Usage:
## [codeblock]
## # aim a bullet from an emitter at a player (angle taken once per burst)
## var a := SimMath.atan2_bam(target.y - origin.y, target.x - origin.x)
## var vx := SimMath.cos_bam(a) * speed
## var vy := SimMath.sin_bam(a) * speed
##
## # a spiral that never drifts: integer angle from the integer volley counter
## var step := SimMath.rad_to_bam(0.33)         # at load
## var phi := (angle_offset + volley * step) & SimMath.MASK
##
## # publish a closed-form position on the 1/16 px grid (ADR-0003 D3)
## var px := SimMath.quantise(centre.x + SimMath.cos_bam(a) * radius)
## [/codeblock]

## Binary angle units in a full turn.
const TURN := 65536
## Wrapping mask. `a & MASK` is the canonical angle for any int.
const MASK := 65535
## A quarter turn: 90 degrees, and the size of the shipped table.
const QUARTER := 16384
## A half turn: 180 degrees.
const HALF := 32768

## Steps the published-position grid is quantised to (ADR-0003 D3: 1/16 px).
const QUANTISE_STEPS := 16.0

const TABLE_PATH := "res://data/sim/trig_table.tres"

## Loaded when the script is first loaded, so no tick ever touches the
## filesystem (ADR-0003 Decision 6 forbids loading inside `tick()`).
static var _quarter_sine: PackedFloat32Array = _load_table()


static func _load_table() -> PackedFloat32Array:
	var res := load(TABLE_PATH) as Resource
	assert(res != null, "SimMath: %s is missing (run tools/gen_trig_table.gd)" % TABLE_PATH)
	var values: PackedFloat32Array = res.quarter_sine
	assert(
		values.size() == QUARTER,
		"SimMath: trig table has %d entries, expected %d" % [values.size(), QUARTER]
	)
	return values


## Sine of a binary angle. Exact at the four cardinal angles.
static func sin_bam(a: int) -> float:
	var w := a & MASK
	var i := w & (QUARTER - 1)
	match w >> 14:
		0:
			return _quarter_sine[i]
		1:
			return _wave(QUARTER - i)
		2:
			return -_quarter_sine[i]
		_:
			return -_wave(QUARTER - i)


## Cosine of a binary angle. `cos(a) == sin(a + 90 deg)`.
static func cos_bam(a: int) -> float:
	return sin_bam(a + QUARTER)


## Index `QUARTER` is not stored (it is exactly 1.0); everything else is a
## straight table read.
static func _wave(i: int) -> float:
	return 1.0 if i >= QUARTER else _quarter_sine[i]


## Angle of the vector (dx, dy) in binary angle units, in [0, TURN).
##
## Found by bisecting the shipped table, so it uses only multiplication and
## comparison — no platform `atan2`. (0, 0) returns 0. Accurate to 1 bam
## (0.0055 degrees), which is the resolution of the angle type itself.
static func atan2_bam(dy: float, dx: float) -> int:
	var ax := absf(dx)
	var ay := absf(dy)
	if ax == 0.0 and ay == 0.0:
		return 0

	# Fold into the first octant (ay <= ax), where the bisection is well
	# conditioned, then unfold with exact integer reflections.
	var swapped := ay > ax
	if swapped:
		var t := ax
		ax = ay
		ay = t

	# Smallest `m` in [0, 45 deg] with tan(m) >= ay/ax, compared by
	# cross-multiplication so no division is needed.
	var lo := 0
	var hi := QUARTER >> 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if sin_bam(mid) * ax < cos_bam(mid) * ay:
			lo = mid + 1
		else:
			hi = mid

	var angle := lo
	if swapped:
		angle = QUARTER - angle
	if dx < 0.0:
		angle = HALF - angle
	if dy < 0.0:
		angle = -angle
	return angle & MASK


## Converts authored radians to binary angle units. LOAD TIME ONLY: it uses
## float division on a designer constant, and the result is what the sim uses.
static func rad_to_bam(radians: float) -> int:
	return roundi(radians * (float(TURN) / TAU))


## Inverse of [method rad_to_bam]. For tests, tools and presentation only.
static func bam_to_rad(a: int) -> float:
	return float(a) * (TAU / float(TURN))


## Signed difference `to - from`, wrapped into (-HALF, HALF].
static func delta_bam(from: int, to: int) -> int:
	var d := (to - from) & MASK
	return d - TURN if d > HALF else d


## Snaps a published position to the 1/16 px grid (ADR-0003 Decision 3), so a
## closed-form path cannot drift between platforms in the bits below it.
static func quantise(v: float) -> float:
	return floorf(v * QUANTISE_STEPS + 0.5) / QUANTISE_STEPS


## Length of (x, y). `sqrt` is IEEE-exact and therefore allowed in the sim;
## `Vector2.length()` is not, until ADR-0003's V1 torture test clears it.
static func length(x: float, y: float) -> float:
	return sqrt(x * x + y * y)
