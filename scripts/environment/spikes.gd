class_name Spikes
extends Area2D
## Floor spikes. Hurt the player on contact, and kill enemies that are knocked into them.

var _rect: Rect2 = Rect2()
var _cooldowns: Dictionary = {}
var _age: float = 0.0


static func spawn(parent: Node, rect: Rect2) -> Spikes:
	var spikes := Spikes.new()
	spikes._rect = rect
	spikes.position = rect.position
	spikes.z_index = 2
	spikes.collision_layer = Config.LAYER_HAZARD
	spikes.collision_mask = Config.LAYER_PLAYER | Config.LAYER_ENEMY
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.size * 0.5
	spikes.add_child(collider)
	parent.add_child(spikes)
	return spikes


func _physics_process(delta: float) -> void:
	_age += delta
	for key in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			_cooldowns.erase(key)
	for body in get_overlapping_bodies():
		var id: int = body.get_instance_id()
		if _cooldowns.has(id):
			continue
		if body is Player:
			if not body.alive:
				continue
			var info := HitInfo.make(Config.SPIKE_DAMAGE, Vector2(0.0, -200.0), self, "hazard")
			info.environmental = true
			if body.receive_hit(info):
				_cooldowns[id] = 0.8
		elif body is EnemyBase and not body.dead:
			var info := HitInfo.make(Config.SPIKE_DAMAGE, Vector2.ZERO, self, "hazard")
			info.environmental = true
			if body.receive_hit(info):
				_cooldowns[id] = 0.5
	queue_redraw()


func _draw() -> void:
	var count := maxi(1, int(_rect.size.x / 12.0))
	var step := _rect.size.x / float(count)
	var glint := 0.5 + 0.5 * sin(_age * 3.0)
	for i in range(count):
		var x := i * step
		var base_l := Vector2(x, _rect.size.y)
		var base_r := Vector2(x + step, _rect.size.y)
		var apex := Vector2(x + step * 0.5, 0.0)
		draw_colored_polygon(PackedVector2Array([base_l, apex, base_r]), Color("#9aa6b8"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + step * 0.5, 2.0), Vector2(x + step * 0.5 + 2.0, _rect.size.y), base_r]),
			Color("#5f6b7d"))
		draw_line(base_l, apex, Color("#dfe6f0"), 1.0, true)
		draw_line(apex, base_r, Color(0.1, 0.1, 0.14, 0.9), 1.0, true)
	draw_rect(Rect2(Vector2(0.0, _rect.size.y - 2.0), _rect.size), Color("#2b2d36"))
	draw_circle(Vector2(_rect.size.x * 0.5, -2.0), 10.0, Color(1.0, 0.45, 0.4, 0.04 + 0.03 * glint))
