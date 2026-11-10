class_name MovingPlatform
extends AnimatableBody2D
## A sewer lift: a one-way platform that slides back and forth along its
## track (from `from_x` to `to_x`, in the parent's space), carrying whoever
## stands on it.

var width := 96.0
var from_x := 0.0
var to_x := 200.0
var speed := 70.0
var pause_time := 0.6

var _dir := 1
var _pause := 0.0


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	add_to_group("one_way_platforms")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 12)
	shape.shape = rect
	shape.position = Vector2(width * 0.5, 6)
	shape.one_way_collision = true
	add_child(shape)


func _physics_process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	var target := to_x if _dir > 0 else from_x
	position.x = move_toward(position.x, target, speed * delta)
	if is_equal_approx(position.x, target):
		_dir = -_dir
		_pause = pause_time
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, width, 12), Color("#8a8f96"))
	draw_rect(Rect2(0, 0, width, 3), Color("#c0c6cc"))
	for x in [8.0, width - 8.0]:
		draw_circle(Vector2(x, 6), 2.5, Color("#ffd34d"))
