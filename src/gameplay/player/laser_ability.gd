class_name LaserAbility
extends Node2D
## Lancer's charge ability: hold to fire a laser that makes the plane invulnerable
## and hits 20x/second (each tick = 1 chain hit). Gated by a meter that fills
## from normal hits. The beam stops at the first boss part in its column.

const COLOR_OUTER := Color(1.0, 0.5, 0.1, 0.55)
const COLOR_INNER := Color(1.0, 0.95, 0.7)

var player: Player
var meter := 0.0
var active := false
## World Y where the beam ends (0 = top of the screen).
var beam_top_y := 0.0

var _tick_acc := 0.0


func setup(owner_player: Player) -> void:
	player = owner_player


func add_meter(amount: float) -> void:
	if not active:
		meter = minf(meter + amount, player.config.meter_max)


func is_ready() -> bool:
	return meter >= player.config.laser_min_meter


func meter_ratio() -> float:
	return meter / player.config.meter_max


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var cfg := player.config
	var held := not player.is_dead and player.is_action_held("ability")
	if held and not active and is_ready():
		active = true
	elif not held:
		active = false

	if not active:
		_tick_acc = 0.0
		queue_redraw()
		return

	meter -= cfg.meter_burn * delta
	if meter <= 0.0:
		meter = 0.0
		active = false

	var target := player.boss.find_laser_target(player.global_position, cfg.laser_width * 0.5)
	beam_top_y = target.bottom_y() if target != null else 0.0

	_tick_acc += delta
	var tick := 1.0 / cfg.laser_hits_per_second
	while _tick_acc >= tick:
		_tick_acc -= tick
		if target != null and target.alive:
			player.register_hit(target.apply_damage(cfg.laser_damage), false)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var top := beam_top_y - global_position.y   # negative: beam goes up
	var w := player.config.laser_width
	draw_rect(Rect2(-w * 0.5, top, w, -top), COLOR_OUTER)
	draw_rect(Rect2(-w * 0.2, top, w * 0.4, -top), COLOR_INNER)
