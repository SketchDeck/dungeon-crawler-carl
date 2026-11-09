class_name KickWave
extends Node2D
## Seismic Stomp's shockwave: runs along the floor from Carl's feet, hits each
## enemy (or switch/crate) it passes once, and stops at walls.

var direction := 1
var speed := 420.0
var max_range := 260.0
var height := 30.0
var hit: Hit
var mask := HitQuery.LAYER_ENEMIES | HitQuery.LAYER_HITTABLE

var travelled := 0.0
var _hit := {}
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var step := speed * delta
	position.x += direction * step
	travelled += step
	if travelled >= max_range or _hits_wall():
		queue_free()
		return
	for body in HitQuery.box(self, global_position + Vector2(0, -height * 0.5), Vector2(28, height), mask):
		if not body.has_method("take_hit") or _hit.has(body.get_instance_id()):
			continue
		_hit[body.get_instance_id()] = true
		body.take_hit(hit)
	queue_redraw()


func _hits_wall() -> bool:
	for body in HitQuery.circle(self, global_position + Vector2(direction * 12.0, -14.0), 6.0, HitQuery.LAYER_WORLD):
		if not (body is SolidBlock and (body as SolidBlock).one_way):
			return true
	return false


func _draw() -> void:
	var fade := clampf((max_range - travelled) / (max_range * 0.25), 0.0, 1.0)
	var hot := Color(1.0, 0.7, 0.3, 0.9 * fade)
	var rock := Color(1.0, 0.55, 0.25, 0.7 * fade)
	for i in 3:
		var x := -direction * i * 9.0
		var h := height * (1.0 - i * 0.25) * (0.85 + 0.15 * sin(_t * 40.0 + i))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 6, 0), Vector2(x + direction * 2, -h), Vector2(x + 6, 0)]), hot if i == 0 else rock)
