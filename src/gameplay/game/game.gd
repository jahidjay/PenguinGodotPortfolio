class_name Game
extends Node2D
## Composition root for one boss fight: builds the boss and player, wires them
## together, and runs the PLAYING -> WON / LOST state machine.
##
## States:
##   PLAYING -> WON   when the boss is defeated (Critical Break)
##   PLAYING -> LOST  when the player runs out of lives
##   WON / LOST: gameplay frozen, wait for restart / next_boss / boss_N
## Restart, next boss and boss select work in every state (scene reload).

enum State { PLAYING, WON, LOST }

const PLAYER_SCENE := preload("res://src/gameplay/player/player.tscn")

@export var rules: CombatRules = preload("res://data/combat_rules.tres")
@export var play_area := Rect2(0, 0, 360, 640)
## Player spawn, measured up from the bottom of the play area.
@export var spawn_from_bottom := 70.0

@onready var boss_layer: Node2D = $BossLayer
@onready var bullets: BulletManager = $BulletManager
@onready var player_layer: Node2D = $PlayerLayer
@onready var hud: Hud = $HUD

var state := State.PLAYING
var boss: Boss
var player: Player

var _result_title := ""


func _ready() -> void:
	bullets.play_area = play_area

	player = PLAYER_SCENE.instantiate()
	player.play_area = play_area
	player.position = Vector2(play_area.get_center().x, play_area.end.y - spawn_from_bottom)

	boss = Boss.new()
	boss.name = "Boss"
	boss.setup(GameSession.current_boss(), rules, bullets, player)
	boss_layer.add_child(boss)

	player_layer.add_child(player)
	player.setup(rules, bullets, boss)

	boss.defeated.connect(_on_boss_defeated)
	player.died.connect(_on_player_died)
	GameEvents.critical_break_landed.connect(_on_critical_break_landed)
	hud.bind(player, boss)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reload()
	elif event.is_action_pressed("next_boss"):
		GameSession.next_boss()
		_reload()
	elif event.is_action_pressed("boss_1"):
		_select(0)
	elif event.is_action_pressed("boss_2"):
		_select(1)
	elif event.is_action_pressed("boss_3"):
		_select(2)


func _select(index: int) -> void:
	GameSession.select_boss(index)
	_reload()


func _reload() -> void:
	get_tree().reload_current_scene()


func _on_critical_break_landed(_who: Player, final_chain: int, life_bonus: int) -> void:
	_result_title = "CRITICAL BREAK!  Chain x%d  (+%d life bonus)" % [final_chain, life_bonus]


func _on_boss_defeated() -> void:
	_end(State.WON, _result_title)


func _on_player_died() -> void:
	_end(State.LOST, "GAME OVER")


func _end(new_state: State, title: String) -> void:
	if state != State.PLAYING:
		return
	state = new_state
	bullets.clear()
	for node: Node in [boss, player, bullets]:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_result(title)
