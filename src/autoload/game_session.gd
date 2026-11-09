extends Node
## Session state that survives a scene change (autoload "GameSession").
##
## What it holds today: the run's plane selections (which slot flies which
## plane, in which colourway) and the debug boss selection.
## Implements the slice of design/gdd/game-events-and-session.md Rule 1 that
## the Lobby needs: `start_run(selections)` is called once, by the Lobby, and
## read once, by the run scene.
##
## Usage:
## [codeblock]
## # the Lobby, on commit (menus GDD Rule 23)
## GameSession.start_run(lobby.selections())
##
## # the run scene, while it builds the world
## for slot: int in GameSession.joined_slots():
##     world.set_slot_kit(slot, GameSession.kind_of(slot))
## [/codeblock]

var bosses: Array[BossDefinition] = [
	preload("res://data/bosses/fortress_1941.tres"),
	preload("res://data/bosses/jet_carrier_1970s.tres"),
	preload("res://data/bosses/plasma_ring_2100.tres"),
]
var boss_index := 0

## One entry per slot that is in the run, in slot order. Each is
## `{slot, kind, colourway, plane_id}` — the shape [method LobbyModel.selections]
## produces. Empty before the Lobby has committed anything.
var selections: Array[Dictionary] = []


func current_boss() -> BossDefinition:
	return bosses[boss_index]


func select_boss(index: int) -> void:
	boss_index = clampi(index, 0, bosses.size() - 1)


func next_boss() -> void:
	boss_index = (boss_index + 1) % bosses.size()


## Called once by the Lobby when its countdown finishes.
func start_run(p_selections: Array[Dictionary]) -> void:
	selections = p_selections.duplicate(true)


## Drops the run's selections (quit to title, or a run that ended).
func clear_run() -> void:
	selections.clear()


func joined_slots() -> PackedInt32Array:
	var out := PackedInt32Array()
	for entry: Dictionary in selections:
		out.append(int(entry["slot"]))
	return out


## The kit a slot flies, or -1 when that slot is not in the run. A run started
## without going through the Lobby (F5 in the run scene, a headless probe)
## has no selections at all, and the caller falls back to its own default.
func kind_of(slot: int) -> int:
	for entry: Dictionary in selections:
		if int(entry["slot"]) == slot:
			return int(entry["kind"])
	return -1


## The colourway a slot's plane is drawn in, or the slot index when the run
## did not come from the Lobby.
func colourway_of(slot: int) -> int:
	for entry: Dictionary in selections:
		if int(entry["slot"]) == slot:
			return int(entry["colourway"])
	return slot


func plane_id_of(slot: int) -> String:
	for entry: Dictionary in selections:
		if int(entry["slot"]) == slot:
			return String(entry["plane_id"])
	return ""
