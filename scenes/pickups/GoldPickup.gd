class_name GoldPickup
extends Area2D
## Gold coins dropped by enemies. Collected on touch and added to the run's
## gold (RunStats), which you spend at safe-room shops.

const GRAVITY := 1200.0
const RADIUS := 8.0

var amount := 1
var velocity := Vector2.ZERO
var pickup_delay := 0.3

var _age := 0.0
var _grounded := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = HitQuery.LAYER_PLAYER
	z_index = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)


func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity
	_grounded = false


func _physics_process(delta: float) -> void:
	_age += delta
	if not _grounded:
		velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
		var motion := velocity * delta
		var foot := global_position + Vector2(0, RADIUS)
		var query := PhysicsRayQueryParameters2D.create(foot - Vector2(0, 2), foot + motion, HitQuery.LAYER_WORLD)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			global_position += motion
		else:
			global_position = (hit["position"] as Vector2) - Vector2(0, RADIUS)
			_grounded = true
	queue_redraw()
	if _age < pickup_delay:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.health.is_dead:
			continue
		var stats := get_tree().get_first_node_in_group(RunStats.GROUP) as RunStats
		if stats:
			stats.add_gold(amount)
		Audio.play("coin", -6.0)
		Fx.text(global_position + Vector2(0, -16), "+%d gold" % amount, Color("#ffd34d"), 13)
		queue_free()
		return


func _draw() -> void:
	var bob := 0.0 if not _grounded else sin(_age * 4.0) * 2.0
	var squeeze := absf(cos(_age * 5.0))
	draw_circle(Vector2(0, bob), RADIUS * 1.6, Color(1, 0.85, 0.3, 0.15))
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(maxf(squeeze, 0.25), 1.0))
	draw_circle(Vector2.ZERO, RADIUS, Color("#e0a020"))
	draw_circle(Vector2.ZERO, RADIUS * 0.7, Color("#ffd34d"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
