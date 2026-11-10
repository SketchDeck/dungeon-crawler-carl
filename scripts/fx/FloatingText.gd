class_name FloatingText
extends Node2D
## Rising, fading text (damage numbers etc.).

var message := ""
var color := Color.WHITE
var font_size := 16
var duration := 0.7

var _t := 0.0


func _ready() -> void:
	z_index = 60


func _process(delta: float) -> void:
	_t += delta
	position.y -= 40.0 * delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var alpha := clampf(1.5 - _t / duration * 1.5, 0.0, 1.0)
	var pos := Vector2(-40, 0)
	draw_string_outline(font, pos, message, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, 4, Color(0, 0, 0, alpha))
	draw_string(font, pos, message, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, Color(color, alpha))
