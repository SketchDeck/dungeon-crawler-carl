class_name BurstEffect
extends Node2D
## Expanding ring with sparks. Used for hits, deaths and other impacts.

var color := Color.WHITE
var radius := 22.0
var duration := 0.25

var _t := 0.0
var _sparks: Array[Vector2] = []


func _ready() -> void:
	z_index = 50
	for i in 7:
		_sparks.append(Vector2.from_angle(randf() * TAU) * randf_range(0.6, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var c := Color(color, 1.0 - k)
	draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * k), 0.0, TAU, 24, c, 3.0)
	for s in _sparks:
		draw_line(s * radius * (0.2 + k), s * radius * (0.5 + k * 1.3), c, 2.0)
