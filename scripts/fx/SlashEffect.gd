class_name SlashEffect
extends Node2D
## Short arc showing where a melee attack landed.

var color := Color.WHITE
var radius := 30.0
var facing := 1
var duration := 0.12

var _t := 0.0


func _ready() -> void:
	z_index = 40


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var start := -PI * 0.45
	var finish := PI * 0.35
	if facing < 0:
		start = PI - finish
		finish = PI + PI * 0.45
	draw_arc(Vector2.ZERO, radius * (0.8 + 0.3 * k), start, finish, 16, Color(color, 1.0 - k), 5.0 * (1.0 - k) + 1.0)
