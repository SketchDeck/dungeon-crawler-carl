class_name ShapeFx
extends Node2D
## A short-lived drawn effect (expanding ring, soft glow, or flash). Frees itself when done.

var kind: String = "ring"
var color: Color = Color.WHITE
var radius: float = 60.0
var width: float = 4.0
var life: float = 0.3
var _age: float = 0.0


func _ready() -> void:
	z_index = 60
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	match kind:
		"ring":
			var r := lerpf(radius * 0.15, radius, ease(t, 0.35))
			var c := Color(color.r, color.g, color.b, 1.0 - t)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, width * (1.0 - t * 0.6) + 0.5, true)
		"glow":
			var a := 1.0 - t
			for i in range(4):
				var k := 1.0 - i * 0.22
				var rr := radius * k * (0.55 + 0.45 * t)
				draw_circle(Vector2.ZERO, rr, Color(color.r, color.g, color.b, 0.2 * a))
		"flash":
			var fr := radius * (0.6 + 0.9 * t)
			draw_circle(Vector2.ZERO, fr, Color(color.r, color.g, color.b, 0.55 * (1.0 - t)))
