class_name PopupLayer
extends Node2D
## Floating world-space text ("TURRET DOWN", "CORE EXPOSED!").
## Listens to GameEvents.popup_requested so gameplay code never touches it directly.

@export var lifetime := 1.0
@export var rise := 30.0
@export var font_size := 12
@export var color := Color(1, 1, 0.6)

var _items: Array[Dictionary] = []


func _ready() -> void:
	GameEvents.popup_requested.connect(_on_popup_requested)


func _on_popup_requested(world_position: Vector2, text: String) -> void:
	_items.append({"pos": world_position, "text": text, "age": 0.0})


func _process(delta: float) -> void:
	for i in range(_items.size() - 1, -1, -1):
		_items[i].age += delta
		if _items[i].age > lifetime:
			_items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for item in _items:
		var age: float = item.age
		var pos: Vector2 = item.pos
		var c := color
		c.a = 1.0 - age / lifetime
		draw_string(font, pos + Vector2(-40, -30 - age * rise), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
