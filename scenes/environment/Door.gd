class_name Door
extends Node2D
## Room exit. Walking into an unlocked door requests a transition; a locked
## door is a solid barrier with bars across it.

signal entered(door: Door)

const SIZE := Vector2(44, 80)

var exit_index := 0
## Destination room id (for display only; the room manager validates exits).
var target_label := ""
var locked := false

var _area: Area2D
var _barrier: StaticBody2D
var _t := 0.0


func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = HitQuery.LAYER_PLAYER
	_area.add_child(_rect_shape(Vector2(SIZE.x - 20.0, SIZE.y)))
	add_child(_area)
	_barrier = StaticBody2D.new()
	_barrier.collision_mask = 0
	_barrier.add_child(_rect_shape(SIZE))
	add_child(_barrier)
	_apply_lock()


func set_locked(value: bool) -> void:
	locked = value
	if is_inside_tree():
		_apply_lock()


func _apply_lock() -> void:
	_barrier.collision_layer = HitQuery.LAYER_WORLD if locked else 0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if locked:
		return
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player and not player.health.is_dead:
			entered.emit(self)
			return


func _rect_shape(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y * 0.5)
	return shape


func _draw() -> void:
	var r := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	draw_rect(r.grow(4), Color("#5a4632"))
	draw_rect(r, Color("#0b0d12"))
	if locked:
		for i in 4:
			var x := r.position.x + 7.0 + i * 10.0
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("#b03a3a"), 4.0)
		draw_rect(Rect2(-7, -46, 14, 12), Color("#d8b040"))
	else:
		var glow := 0.25 + 0.15 * sin(_t * 3.0)
		draw_rect(r.grow(-4), Color(0.45, 1.0, 0.6, glow * 0.35))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-SIZE.x * 0.5, -SIZE.y * 0.5 + 6), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 12, Color(0.7, 1.0, 0.75, 0.9))
