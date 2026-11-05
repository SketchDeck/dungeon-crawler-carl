class_name Shockwave
extends Area2D
## A ground shockwave that rolls along the floor. It hits a grounded player; jumping clears it.

var speed: float = 380.0
var dir: float = 1.0
var damage: int = Config.BRUTE_SLAM_DAMAGE
var range_left: float = 520.0
var _hit: bool = false
var _age: float = 0.0


static func spawn(world: Node, pos: Vector2, direction: float, reach: float, spd: float, dmg: int) -> Shockwave:
	var wave := Shockwave.new()
	wave.position = pos
	wave.dir = direction
	wave.range_left = reach
	wave.speed = spd
	wave.damage = dmg
	wave.z_index = 8
	wave.collision_layer = Config.LAYER_PROJECTILE
	wave.collision_mask = Config.LAYER_PLAYER
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26.0, 34.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0.0, -17.0)
	wave.add_child(collider)
	world.add_child(wave)
	wave.body_entered.connect(wave._on_body_entered)
	return wave


func _physics_process(delta: float) -> void:
	_age += delta
	var step := speed * delta
	position.x += dir * step
	range_left -= step
	if range_left <= 0.0:
		queue_free()
		return
	if int(_age * 30.0) % 3 == 0:
		Fx.burst(global_position + Vector2(0.0, -2.0), Color("#8a7a6a"), 2, 60.0, 0.35)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _hit or not (body is Player):
		return
	if not body.is_on_floor():
		return
	_hit = true
	var info := HitInfo.make(damage, Vector2(dir * 240.0, -200.0), self, "slam")
	body.receive_hit(info)


func _draw() -> void:
	var fade := clampf(range_left / 120.0, 0.0, 1.0)
	var dust := Color("#9a8a78", 0.55 * fade)
	draw_circle(Vector2(0.0, -6.0), 13.0, dust)
	draw_circle(Vector2(-8.0 * dir, -4.0), 9.0, Color("#8a7a68", 0.45 * fade))
	draw_circle(Vector2(6.0 * dir, -10.0), 7.0, Color("#b3a392", 0.4 * fade))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.0, 0.0), Vector2(0.0, -20.0), Vector2(6.0, 0.0),
	]), Color("#6b5d50", 0.9 * fade))
