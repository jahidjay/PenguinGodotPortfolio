class_name Player
extends Node2D
## A player plane: movement, lives, bombs, chain and score.
## Weapons are child components (ShotWeapon, LaserAbility) so each plane can swap its kit.
## Implements: design/gdd/game-concept.md §3 (30-Second Loop) and §4 (Critical Break).
##
## Usage:
##   var player: Player = PLAYER_SCENE.instantiate()
##   layer.add_child(player)
##   player.setup(rules, bullet_manager, boss)

signal hit_taken
signal died

@export var config: PlaneConfig
## 0..3, selects input actions p1_* .. p4_* (see InputSetup).
@export var player_index := 0
@export var play_area := Rect2(0, 0, 360, 640)
## Keeps the plane below the top HUD.
@export var top_margin := 40.0

@onready var shot_weapon: ShotWeapon = $ShotWeapon
@onready var laser: LaserAbility = $LaserAbility

var rules: CombatRules
var bullets: BulletManager
var boss: Boss
var chain: ChainTracker
var score := 0
var lives := 0
var bombs := 0
var invulnerable_time := 0.0
var is_dead := false

var _blink := 0.0


func setup(combat_rules: CombatRules, bullet_manager: BulletManager, target_boss: Boss) -> void:
	rules = combat_rules
	bullets = bullet_manager
	boss = target_boss
	chain = ChainTracker.new(rules)
	lives = config.lives
	bombs = config.bombs
	shot_weapon.setup(self)
	laser.setup(self)


func action(action_name: String) -> StringName:
	return StringName("p%d_%s" % [player_index + 1, action_name])


func is_action_held(action_name: String) -> bool:
	return Input.is_action_pressed(action(action_name))


func is_invulnerable() -> bool:
	return invulnerable_time > 0.0 or laser.active


func _physics_process(delta: float) -> void:
	if is_dead or rules == null:
		return
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	_blink += delta
	chain.tick(delta)
	_move(delta)
	if Input.is_action_just_pressed(action("bomb")):
		_use_bomb()
	bullets.target_position = global_position
	if not is_invulnerable() and bullets.overlaps(global_position, config.hitbox_radius):
		_take_hit()
	queue_redraw()


func _move(delta: float) -> void:
	var dir := Input.get_vector(action("left"), action("right"), action("up"), action("down"))
	var speed := config.speed
	if laser.active:
		speed = config.speed_ability
	elif shot_weapon.is_firing:
		speed = config.speed_firing
	position += dir * speed * delta
	position.x = clampf(position.x, play_area.position.x + 10.0, play_area.end.x - 10.0)
	position.y = clampf(position.y, play_area.position.y + top_margin, play_area.end.y - 10.0)


## Called by weapons with the result (BossPart.HitResult) of a hit on a boss part.
func register_hit(result: int, gain_meter: bool) -> void:
	if result == BossPart.HitResult.IGNORED:
		return
	chain.add_hits()
	if result == BossPart.HitResult.DESTROYED:
		chain.add_hits(rules.part_kill_chain)
		score += rules.part_kill_score
	score += rules.hit_score(chain.count)
	if gain_meter:
		laser.add_meter(config.meter_per_hit)


func _use_bomb() -> void:
	if bombs <= 0 or boss == null or boss.is_defeated:
		return
	bombs -= 1
	bullets.clear()
	invulnerable_time = maxf(invulnerable_time, config.bomb_invulnerability)
	GameEvents.screen_flash_requested.emit(0.4)
	if laser.active and boss.is_critical():
		_critical_break()
		return
	for result in boss.apply_bomb(config.bomb_damage):
		register_hit(result, true)


func _critical_break() -> void:
	var final_chain := chain.apply_critical_break()
	var life_bonus := lives * rules.life_bonus_per_life
	score += final_chain * rules.break_score_per_hit + life_bonus
	GameEvents.screen_flash_requested.emit(1.2)
	GameEvents.critical_break_landed.emit(self, final_chain, life_bonus)
	boss.critical_break()


func _take_hit() -> void:
	lives -= 1
	chain.drop()
	bullets.clear()
	invulnerable_time = config.respawn_invulnerability
	GameEvents.screen_flash_requested.emit(0.3)
	hit_taken.emit()
	if lives <= 0:
		is_dead = true
		hide()
		died.emit()


func _draw() -> void:
	var blinking := invulnerable_time > 0.0 and not laser.active and int(_blink * 20.0) % 2 == 0
	if not blinking:
		var color := config.color_ability if laser.active else config.color
		draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(10, 10), Vector2(-10, 10)]), color)
	# Hitbox is always visible (Readable Chaos pillar).
	draw_circle(Vector2.ZERO, config.hitbox_radius, Color.WHITE)
	draw_circle(Vector2.ZERO, config.hitbox_radius - 1.0, Color(1, 0.1, 0.1))
