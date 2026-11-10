class_name PotionPickup
extends Area2D
## A health potion lying in the world. Collected automatically on touch,
## unless the player already carries the maximum — then it stays put.

const GRAVITY := 1200.0
const RADIUS := 10.0

@export var pickup_delay := 0.35

var velocity := Vector2.ZERO

var _age := 0.0
var _grounded := false
var _full_notice_cd := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = HitQuery.LAYER_PLAYER
	z_index = 5


func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity
	_grounded = false


func _physics_process(delta: float) -> void:
	_age += delta
	_full_notice_cd = maxf(_full_notice_cd - delta, 0.0)
	if not _grounded:
		_fall(delta)
	queue_redraw()
	if _age < pickup_delay:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.health.is_dead:
			continue
		if player.potions.add():
			Audio.play("potion_pickup")
			Fx.burst(global_position, Color("#ff6b6b"), 20.0, 0.3)
			Fx.text(global_position + Vector2(0, -20), "+1 Potion", Color("#ff9090"), 14)
			queue_free()
			return
		if _full_notice_cd <= 0.0:
			_full_notice_cd = 2.0
			Fx.text(global_position + Vector2(0, -20), "Potions full (%d)" % player.potions.capacity, Color(1, 1, 1, 0.8), 13)


func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	var motion := velocity * delta
	var space := get_world_2d().direct_space_state
	var foot := global_position + Vector2(0, RADIUS)
	var query := PhysicsRayQueryParameters2D.create(foot - Vector2(0, 2), foot + motion, HitQuery.LAYER_WORLD)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		global_position += motion
		return
	var normal: Vector2 = hit["normal"]
	var point: Vector2 = hit["position"]
	if normal.y < -0.5:
		global_position = point - Vector2(0, RADIUS)
		velocity = Vector2.ZERO
		_grounded = true
	else:
		velocity.x = -velocity.x * 0.3
		global_position.y += motion.y


func _draw() -> void:
	var bob := sin(_age * 3.0) * 2.0 if _grounded else 0.0
	draw_circle(Vector2(0, bob), 14.0, Color(1, 0.3, 0.3, 0.12 + 0.06 * sin(_age * 5.0)))
	draw_flask(self, Vector2(0, bob), 1.0)


## Shared flask drawing (also used by the HUD icon).
static func draw_flask(canvas: CanvasItem, center: Vector2, s: float) -> void:
	canvas.draw_circle(center + Vector2(0, 3) * s, 7.0 * s, Color("#d8323a"))
	canvas.draw_rect(Rect2(center + Vector2(-3, -9) * s, Vector2(6, 7) * s), Color("#d8323a").lightened(0.3))
	canvas.draw_rect(Rect2(center + Vector2(-3.5, -12) * s, Vector2(7, 3.5) * s), Color("#8a5a2b"))
	canvas.draw_rect(Rect2(center + Vector2(-1, 0) * s, Vector2(2, 7) * s), Color.WHITE)
	canvas.draw_rect(Rect2(center + Vector2(-3.5, 2.5) * s, Vector2(7, 2) * s), Color.WHITE)
	canvas.draw_circle(center + Vector2(-3, 0) * s, 1.5 * s, Color(1, 1, 1, 0.6))
