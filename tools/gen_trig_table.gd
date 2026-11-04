extends SceneTree
## OFFLINE generator for `data/sim/trig_table.tres` (ADR-0003 Decision 3).
##
## Run once, from the project folder, whenever the table definition changes.
## Changing the output is a new `ruleset` (ADR-0003 Decision 10).
##
##   godot --headless --script res://tools/gen_trig_table.gd
##
## This is a tool, not simulation code: it is the one place allowed to call the
## platform `sin()`, because its result is frozen into shipped data instead of
## being recomputed per platform at runtime.

const OUT_PATH := "res://data/sim/trig_table.tres"
const ENTRIES := 16384
const TrigTableScript := preload("res://src/sim/trig_table.gd")


func _init() -> void:
	var table: Resource = TrigTableScript.new()
	table.entries = ENTRIES
	var values := PackedFloat32Array()
	values.resize(ENTRIES)
	for i: int in range(ENTRIES):
		values[i] = sin(float(i) * (PI * 0.5) / float(ENTRIES))
	table.quarter_sine = values

	var err := ResourceSaver.save(table, OUT_PATH)
	if err != OK:
		printerr("gen_trig_table: save failed (%d)" % err)
		quit(1)
		return
	print("gen_trig_table: wrote %s (%d entries)" % [OUT_PATH, ENTRIES])
	quit(0)
