class_name SimRng
extends Object
## Factory for the simulation's seeded random streams (ADR-0003 Decision 4).
##
## WHY A FACTORY: there is deliberately NO shared gameplay RNG. A shared
## generator makes every draw order-dependent, so adding one enemy, or one
## refused spawn, would shift every later random choice and silently change a
## replay. Instead each owner gets its own stream, seeded from stable authored
## ids, and advances only on its own draws.
##
## Every stream must be REGISTERED here and listed in ADR-0003's stream table.
## Adding one is an ADR amendment, not a code change on its own — the assert is
## there to make an unlisted stream fail loudly in tests rather than quietly
## become un-reproducible state.
##
## Usage:
## [codeblock]
## # one emitter's stream: adding, removing or reordering other emitters
## # never changes this one's draws (Pattern library Rule 15)
## var rng := SimRng.make(
##     SimRng.EMITTER, [run_seed, stage_index, owner_id, emitter_index]
## )
## var u := rng.randf()
## [/codeblock]

## Pattern library runner streams: ring offsets, wall gaps, spray angles.
const EMITTER := &"emitter"
## Powerups drop draws.
const DROPS := &"drops"

## Streams listed in ADR-0003 Decision 4. Keep in sync with that table.
const REGISTERED: Array[StringName] = [EMITTER, DROPS]


## Builds the generator for one stream. `parts` are the stable ids that
## identify this particular stream (see ADR-0003's table for each stream's
## seed recipe).
static func make(stream_key: StringName, parts: Array) -> RandomNumberGenerator:
	assert(
		REGISTERED.has(stream_key),
		"SimRng: stream '%s' is not registered in ADR-0003 Decision 4" % stream_key
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = SimHash.seed([stream_key] + parts)
	return rng


## Hashes a generator's position so a stream's progress is part of
## `state_hash()`. `state` is opaque; only equality matters.
static func hash_into(ctx: HashingContext, rng: RandomNumberGenerator) -> void:
	SimHash.add_int(ctx, rng.seed)
	SimHash.add_int(ctx, rng.state)
