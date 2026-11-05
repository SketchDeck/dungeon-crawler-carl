class_name Puddle
extends Area2D
## Temporary hazardous goo left behind by the Mutating Slime. Hurts the player on contact
## and fades away after a few seconds.

const LIFETIME := 4.5

var _age: float = 0.0
var _cooldown: float = 0.0
var _radius: float = 40.0


static func spawn(parent: Node, pos: Vector2, radius: float = 42.0) -> Puddle:
	var puddle := Puddle.new()
	puddle.position = pos
	puddle._radius = radius
	puddle.z_index = 2
	puddle.collision_layer = Config.LAYER_HAZARD
	puddle.collision_mask = Config.LAYER_PLAYER
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius * 1.6, 14.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0.0, -4.0)
	puddle.add_child(collider)
	parent.add_child(puddle)
	return puddle


func _physics_process(delta: float) -> void:
	_age += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if _age >= LIFETIME:
		queue_free()
		return
	if _cooldown <= 0.0:
		for body in get_overlapping_bodies():
			if body is Player and body.alive:
				var info := HitInfo.make(Config.MUTANT_SLAM_DAMAGE / 2, Vector2(0.0, -120.0), self, "hazard")
				info.environmental = true
				body.receive_hit(info)
				_cooldown = 0.6
				break
	queue_redraw()


func _draw() -> void:
	var fade := clampf(minf(_age / 0.3, (LIFETIME - _age) / 0.8), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)
	var goo := Color("#b657d6")
	draw_set_transform(Vector2(0.0, 0.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2(0.0, 6.0), _radius * 1.1, Color(goo.r, goo.g, goo.b, 0.35 * fade))
	draw_circle(Vector2(0.0, 4.0), _radius * 0.85, Color(goo.r, goo.g, goo.b, 0.6 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(3):
		var bx := -_radius * 0.5 + i * _radius * 0.5
		draw_circle(Vector2(bx, -2.0 - pulse * 3.0), 3.0 + i, Color(1.0, 0.8, 1.0, 0.5 * fade))
