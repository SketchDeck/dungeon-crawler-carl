class_name GameCamera
extends Camera2D
## Follow camera with trauma-based screen shake and room limits.

@export var shake_decay := 2.5
@export var max_shake_offset := Vector2(12, 9)

var _trauma := 0.0


func _ready() -> void:
	Fx.camera = self


func _exit_tree() -> void:
	if Fx.camera == self:
		Fx.camera = null


func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func set_room_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	reset_smoothing()


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var s := _trauma * _trauma
	offset = Vector2(randf_range(-1, 1) * max_shake_offset.x * s, randf_range(-1, 1) * max_shake_offset.y * s)
