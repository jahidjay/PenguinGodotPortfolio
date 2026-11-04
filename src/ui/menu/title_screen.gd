class_name TitleScreen
extends Control
## The Title screen: the front door (design/gdd/menus-title-plane-select.md
## Rules 6-11, design/ux/main-menu.md).
##
## Implemented: the focus list, START GAME, the language chip, the prompt bar
## and the hi-score line, navigable by keyboard, gamepad (any player's device —
## Title is shared, last input wins) and mouse. Every other item is in the list
## because the spec puts it there, and says plainly that it is not built yet
## rather than leading the player into an empty screen.
##
## Text goes through [UiStrings], so no screen holds a user-facing literal and
## Bengali can be filled in without touching code. The `bn` column is still
## empty for most keys: a translator fills it, and until then those lines fall
## back to English on purpose.
##
## Art: the spec's logo is two art layers (`logo_title_bn` above
## `logo_title_en`). `assets/art/` is empty, so the title is drawn as text in
## the palette's Gold. The Bengali line appears only when a font that can
## render it is present in `assets/fonts/` — a missing glyph draws as a box,
## which would look broken rather than bilingual.
##
## Layout follows the spec's wireframe at 360x640: hi-score y8, logo y86,
## list from y392, prompt bar y606.

## Where the list starts without the Target-tier Flight School item
## (main-menu.md, decided 2026-11-03: y372 with it, y392 without).
const LIST_TOP := 392.0
const ROW_HEIGHT := 36.0
const ROW_HIT_HEIGHT := 28.0

## Art bible palette, until a HudTheme resource exists.
const GOLD := Color(0.93, 0.76, 0.33)
const CREAM := Color(0.95, 0.92, 0.84)
const CHAR := Color(0.10, 0.09, 0.13)
const DIM := Color(0.55, 0.52, 0.48)

const BENGALI_FONT_PATHS := [
	"res://assets/fonts/title_bn.ttf",
	"res://assets/fonts/NotoSansBengali-Regular.ttf",
]

## The list in the spec's order. `action` empty means the screen behind it does
## not exist yet. Flight School is Target tier and deliberately absent.
const ITEMS := [
	{"key": "menu.start_game", "action": "play"},
	{"key": "menu.high_scores", "action": ""},
	{"key": "menu.settings", "action": ""},
	{"key": "menu.credits", "action": ""},
	{"key": "menu.quit", "action": "quit"},
]

var _focus := 0
var _rows: Array[Label] = []
var _toast: Label
var _chip: Label
var _title_bn: Label
var _title_en: Label
var _tagline: Label
var _prompt: Label
var _hi: Label
var _bengali_font: Font


func _ready() -> void:
	_bengali_font = _find_bengali_font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = CHAR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_hi = _add_label(Vector2(8.0, 6.0), 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_chip = _add_label(Vector2(0.0, 6.0), 10, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, 352.0)

	# The logo: Bengali above English, equal weight (GDD Rule 6).
	var title_y := 86.0
	if _bengali_font != null:
		_title_bn = _add_label(
			Vector2(0.0, title_y), 40, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 360.0
		)
		_title_bn.add_theme_font_override("font", _bengali_font)
		title_y += 56.0
	_title_en = _add_label(Vector2(0.0, title_y), 40, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	_tagline = _add_label(
		Vector2(0.0, title_y + 54.0), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, 360.0
	)

	for i: int in range(ITEMS.size()):
		_rows.push_back(
			_add_label(
				Vector2(0.0, LIST_TOP + ROW_HEIGHT * float(i)),
				16,
				CREAM,
				HORIZONTAL_ALIGNMENT_CENTER,
				360.0
			)
		)

	_toast = _add_label(Vector2(0.0, 560.0), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	_prompt = _add_label(Vector2(0.0, 606.0), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, 360.0)


func _add_label(at: Vector2, size: int, color: Color, align: int, width := 0.0) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		label.size.x = width
	add_child(label)
	return label


func _find_bengali_font() -> Font:
	for path: String in BENGALI_FONT_PATHS:
		if ResourceLoader.exists(path):
			return load(path) as Font
	return null


## Redraws every string. Called on language change too, which is why no label
## keeps its own copy of the text.
func _refresh() -> void:
	_hi.text = UiStrings.text("menu.hi_score").format(["0"])
	_chip.text = UiStrings.text("lang.%s" % UiStrings.language())
	_title_en.text = UiStrings.text("title.name_en")
	if _title_bn != null:
		_title_bn.text = UiStrings.text("title.name_bn")
	_tagline.text = UiStrings.text("menu.tagline")
	_prompt.text = UiStrings.text("menu.prompt")

	for i: int in range(_rows.size()):
		var item: Dictionary = ITEMS[i]
		var ready_now: bool = not String(item["action"]).is_empty()
		var label := UiStrings.text(item["key"])
		if not ready_now:
			label += "  —"
		var focused := i == _focus
		_rows[i].text = ("> %s <" % label) if focused else label
		_rows[i].add_theme_color_override(
			"font_color", GOLD if focused else (CREAM if ready_now else DIM)
		)


func _unhandled_input(event: InputEvent) -> void:
	if _pressed(event, "up"):
		_move(-1)
	elif _pressed(event, "down"):
		_move(1)
	elif _pressed(event, "fire") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_L:
			UiStrings.cycle_language()
			_refresh()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_click(click.position)


## True when ANY player's device pressed `action`: Title is shared, and the
## last input wins (main-menu.md "Joining").
func _pressed(event: InputEvent, action: String) -> bool:
	for slot: int in range(4):
		var name := StringName("p%d_%s" % [slot + 1, action])
		if InputMap.has_action(name) and event.is_action_pressed(name):
			return true
	return false


func _move(step: int) -> void:
	_focus = wrapi(_focus + step, 0, ITEMS.size())
	_toast.text = ""
	_refresh()


## A click on a row focuses it and confirms it in one press, which is what a
## pointer player expects (interaction pattern P01).
func _click(at: Vector2) -> void:
	for i: int in range(_rows.size()):
		var top := LIST_TOP + ROW_HEIGHT * float(i)
		if at.y >= top and at.y <= top + ROW_HIT_HEIGHT:
			_focus = i
			_refresh()
			_confirm()
			return


func _confirm() -> void:
	var item: Dictionary = ITEMS[_focus]
	match String(item["action"]):
		"play":
			# Rule 6: the device that confirmed START GAME becomes P1's, and
			# the Lobby opens with that slot already Choosing.
			GameSession.clear_run()
			get_tree().change_scene_to_file("res://src/ui/menu/plane_select.tscn")
		"quit":
			get_tree().quit()
		_:
			# Honest dead end: the spec lists the item, the screen does not
			# exist yet, and the player is told so instead of being dropped
			# into an empty scene.
			_toast.text = UiStrings.text("menu.not_built").format(
				[UiStrings.text(item["key"])]
			)
