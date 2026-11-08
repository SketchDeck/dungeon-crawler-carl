class_name EnemyBase
extends CharacterBody2D
## Shared enemy health, damage, knockback, engagement and death.
## Subclasses implement _ai(delta) and drawing.

signal damaged(enemy: EnemyBase, amount: float)
signal died(enemy: EnemyBase)
signal engaged_changed(enemy: EnemyBase, is_engaged: bool)
## This enemy was knocked into `other` hard enough to hurt both.
signal collided(enemy: EnemyBase, other: EnemyBase)

## Name used in Dungeon AI announcements.
@export var display_name := "Goblin"
@export var max_health := 50.0
@export var body_size := Vector2(26, 40)
@export var gravity := 1500.0
@export var max_fall_speed := 900.0
@export_group("Knockback")
@export var knockback_multiplier := 1.0
## Minimum time an enemy stays in knockback (it also waits to land).
@export var knockback_min_time := 0.18
@export var knockback_friction := 1600.0
## While armored (e.g. mid-attack), hits below this damage don't interrupt.
@export var stagger_threshold := 15.0
@export_group("Enemy collisions")
## Knocked-back enemies moving at least this fast damage enemies they hit.
@export var collision_min_speed := 350.0
## Damage to the enemy that gets hit, and to the one that was thrown.
@export var collision_damage := 15.0
@export var collision_self_damage := 8.0
@export_group("Drops")
@export_range(0.0, 1.0) var potion_drop_chance := 0.2
@export_group("")
## Tests disable AI to keep enemies stationary.
@export var ai_enabled := true

var health := 0.0
var is_dead := false
var is_engaged := false
## The most recent hit taken (e.g. to credit a kill to spikes or a barrel).
var last_hit: Hit
var in_knockback := false
var facing := -1

var _knockback_t := 0.0
var _flash_t := 0.0
var _death_t := 0.0
var _player: Player
## Enemies already hit during the current knockback (no repeat damage).
var _collided := {}
var rng := RandomNumberGenerator.new()

const DEATH_DURATION := 0.7
const POTION_SCENE := preload("res://scenes/pickups/PotionPickup.tscn")


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	rng.randomize()


func get_player() -> Player:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func _physics_process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	if is_dead:
		_death_t += delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
		move_and_slide()
		queue_redraw()
		if _death_t >= DEATH_DURATION:
			queue_free()
		return

	if in_knockback:
		if absf(velocity.x) >= collision_min_speed:
			_check_enemy_collisions()
		_knockback_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
			if _knockback_t <= 0.0:
				in_knockback = false
				_on_knockback_end()
	elif ai_enabled:
		_ai(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)

	move_and_slide()
	queue_redraw()


func take_hit(hit: Hit) -> void:
	if is_dead:
		return
	var amount := maxf(hit.damage, 0.0)
	last_hit = hit
	health = maxf(health - amount, 0.0)
	_flash_t = 0.1
	Audio.play("hit", -3.0)
	damaged.emit(self, amount)
	Fx.text(global_position + Vector2(0, -body_size.y * 0.5 - 12), str(roundi(amount)),
		Color("#ffd34d") if hit.has_tag("heavy") else Color.WHITE, 18 if hit.has_tag("heavy") else 15)
	Fx.burst(global_position, Color("#ffe6a0"), 18.0, 0.18)
	set_engaged(true)
	if health <= 0.0:
		die(hit)
		return
	if is_armored() and amount < stagger_threshold:
		return
	apply_knockback(hit.knockback)


func apply_knockback(knockback: Vector2) -> void:
	if knockback == Vector2.ZERO:
		return
	velocity = knockback * knockback_multiplier
	in_knockback = true
	_collided.clear()
	_knockback_t = knockback_min_time
	_on_interrupted()


func die(hit: Hit = null) -> void:
	if is_dead:
		return
	is_dead = true
	in_knockback = false
	# Stop being targetable/hittable; keep colliding with the world while the body falls.
	collision_layer = 0
	if hit:
		velocity = hit.knockback * knockback_multiplier
	set_engaged(false)
	Audio.play("enemy_death", -2.0)
	_on_died()
	Fx.burst(global_position, body_color(), 34.0, 0.35)
	if should_drop_potion(rng.randf()):
		drop_potion()
	died.emit(self)
	GameManager.enemy_died.emit(self)


func should_drop_potion(roll: float) -> bool:
	return roll < potion_drop_chance


func drop_potion() -> PotionPickup:
	var potion := POTION_SCENE.instantiate() as PotionPickup
	potion.position = position + Vector2(0, -10)
	potion.launch(Vector2(rng.randf_range(-60, 60), -260))
	# Deferred: deaths happen during physics callbacks.
	get_parent().add_child.call_deferred(potion)
	return potion


func set_engaged(value: bool) -> void:
	if value == is_engaged or (value and is_dead):
		return
	is_engaged = value
	engaged_changed.emit(self, value)
	var player := get_player()
	if player:
		player.combat_state.set_enemy_engaged(self, value)


func _check_enemy_collisions() -> void:
	var dir := signf(velocity.x)
	for body in HitQuery.box(self, global_position + Vector2(dir * 4.0, 0), body_size + Vector2(8, 0), HitQuery.LAYER_ENEMIES):
		var other := body as EnemyBase
		if other == null or other == self or other.is_dead or _collided.has(other.get_instance_id()):
			continue
		_collided[other.get_instance_id()] = true
		var speed := absf(velocity.x)
		var tags := PackedStringArray(["collision"])
		other.take_hit(Hit.new(collision_damage, Vector2(dir * speed * 0.6, -220), self, tags))
		# The thrown enemy can't bounce straight back into the one it hit.
		other._collided[get_instance_id()] = true
		velocity.x *= 0.5
		Fx.text((global_position + other.global_position) * 0.5 + Vector2(0, -36), "BONK!", Color("#ffb347"), 18)
		Fx.shake(0.3)
		collided.emit(self, other)
		GameManager.enemy_collided.emit(self, other)
		take_hit(Hit.new(collision_self_damage, Vector2.ZERO, self, tags))
		if is_dead:
			return


# --- Helpers for subclasses -------------------------------------------------

func is_ledge_ahead(dir: int) -> bool:
	if not is_on_floor():
		return false
	var from := global_position + Vector2(dir * (body_size.x * 0.5 + 6.0), 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, body_size.y * 0.5 + 20.0), HitQuery.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func is_wall_ahead(dir: int) -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -dir


func hit_flash() -> float:
	return _flash_t


func death_progress() -> float:
	return _death_t / DEATH_DURATION


# --- Overridables -----------------------------------------------------------

func _ai(_delta: float) -> void:
	pass


## True while the enemy shrugs off light hits (no knockback/interrupt).
func is_armored() -> bool:
	return false


func _on_interrupted() -> void:
	pass


func _on_knockback_end() -> void:
	pass


func _on_died() -> void:
	pass


func body_color() -> Color:
	return Color.WHITE
