@tool
class_name SolidBlock
extends StaticBody2D
## Placeholder terrain: a rectangle (top-left origin) that builds its own
## collision and draws itself, in the editor and in game.
## One-way blocks can be jumped through from below.

@export var size := Vector2(128, 32):
	set(value):
		size = value
		_rebuild()
@export var one_way := false:
	set(value):
		one_way = value
		_rebuild()
@export var color := Color("#3b4a5e"):
	set(value):
		color = value
		queue_redraw()

var _shape_node: CollisionShape2D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		# Not given an owner, so it is never saved into the scene file.
		_shape_node = CollisionShape2D.new()
		add_child(_shape_node)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape_node.shape = rect
	_shape_node.position = size * 0.5
	_shape_node.one_way_collision = one_way
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if one_way:
		draw_rect(rect, Color(color, 0.55))
		draw_rect(Rect2(0, 0, size.x, 4), color.lightened(0.35))
	else:
		draw_rect(rect, color)
		draw_rect(Rect2(0, 0, size.x, 3), color.lightened(0.25))
		draw_rect(rect, color.darkened(0.35), false, 1.0)
