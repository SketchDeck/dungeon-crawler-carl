class_name ExplosionEffect
extends Node2D
## Flash, expanding shock ring and flying debris. The ring ends at the blast
## radius, so players can see exactly how far an explosion reached.

var color := Color("#ff9a3c")
var radius := 90.0
var duration := 0.4

var _t := 0.0
var _debris: Array[Vector2] = []


func _ready() -> void:
	z_index = 50
	for i in 12:
		_debris.append(Vector2.from_angle(randf() * TAU) * randf_range(0.5, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	# Bright core that fades quickly.
	draw_circle(Vector2.ZERO, radius * (0.35 + 0.45 * ease_k), Color(color.lightened(0.4), maxf(0.0, 0.7 - k * 1.6)))
	draw_circle(Vector2.ZERO, radius * 0.25 * (1.0 - k), Color(1, 1, 0.9, 0.9 * (1.0 - k)))
	# Shock ring out to the full radius.
	draw_arc(Vector2.ZERO, radius * ease_k, 0.0, TAU, 40, Color(color, 1.0 - k), 4.0 * (1.0 - k) + 1.0)
	for d in _debris:
		draw_circle(d * radius * ease_k, 3.0 * (1.0 - k), Color(color.darkened(0.2), 1.0 - k))
