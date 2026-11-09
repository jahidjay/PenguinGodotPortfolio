class_name PlaneSelectScreen
extends Control
## The Lobby / plane select screen
## (design/gdd/menus-title-plane-select.md Rules 18-25, F7, F8).
##
## View only: every decision belongs to [LobbyModel], which this draws and
## feeds one [SimInput] snapshot per physics step. It owns no game state and
## changes none — on commit it hands the selections to [GameSession] and
## changes scene (UI code rules).
##
## Input comes through the same two-stage sampler the run uses
## (InputSampler.service_step / commit_sim_tick), so every device that works
## in the fight works here: slot 0 on KB1 (arrows, Z confirm, C back) or pad 0,
## slot 1 on KB2 (WASD, F confirm, R back) or pad 1, slots 2-3 on pads 2-3.
## An Empty slot joins by pressing Start (Enter / 1 / pad Start) or Fire.
##
## Every string goes through [UiStrings]; the plane cards themselves are data
## (`data/menus/plane_cards.tres`), so adding a fifth plane is a .tres edit.
##
## Layout at 360x640 (F7, scaled to the project's canvas): the card row fills
## the middle, the four slot columns sit under it, the prompt bar at the foot.

const CARDS_PATH := "res://data/menus/plane_cards.tres"
const RULES_PATH := "res://data/menus/lobby_rules.tres"
const VISUALS_PATH := "res://data/art/run_visuals_1941.tres"
const RUN_SCENE := "res://src/gameplay/run/run.tscn"
const TITLE_SCENE := "res://src/ui/menu/title.tscn"

## Art bible palette (3.1, 4.4, 7.8), until a HudTheme resource exists.
const CHAR := Color(0.118, 0.106, 0.094)
const PLATE := Color(0.161, 0.149, 0.133)
const EDGE := Color(0.353, 0.318, 0.282)
const CREAM := Color(0.957, 0.922, 0.839)
const GOLD := Color(1.0, 0.788, 0.235)
const DIM := Color(0.55, 0.52, 0.48)
## The four slot identity colours: P1 amber, P2 azure, P3 green, P4 pink.
## These ARE the colourways (LobbyModel.colourway_of), so two players on the
## same plane never share a palette.
const SLOT_COLORS := [
	Color(1.00, 0.70, 0.20),
	Color(0.45, 0.80, 1.00),
	Color(0.60, 1.00, 0.55),
	Color(1.00, 0.55, 0.85),
]
## The slot's ring pattern, so colour is never the only cue (art bible 4.4).
const SLOT_PATTERN := ["███", "█ █", "···", "═══"]

const CARD_TOP := 96.0
const CARD_HEIGHT := 232.0
const CARD_GAP := 6.0
const COLUMN_TOP := 392.0
const COLUMN_HEIGHT := 120.0

var model: LobbyModel
var visuals: RunVisuals

var _input := SimInput.new()
var _sampler: Node
var _canvas: Control
var _heading: Label
var _prompt: Label
var _toast: Label
var _toast_ticks := 0
var _leaving := false


func _ready() -> void:
	# The screen must keep ticking even if something paused the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var card_set := load(CARDS_PATH) as PlaneCardSet
	var rules := load(RULES_PATH) as LobbyRules
	visuals = load(VISUALS_PATH) as RunVisuals
	model = LobbyModel.new(card_set, rules)
	# Rule 6: the device that confirmed START GAME is already slot 0's, so P1
	# is Choosing the moment the screen opens and never presses Start twice.
	model.open(0)

	_sampler = get_node_or_null("/root/InputSampler")
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = CHAR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_lobby)
	add_child(_canvas)

	_heading = _add_label(Vector2(0.0, 24.0), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	_toast = _add_label(Vector2(0.0, 540.0), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	_prompt = _add_label(Vector2(0.0, 606.0), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	_heading.text = UiStrings.text("lobby.heading")
	_prompt.text = UiStrings.text("lobby.prompt")


func _add_label(at: Vector2, size: int, color: Color, align: int, width := 0.0) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", CHAR)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		label.size.x = width
	add_child(label)
	return label


func _physics_process(_delta: float) -> void:
	if _leaving:
		return
	if _sampler != null:
		_sampler.service_step()
		_sampler.commit_sim_tick(_input)
	model.tick(_input)
	_sync_keyboard_schemes()

	if _toast_ticks > 0:
		_toast_ticks -= 1
		if _toast_ticks == 0:
			_toast.text = ""

	if model.committed:
		_start_run()
		return
	if model.abandoned:
		_leave(TITLE_SCENE)
		return
	_canvas.queue_redraw()


## While slot 1 is in the lobby the two keyboard schemes share one keyboard,
## so WASD has to belong to KB2 alone (InputSetup, GDD "Default bindings").
func _sync_keyboard_schemes() -> void:
	var setup := get_node_or_null("/root/InputSetup")
	if setup == null or not setup.has_method("release_wasd_from_kb1"):
		return
	var slot_1_in := model.state_of(1) != LobbyModel.SlotState.EMPTY
	if slot_1_in and setup.wasd_on_kb1():
		setup.release_wasd_from_kb1()
		_show_toast(UiStrings.text("lobby.keyboard_split"))
	elif not slot_1_in and not setup.wasd_on_kb1():
		setup.restore_wasd_to_kb1()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_ticks = 180


func _start_run() -> void:
	GameSession.start_run(model.selections())
	_leave(RUN_SCENE)


func _leave(path: String) -> void:
	_leaving = true
	get_tree().change_scene_to_file(path)


# --- drawing ------------------------------------------------------------------

func _draw_lobby(_unused := 0) -> void:
	var count := model.cards.size()
	var width := (360.0 - CARD_GAP * float(count + 1)) / float(count)
	for i: int in range(count):
		_draw_card(i, Rect2(CARD_GAP + (width + CARD_GAP) * float(i), CARD_TOP, width, CARD_HEIGHT))
	for slot: int in range(LobbyModel.MAX_SLOTS):
		_draw_column(slot)
	if model.is_ready():
		_draw_commit_bar()


func _draw_card(index: int, box: Rect2) -> void:
	var card: PlaneCard = model.cards[index]
	_canvas.draw_rect(box, PLATE)

	# Rule 20 / F8: the rim light carries one segment per slot hovering or
	# locked on this card, so a shared card is obvious before the run starts.
	var holders := PackedInt32Array()
	for slot: int in range(LobbyModel.MAX_SLOTS):
		if model.state_of(slot) != LobbyModel.SlotState.EMPTY and model.cursor_of(slot) == index:
			holders.append(slot)
	if holders.size() == 0:
		_canvas.draw_rect(box, EDGE, false, 1.0)
	else:
		var seg := box.size.x / float(holders.size())
		for h: int in range(holders.size()):
			_canvas.draw_rect(
				Rect2(box.position.x + seg * float(h), box.position.y, seg, 3.0),
				SLOT_COLORS[holders[h]]
			)
		_canvas.draw_rect(box, SLOT_COLORS[holders[0]], false, 1.0)

	# The plane itself, in the colourway of the first slot holding it — or
	# P1's, as the showroom colour, when nobody is on it.
	var colourway := holders[0] if holders.size() > 0 else 0
	var sprite := _plane_sprite(card, colourway)
	var centre := Vector2(box.position.x + box.size.x * 0.5, box.position.y + 44.0)
	if sprite != null:
		_canvas.draw_texture(
			sprite,
			Vector2(
				floorf(centre.x - float(sprite.get_width()) * 0.5),
				floorf(centre.y - float(sprite.get_height()) * 0.5)
			)
		)
	else:
		_canvas.draw_colored_polygon(
			PackedVector2Array([
				centre + Vector2(0.0, -16.0),
				centre + Vector2(-13.0, 11.0),
				centre + Vector2(13.0, 11.0),
			]),
			SLOT_COLORS[colourway]
		)

	# Name, playstyle tag, and the three trait rows (Fire / Hold / Drone).
	var text_x := box.position.x + 4.0
	var w := box.size.x - 8.0
	_text(UiStrings.text(card.name_key()), text_x, box.position.y + 74.0, 13, GOLD, w)
	_text(UiStrings.text(card.style_key()), text_x, box.position.y + 92.0, 9, CREAM, w)
	_text(UiStrings.text(card.tag_key()), text_x, box.position.y + 106.0, 9, DIM, w)
	var rows := [
		["lobby.row_fire", card.fire_key()],
		["lobby.row_hold", card.hold_key()],
		["lobby.row_drone", card.drone_key()],
	]
	var y := box.position.y + 128.0
	for row: Array in rows:
		_text(UiStrings.text(row[0]), text_x, y, 9, GOLD, w)
		_text(UiStrings.text(row[1]), text_x, y + 11.0, 9, CREAM, w)
		y += 32.0


## The plane's body in one of its four colourways. `plane_sprites` holds four
## per plane, flattened as `sprite_row * 4 + colourway`.
func _plane_sprite(card: PlaneCard, colourway: int) -> Texture2D:
	if visuals == null:
		return null
	var index := card.sprite_row * 4 + colourway
	if index < 0 or index >= visuals.plane_sprites.size():
		return null
	return visuals.plane_sprites[index]


func _draw_column(slot: int) -> void:
	var width := 86.0
	var box := Rect2(4.0 + 88.0 * float(slot), COLUMN_TOP, width, COLUMN_HEIGHT)
	var state := model.state_of(slot)
	var colour: Color = SLOT_COLORS[slot]
	_canvas.draw_rect(box, PLATE)
	_canvas.draw_rect(box, colour if state != LobbyModel.SlotState.EMPTY else EDGE, false, 1.0)
	# The 3 px colour notch and the ring pattern, so the slot is identifiable
	# in greyscale too (art bible 4.4, AC-25).
	_canvas.draw_rect(Rect2(box.position.x, box.position.y, 3.0, box.size.y), colour)

	var x := box.position.x + 6.0
	var w := box.size.x - 10.0
	_text("P%d %s" % [slot + 1, SLOT_PATTERN[slot]], x, box.position.y + 4.0, 11, colour, w)

	match state:
		LobbyModel.SlotState.EMPTY:
			_text(UiStrings.text("lobby.join"), x, box.position.y + 28.0, 9, DIM, w)
		LobbyModel.SlotState.CHOOSING:
			_text(UiStrings.text("lobby.choosing"), x, box.position.y + 28.0, 10, CREAM, w)
			_text(
				UiStrings.text(model.card_of(slot).name_key()),
				x, box.position.y + 46.0, 11, GOLD, w
			)
			_text(UiStrings.text("lobby.confirm_hint"), x, box.position.y + 76.0, 8, DIM, w)
		LobbyModel.SlotState.LOCKED:
			_text(UiStrings.text("lobby.ready"), x, box.position.y + 28.0, 12, colour, w)
			_text(
				UiStrings.text(model.card_of(slot).name_key()),
				x, box.position.y + 46.0, 11, GOLD, w
			)
			# The user-visible half of the duplicate rule: a player who picked
			# a plane somebody else already holds is told which copy they are.
			if model.duplicate_rank_of(slot) > 0:
				_text(
					UiStrings.text("lobby.colour_variant").format(
						[model.duplicate_rank_of(slot) + 1]
					),
					x, box.position.y + 62.0, 8, colour, w
				)
			_text(UiStrings.text("lobby.cancel_hint"), x, box.position.y + 76.0, 8, DIM, w)


## Rule 23's "Starting" bar: the run commits when it fills.
func _draw_commit_bar() -> void:
	var ratio := clampf(
		float(model.commit_ticks) / float(maxf(1.0, model.rules.start_delay_ticks)), 0.0, 1.0
	)
	var box := Rect2(60.0, 524.0, 240.0, 8.0)
	_canvas.draw_rect(box, PLATE)
	_canvas.draw_rect(Rect2(box.position, Vector2(box.size.x * ratio, box.size.y)), GOLD)
	_canvas.draw_rect(box, EDGE, false, 1.0)


## One run of text. Labels are nodes; a lobby redrawn every tick draws its
## text immediately instead, the same way the run scene does.
func _text(text: String, x: float, y: float, size: int, colour: Color, width: float) -> void:
	var font := ThemeDB.fallback_font
	_canvas.draw_string(
		font, Vector2(x, y + float(size)), text, HORIZONTAL_ALIGNMENT_LEFT,
		width, size, colour
	)
