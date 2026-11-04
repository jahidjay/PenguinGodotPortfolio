class_name SimHash
extends Object
## Canonical hashing for the simulation (ADR-0003 Decision 5).
##
## WHY NOT `hash()`: Godot's Variant `hash()` is an implementation detail. It
## may change between engine versions and is not specified to agree across
## platforms, so a replay recorded on Windows could "fail" verification on the
## Web build for no gameplay reason. Everything persisted or compared across
## builds — seeds, `state_hash()` checkpoints — goes through SHA-256 over a
## byte stream whose layout is fixed here:
##
## - int: 8 bytes, little-endian two's complement
## - float: 4 bytes, the float32 bit pattern (sim state is float32 anyway)
## - bool: one byte, 0 or 1
## - String / StringName: UTF-8 length as an int, then the UTF-8 bytes
## - packed array: element count as an int, then the elements' bytes
##
## Lengths are always written before bytes, so `["ab", "c"]` can never hash the
## same as `["a", "bc"]`.
##
## Usage:
## [codeblock]
## # a seed for one emitter's random stream (ADR-0003 Decision 4)
## var s := SimHash.seed([run_seed, stage_index, owner_id, emitter_index])
##
## # a system's contribution to SimWorld.state_hash()
## func hash_into(ctx: HashingContext) -> void:
##     SimHash.add_int(ctx, _count)
##     SimHash.add_f32_array(ctx, _x)
## [/codeblock]

## Starts a context. Caller finishes with [method digest32] or [method digest].
static func begin() -> HashingContext:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	return ctx


static func add_int(ctx: HashingContext, v: int) -> void:
	var buf := PackedInt64Array()
	buf.push_back(v)
	ctx.update(buf.to_byte_array())


static func add_float(ctx: HashingContext, v: float) -> void:
	var buf := PackedFloat32Array()
	buf.push_back(v)
	ctx.update(buf.to_byte_array())


static func add_bool(ctx: HashingContext, v: bool) -> void:
	var buf := PackedByteArray()
	buf.push_back(1 if v else 0)
	ctx.update(buf)


static func add_string(ctx: HashingContext, v: String) -> void:
	var bytes := v.to_utf8_buffer()
	add_int(ctx, bytes.size())
	if bytes.size() > 0:
		ctx.update(bytes)


static func add_f32_array(ctx: HashingContext, v: PackedFloat32Array) -> void:
	add_int(ctx, v.size())
	if v.size() > 0:
		ctx.update(v.to_byte_array())


static func add_i32_array(ctx: HashingContext, v: PackedInt32Array) -> void:
	add_int(ctx, v.size())
	if v.size() > 0:
		ctx.update(v.to_byte_array())


## Adds the first `n` elements only — the live prefix of a pooled array, so a
## hash never depends on stale rows past the live count.
static func add_f32_prefix(ctx: HashingContext, v: PackedFloat32Array, n: int) -> void:
	add_int(ctx, n)
	for i: int in range(n):
		add_float(ctx, v[i])


## Adds the first `n` elements only. See [method add_f32_prefix].
static func add_i32_prefix(ctx: HashingContext, v: PackedInt32Array, n: int) -> void:
	add_int(ctx, n)
	for i: int in range(n):
		add_int(ctx, v[i])


## Adds any supported value, dispatching on its type. Used by [method seed];
## hot paths should call the typed functions directly.
static func add_variant(ctx: HashingContext, v: Variant) -> void:
	match typeof(v):
		TYPE_INT:
			add_int(ctx, v)
		TYPE_FLOAT:
			add_float(ctx, v)
		TYPE_BOOL:
			add_bool(ctx, v)
		TYPE_STRING, TYPE_STRING_NAME:
			add_string(ctx, String(v))
		TYPE_PACKED_FLOAT32_ARRAY:
			add_f32_array(ctx, v)
		TYPE_PACKED_INT32_ARRAY:
			add_i32_array(ctx, v)
		_:
			assert(false, "SimHash: unsupported type %d in the hash stream" % typeof(v))


## The whole 32-byte digest.
static func digest(ctx: HashingContext) -> PackedByteArray:
	return ctx.finish()


## The first 4 bytes of the digest as an unsigned 32-bit int. This is the
## `state_hash()` value compared at replay checkpoints.
static func digest32(ctx: HashingContext) -> int:
	return ctx.finish().decode_u32(0)


## The first 8 bytes of the digest as a signed 64-bit int, for RNG seeds.
static func digest64(ctx: HashingContext) -> int:
	return ctx.finish().decode_s64(0)


## A stable 64-bit seed from any list of supported parts (ADR-0003 D4).
## The same parts always give the same seed, on every platform and build.
static func seed(parts: Array) -> int:
	var ctx := begin()
	add_int(ctx, parts.size())
	for i: int in range(parts.size()):
		add_variant(ctx, parts[i])
	return digest64(ctx)
