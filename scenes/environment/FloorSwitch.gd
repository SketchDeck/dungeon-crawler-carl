class_name FloorSwitch
extends StaticBody2D
## Puzzle switch activated by any player attack. Lives on the "hittable" layer,
## so it is struck by attacks but never blocks movement.

signal activated(switch: FloorSwitch)

var is_on := false


func _ready() -> void:
	collision_layer = HitQuery.LAYER_HITTABLE
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 46)
	shape.shape = rect
	shape.position = Vector2(0, -23)
	add_child(shape)


func take_hit(_hit: Hit) -> void:
	if is_on:
		return
	is_on = true
	Fx.burst(global_position + Vector2(0, -40), Color("#7dff8a"), 22.0, 0.3)
	Fx.text(global_position + Vector2(0, -60), "Click!", Color("#7dff8a"), 14)
	queue_redraw()
	activated.emit(self)


func _draw() -> void:
	draw_rect(Rect2(-10, -6, 20, 6), Color("#4a505c"))
	draw_rect(Rect2(-3, -36, 6, 30), Color("#8a909c"))
	var lamp := Color("#5dff70") if is_on else Color("#ff4a4a")
	draw_circle(Vector2(0, -40), 8.0, lamp.darkened(0.3))
	draw_circle(Vector2(0, -40), 5.5, lamp)
	if not is_on:
		draw_circle(Vector2(0, -40), 12.0, Color(1, 0.3, 0.3, 0.15))
