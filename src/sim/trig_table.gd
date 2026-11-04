class_name TrigTable
extends Resource
## Shipped quarter-wave sine table (ADR-0003 Decision 3).
##
## The simulation may not call the platform `sin`/`cos`/`atan2`: their results
## come from the platform libm, which differs between Windows, Linux and the
## Web/wasm build, so two platforms would diverge mid-run and break replay
## verification. This table is generated ONCE, offline, by
## `tools/gen_trig_table.gd` and shipped as data, so every platform reads the
## same bytes.
##
## Covered by `content_hash`: regenerating it is a new ruleset (ADR-0003 D10).
##
## Usage: never read directly — go through [SimMath].
## [codeblock]
## var s := SimMath.sin_bam(SimMath.QUARTER)   # sin(90 deg) == 1.0
## [/codeblock]

## Entries in the quarter wave. 16,384 (ADR-0003 Decision 3).
@export var entries := 16384

## `quarter_sine[i] = sin(i * (PI/2) / entries)`, float32. Index `entries`
## itself is not stored: it is exactly 1.0 and SimMath substitutes it.
@export var quarter_sine := PackedFloat32Array()
