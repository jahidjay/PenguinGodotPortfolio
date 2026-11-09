class_name LobbyModel
extends RefCounted
## The Lobby / plane select screen's model: four slot panels, one cursor per
## slot, ready-up and the commit countdown.
## Implements design/gdd/menus-title-plane-select.md Rules 18-25 at MVP scope.
##
## Node-free and tickable at 60 Hz (ADR-0001), so the whole screen's behaviour
## is unit-testable without a viewport: the view draws what this says and
## sends it nothing but a [SimInput] snapshot.
##
## The three verbs come from Input (2) Rule 24:
##   Start   join (Empty slot)
##   Fire    Confirm — lock the hovered plane
##   Bomb    Cancel  — unlock, then leave
##
## **Duplicate planes are allowed** (Rule 20), and the two players are told
## apart by the **colourway**, which is the slot's own identity colour:
## P1 amber, P2 azure, P3 green, P4 pink (art bible 3.1, 4.4). So if P2 picks
## the plane P1 already locked, P2 flies the azure one — the second, third and
## fourth pick of the same plane each come out a different colour, and no two
## planes on screen ever share a palette.
##
## Usage:
## [codeblock]
## var lobby := LobbyModel.new(card_set, rules)
## lobby.open(0)                      # the device that confirmed START GAME
##
## # once per physics step, paused or not
## lobby.tick(input)
## if lobby.committed:
##     GameSession.start_run(lobby.selections())
## elif lobby.abandoned:
##     back_to_title()
## [/codeblock]

const MAX_SLOTS := 4

## Rule 21's slot panel states.
enum SlotState { EMPTY, CHOOSING, LOCKED }

var cards: Array[PlaneCard] = []
var rules: LobbyRules

## True for exactly one tick, when the countdown finished and the run may
## start. The host reads it and changes scene.
var committed := false
## True once every joined slot has left: the Lobby goes back to Title
## (Rule 21), or the whole screen went idle (Rule 24b).
var abandoned := false
## Ticks the "Starting" bar has run, 0 when it is not running.
var commit_ticks := 0
## Ticks since any joined slot last sent input, for Rule 24b.
var idle_ticks := 0

var _state := PackedInt32Array()
var _cursor := PackedInt32Array()
## Ticks since this slot last sent input, for the AFK release (Rule 24a).
var _quiet := PackedInt32Array()
## Held-direction repeat state, per slot: last direction and its timer.
var _nav_dir := PackedInt32Array()
var _nav_timer := PackedInt32Array()
## 0 until this slot has been seen with Confirm, Cancel and Start all up.
##
## The screen opens on the very press that confirmed START GAME, and a fresh
## [SimInput] reports a button that was already down as a PRESS on its first
## tick. Without this gate that one press would lock a plane and launch the
## run before the player ever saw the cards. Same shape as Input Rule 27's
## re-arm after a pause: a button has to be released before it counts.
var _armed := PackedInt32Array()


func _init(card_set: PlaneCardSet, p_rules: LobbyRules) -> void:
	assert(card_set != null, "LobbyModel needs a PlaneCardSet (data/menus/plane_cards.tres)")
	assert(p_rules != null, "LobbyModel needs a LobbyRules (data/menus/lobby_rules.tres)")
	cards = card_set.available_cards()
	assert(cards.size() > 0, "PlaneCardSet lists no available plane")
	rules = p_rules
	_state.resize(MAX_SLOTS)
	_cursor.resize(MAX_SLOTS)
	_quiet.resize(MAX_SLOTS)
	_nav_dir.resize(MAX_SLOTS)
	_nav_timer.resize(MAX_SLOTS)
	_armed.resize(MAX_SLOTS)


## Puts one slot straight into Choosing: the device that confirmed START GAME
## on Title is already bound to it (Rule 6, Input Rule 3), so it does not have
## to press Start again. `start_on` is the card it starts hovering.
func open(slot: int, start_on := -1) -> void:
	_state[slot] = SlotState.CHOOSING
	_cursor[slot] = _default_cursor(slot) if start_on < 0 else clampi(
		start_on, 0, cards.size() - 1
	)


## One tick. Everything happens in Rule order: joins, then each slot's own
## navigation and verbs, then the commit gate, then the stall timers.
func tick(input: SimInput) -> void:
	committed = false
	var any_input := false

	for slot: int in range(MAX_SLOTS):
		var acted := _tick_slot(slot, input)
		if acted:
			_quiet[slot] = 0
			any_input = true
		elif _state[slot] != SlotState.EMPTY:
			_quiet[slot] += 1

	if joined_count() == 0:
		# Every slot left: Title (Rule 21). `open` is what put the first one
		# in, so this can only happen after a Cancel.
		abandoned = true
		return

	idle_ticks = 0 if any_input else idle_ticks + 1
	_tick_commit()
	_tick_stalls()


## Rule 23: ready when at least one slot joined and every joined slot locked.
func is_ready() -> bool:
	var joined := joined_count()
	return joined >= 1 and locked_count() == joined


func joined_count() -> int:
	var n := 0
	for slot: int in range(MAX_SLOTS):
		if _state[slot] != SlotState.EMPTY:
			n += 1
	return n


func locked_count() -> int:
	var n := 0
	for slot: int in range(MAX_SLOTS):
		if _state[slot] == SlotState.LOCKED:
			n += 1
	return n


func state_of(slot: int) -> int:
	return _state[slot]


func cursor_of(slot: int) -> int:
	return _cursor[slot]


func card_of(slot: int) -> PlaneCard:
	return cards[_cursor[slot]]


## The kit a slot will fly, as a [enum KitRules.Kind] value.
func kind_of(slot: int) -> int:
	return cards[_cursor[slot]].kit_kind


## The colourway a slot's plane is drawn in. It IS the slot index, which is
## what makes two players on the same plane tell apart (see the class note).
func colourway_of(slot: int) -> int:
	return slot


## How many lower-numbered slots already hold this slot's plane: 0 for the
## first player on it, 1 for the second, and so on. The view shows it as a
## "·2" pip on the card so a duplicate pick is visible before the run starts.
func duplicate_rank_of(slot: int) -> int:
	var rank := 0
	for other: int in range(slot):
		if _state[other] == SlotState.EMPTY:
			continue
		if _cursor[other] == _cursor[slot]:
			rank += 1
	return rank


## True while any other joined slot hovers or holds this slot's card, which
## the view draws as a split rim light (Rule 20, F8).
func is_shared(slot: int) -> bool:
	for other: int in range(MAX_SLOTS):
		if other == slot or _state[other] == SlotState.EMPTY:
			continue
		if _cursor[other] == _cursor[slot]:
			return true
	return false


## What the run starts with: one entry per locked slot, in slot order
## (Rule 23). `plane_id` is carried for the boards and the save file.
func selections() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in range(MAX_SLOTS):
		if _state[slot] != SlotState.LOCKED:
			continue
		out.append({
			"slot": slot,
			"kind": kind_of(slot),
			"colourway": colourway_of(slot),
			"plane_id": cards[_cursor[slot]].plane_id,
		})
	return out


# --- per slot -----------------------------------------------------------------

## Returns true if this slot sent any input this tick.
func _tick_slot(slot: int, input: SimInput) -> bool:
	var dir := input.move_x(slot)
	if _armed[slot] == 0:
		# Wait for a clean hand before reading any verb from this slot.
		if (
			input.held(slot, SimInput.Action.FIRE)
			or input.held(slot, SimInput.Action.BOMB)
			or input.held(slot, SimInput.Action.START)
		):
			return true
		_armed[slot] = 1

	var start := input.pressed(slot, SimInput.Action.START)
	var confirm := input.pressed(slot, SimInput.Action.FIRE)
	var cancel := input.pressed(slot, SimInput.Action.BOMB)

	if _state[slot] == SlotState.EMPTY:
		# Rule 18 / Input Rule 3: a Start press is the whole join flow.
		# Confirm also joins, because a player who grabbed a pad and pressed
		# the big button meant to join.
		if start or confirm:
			open(slot)
			return true
		return false

	var acted := false

	# Rule 20: left/right wraps, and only this slot's own device moves it.
	var step := _nav_step(slot, dir)
	if step != 0 and _state[slot] == SlotState.CHOOSING:
		_cursor[slot] = wrapi(_cursor[slot] + step, 0, cards.size())
		acted = true
	elif step != 0:
		acted = true

	if confirm and _state[slot] == SlotState.CHOOSING:
		_state[slot] = SlotState.LOCKED
		_reset_commit()
		acted = true
	elif cancel:
		# Rule 21: Cancel unlocks; a second Cancel leaves and releases the
		# device. Leaving also stops a countdown that was already running.
		if _state[slot] == SlotState.LOCKED:
			_state[slot] = SlotState.CHOOSING
		else:
			_release(slot)
		_reset_commit()
		acted = true
	elif start and _state[slot] == SlotState.CHOOSING:
		# Start confirms too (Input Rule 24: Confirm = Fire or Start).
		_state[slot] = SlotState.LOCKED
		_reset_commit()
		acted = true

	if dir != 0:
		acted = true
	return acted


## Input F4 / Rule 23: a direction fires once on the press, then repeats.
func _nav_step(slot: int, dir: int) -> int:
	if dir == 0:
		_nav_dir[slot] = 0
		_nav_timer[slot] = 0
		return 0
	if _nav_dir[slot] != dir:
		_nav_dir[slot] = dir
		_nav_timer[slot] = rules.nav_repeat_first
		return dir
	_nav_timer[slot] -= 1
	if _nav_timer[slot] > 0:
		return 0
	_nav_timer[slot] = rules.nav_repeat
	return dir


func _release(slot: int) -> void:
	_armed[slot] = 0
	_state[slot] = SlotState.EMPTY
	_cursor[slot] = 0
	_quiet[slot] = 0
	_nav_dir[slot] = 0
	_nav_timer[slot] = 0


## A joining slot starts on the plane whose row matches its slot, so four
## players who all press Start and Confirm immediately get four different
## planes — the concept's third pillar without anyone navigating.
## (Save 26 will replace this with `profile.last_plane[slot]`, Rule 22.)
func _default_cursor(slot: int) -> int:
	return slot % cards.size()


# --- commit and stalls --------------------------------------------------------

func _tick_commit() -> void:
	if not is_ready():
		commit_ticks = 0
		return
	commit_ticks += 1
	if commit_ticks >= rules.start_delay_ticks:
		committed = true


func _reset_commit() -> void:
	commit_ticks = 0


func _tick_stalls() -> void:
	# Rule 24a: an AFK Choosing slot is released, but only while somebody
	# else is actually waiting on it.
	if locked_count() >= 1:
		for slot: int in range(MAX_SLOTS):
			if (
				_state[slot] == SlotState.CHOOSING
				and _quiet[slot] >= rules.afk_release_ticks
			):
				_release(slot)
		if joined_count() == 0:
			abandoned = true
			return
	# Rule 24b: the whole screen going quiet returns to Title. There is no
	# forced lock-in.
	if idle_ticks >= rules.lobby_idle_ticks:
		abandoned = true


## True once this slot's device has been seen with every verb released, so
## its presses now count.
func is_armed(slot: int) -> bool:
	return _armed[slot] == 1


## True while the "returning to title" warning bar should show (Rule 24b).
func idle_warning() -> bool:
	return idle_ticks >= rules.lobby_idle_ticks - rules.lobby_warn_ticks
