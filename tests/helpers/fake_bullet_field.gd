class_name FakeBulletField
extends RefCounted
## Recording stand-in for [BulletField], used by the pattern library tests
## (design/gdd/bullet-pattern-library.md, "Test setup").
##
## It has exactly the `request_spawn` signature the real field has and records
## every request with the tick it arrived on, so a test can assert geometry,
## order and target slot without running the bullet simulation. It can also
## refuse after N requests, which is how the pool-full acceptance criteria
## (AC-04, AC-45) are checked.

## Requests accepted before the field starts refusing. -1 means never refuse.
var accept_limit := -1
## Set by the test before each tick so every row carries the tick it fired on.
var tick := 0

var xs := PackedFloat32Array()
var ys := PackedFloat32Array()
var vxs := PackedFloat32Array()
var vys := PackedFloat32Array()
var behs := PackedInt32Array()
var shapes := PackedInt32Array()
var params := PackedFloat32Array()
var slots := PackedInt32Array()
var ticks := PackedInt32Array()

var refused := 0


func request_spawn(
	at_x: float,
	at_y: float,
	vel_x: float,
	vel_y: float,
	beh: int = 0,
	shape: int = 0,
	param: float = 0.0,
	target_slot: int = 0,
) -> bool:
	if accept_limit >= 0 and xs.size() >= accept_limit:
		refused += 1
		return false
	xs.push_back(at_x)
	ys.push_back(at_y)
	vxs.push_back(vel_x)
	vys.push_back(vel_y)
	behs.push_back(beh)
	shapes.push_back(shape)
	params.push_back(param)
	slots.push_back(target_slot)
	ticks.push_back(tick)
	return true


func size() -> int:
	return xs.size()


func clear() -> void:
	xs.clear()
	ys.clear()
	vxs.clear()
	vys.clear()
	behs.clear()
	shapes.clear()
	params.clear()
	slots.clear()
	ticks.clear()
	refused = 0


## Binary angle of request `i`, recovered the same way the runner computed it.
func angle_bam(i: int) -> int:
	return SimMath.atan2_bam(vys[i], vxs[i])


func speed_of(i: int) -> float:
	return SimMath.length(vxs[i], vys[i])


## Ticks on which at least one request was accepted, in order.
func fired_ticks() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in range(ticks.size()):
		if out.size() == 0 or out[out.size() - 1] != ticks[i]:
			out.push_back(ticks[i])
	return out


## Indices of the requests made on tick `t`.
func indices_at(t: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in range(ticks.size()):
		if ticks[i] == t:
			out.push_back(i)
	return out
