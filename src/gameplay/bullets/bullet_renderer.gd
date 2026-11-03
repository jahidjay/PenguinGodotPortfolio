class_name BulletRenderer
extends Node2D
## Draws a BulletField through one MultiMesh. ADR-0001 Decision 4.
##
## `instance_count` is allocated once and never changed. Each frame sets
## `visible_instance_count` and assigns the whole `multimesh.buffer` in ONE
## call. No _draw()/draw_circle for bullets.
##
## Buffer layout for TRANSFORM_2D + use_colors + use_custom_data is 16 floats
## per instance: 8 transform (two rows of four), 4 colour, 4 custom data.
## That layout is listed UNVERIFIED for 4.7 in ADR-0001 and is asserted
## empirically by verify_buffer_layout() and by the V1 benchmark.
##
## With an atlas the quad is textured and `bullet_atlas.gdshader` picks each
## instance's cell from INSTANCE_CUSTOM.x, so four bullet shapes still cost
## ONE draw call. Without one the mesh is an untextured quad tinted per shape,
## and the game runs exactly the same — the packing path below never changes.
##
## To re-skin every enemy bullet in the game, replace the atlas PNG. See
## docs/art-pipeline.md.

const FLOATS_PER_INSTANCE := 16
const SHADER_PATH := "res://src/gameplay/bullets/shaders/bullet_atlas.gdshader"

var multimesh: MultiMesh
var _instance: MultiMeshInstance2D
var _buffer := PackedFloat32Array()
## Tint per shape index; replaced by the atlas lookup once art lands.
var _shape_colors: PackedColorArray


func _init(capacity: int = 0, bullet_size: float = 7.0, shape_colors := PackedColorArray()) -> void:
	if capacity <= 0:
		return
	setup(capacity, bullet_size, shape_colors)


## Allocates for `capacity` instances once. Safe to call outside the tree.
func setup(
	capacity: int,
	bullet_size: float,
	shape_colors: PackedColorArray,
	atlas: Texture2D = null,
	atlas_cells: int = 4
) -> void:
	_shape_colors = shape_colors
	if _shape_colors.is_empty():
		_shape_colors = PackedColorArray([Color.WHITE])

	var quad := QuadMesh.new()
	quad.size = Vector2(bullet_size, bullet_size)

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0

	_buffer.resize(capacity * FLOATS_PER_INSTANCE)

	_instance = MultiMeshInstance2D.new()
	_instance.multimesh = multimesh
	if atlas != null:
		# The quad is drawn at the atlas cell's own size, so a 16 px cell is
		# not stretched over a 7 px quad and softened.
		var cell := float(atlas.get_height())
		quad.size = Vector2(cell, cell)
		_instance.texture = atlas
		var material := ShaderMaterial.new()
		material.shader = load(SHADER_PATH)
		material.set_shader_parameter("cells", atlas_cells)
		_instance.material = material
	add_child(_instance)


## Packs the live rows and hands the whole buffer over in one assignment.
func sync_from(field: BulletField) -> void:
	var n := pack(field, _buffer)
	multimesh.visible_instance_count = n
	multimesh.buffer = _buffer


## Fills `into` from the field's arrays. Returns the instance count written.
## Split out from sync_from so the benchmark can time packing without a
## rendering device attached.
func pack(field: BulletField, into: PackedFloat32Array) -> int:
	var n := field.count()
	if n == 0:
		return 0
	var x := field.x_array()
	var y := field.y_array()
	var shape := field.shape_array()
	var colors := _shape_colors
	var color_count := colors.size()

	var w := 0
	for i: int in range(n):
		# Row 0: (basis.x.x, basis.y.x, 0, origin.x)
		into[w] = 1.0
		into[w + 1] = 0.0
		into[w + 2] = 0.0
		into[w + 3] = x[i]
		# Row 1: (basis.x.y, basis.y.y, 0, origin.y)
		into[w + 4] = 0.0
		into[w + 5] = 1.0
		into[w + 6] = 0.0
		into[w + 7] = y[i]

		var s := shape[i]
		var c := colors[s % color_count]
		into[w + 8] = c.r
		into[w + 9] = c.g
		into[w + 10] = c.b
		into[w + 11] = c.a

		# Custom data: shape index for the atlas frame, rest reserved.
		into[w + 12] = float(s)
		into[w + 13] = 0.0
		into[w + 14] = 0.0
		into[w + 15] = 0.0
		w += FLOATS_PER_INSTANCE
	return n


## Empirically checks the 16-float stride ADR-0001 assumes, and that a 2D
## transform round-trips through the buffer. Returns "" on success or a
## description of the mismatch. Needs no rendering device.
static func verify_buffer_layout() -> String:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = 2

	# MultiMesh.buffer is empty with no rendering device attached, so this
	# cannot be checked under --headless. Reported as a skip, never a pass:
	# ADR-0001 lists the 4.7 layout as UNVERIFIED and it stays that way until
	# this runs with a real device.
	if mm.buffer.is_empty():
		return "SKIP: needs a rendering device (MultiMesh.buffer is empty headless)"

	var stride := mm.buffer.size() / 2
	if stride != FLOATS_PER_INSTANCE:
		return "stride is %d floats per instance, ADR-0001 assumes %d" % [
			stride, FLOATS_PER_INSTANCE,
		]

	var probe := Transform2D(0.0, Vector2(12.0, 34.0))
	mm.set_instance_transform_2d(1, probe)
	var buf := mm.buffer
	var base := FLOATS_PER_INSTANCE
	var got_x: float = buf[base + 3]
	var got_y: float = buf[base + 7]
	if not (is_equal_approx(got_x, 12.0) and is_equal_approx(got_y, 34.0)):
		return "origin lands at [3]=%f [7]=%f, expected 12,34" % [got_x, got_y]

	return ""
