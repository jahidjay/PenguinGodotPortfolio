class_name Hud
extends CanvasLayer
## Read-only view of one Player and the Boss. Polls state each frame; never
## changes gameplay. Screen flash is driven by GameEvents.screen_flash_requested.

const CHAIN_COLOR_NORMAL := Color.WHITE
const CHAIN_COLOR_100 := Color(1.0, 0.85, 0.2)
const CHAIN_COLOR_200 := Color(1.0, 0.3, 0.9)
const STATUS_COLOR := Color(0.7, 0.8, 1.0)
const STATUS_COLOR_CRITICAL := Color(1.0, 0.9, 0.3)
const METER_READY := Color(1, 1, 1)
const METER_NOT_READY := Color(0.55, 0.55, 0.55)

@onready var boss_hp_bar: ProgressBar = %BossHpBar
@onready var critical_marker: ColorRect = %CriticalMarker
@onready var boss_name: Label = %BossName
@onready var status: Label = %Status
@onready var chain_count: Label = %ChainCount
@onready var chain_bar: ProgressBar = %ChainBar
@onready var dropped: Label = %Dropped
@onready var stats: Label = %Stats
@onready var meter_bar: ProgressBar = %MeterBar
@onready var flash_rect: ColorRect = %Flash
@onready var result_panel: Control = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_stats: Label = %ResultStats

var player: Player
var boss: Boss

var _flash := 0.0


func _ready() -> void:
	GameEvents.screen_flash_requested.connect(_on_flash_requested)
	result_panel.hide()


func bind(target_player: Player, target_boss: Boss) -> void:
	player = target_player
	boss = target_boss
	var def := boss.definition
	boss_name.text = "%s  %s" % [def.era, def.display_name]
	var ratio := def.critical_hp / boss.core.definition.max_hp
	critical_marker.position.x = boss_hp_bar.position.x + boss_hp_bar.size.x * ratio - 1.0


func show_result(title: String) -> void:
	result_title.text = title
	result_stats.text = "Max chain: %d    Score: %d" % [player.chain.max_count, player.score]
	result_panel.show()


func _on_flash_requested(strength: float) -> void:
	_flash = maxf(_flash, strength)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	flash_rect.color.a = clampf(_flash, 0.0, 0.6) * 0.5
	if player == null or boss == null:
		return

	boss_hp_bar.value = boss.core.hp / boss.core.definition.max_hp
	status.text = _status_text()
	status.modulate = STATUS_COLOR_CRITICAL if boss.is_critical() else STATUS_COLOR

	var chain := player.chain
	chain_count.text = str(chain.count)
	chain_count.modulate = _chain_color(chain.count)
	chain_bar.value = chain.window_ratio()
	dropped.text = "dropped: %d" % chain.last_dropped if chain.last_dropped > 0 else ""

	stats.text = "LIVES %d   BOMBS %d   SCORE %d   MAX CHAIN %d" % [
		maxi(player.lives, 0), player.bombs, player.score, chain.max_count]
	meter_bar.value = player.laser.meter_ratio()
	meter_bar.modulate = METER_READY if player.laser.is_ready() else METER_NOT_READY


func _status_text() -> String:
	if boss.is_critical():
		return "!! CRITICAL: LASER + BOMB !!"
	if boss.is_core_shielded():
		return "CORE SHIELDED - destroy shields"
	if boss.is_core_armored():
		return "CORE ARMORED (%d parts left)" % boss.others_alive()
	return ""


func _chain_color(count: int) -> Color:
	if count >= 200:
		return CHAIN_COLOR_200
	if count >= 100:
		return CHAIN_COLOR_100
	return CHAIN_COLOR_NORMAL
