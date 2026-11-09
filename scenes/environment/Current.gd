class_name Current
extends Node2D
## Sewer water current: a strip of solid floor whose surface flows sideways,
## carrying anyone standing on it (player and enemies) at `speed` px/s.
## Positioned at the strip's top-left; `size` is in pixels.

var size := Vector2(96, 32)
## Positive flows right, negative flows left.
var speed := 140.0

var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var top := global_position.y
	for node in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		var body := node as CharacterBody2D
		if body == null or not body.is_on_floor():
			continue
		if body is EnemyBase and ((body as EnemyBase).is_dead or (body as EnemyBase).flying):
			continue
		var feet := body.global_position.y + feet_offset(body)
		var x := body.global_position.x
		if absf(feet - top) <= 6.0 and x >= global_position.x - 4.0 and x <= global_position.x + size.x + 4.0:
			body.move_and_collide(Vector2(speed * delta, 0.0))


static func feet_offset(body: CharacterBody2D) -> float:
	if body is EnemyBase:
		return (body as EnemyBase).body_size.y * 0.5
	return 28.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 8)), Color("#2f8a8a"))
	draw_rect(Rect2(Vector2(0, 8), Vector2(size.x, size.y - 8)), Color("#24505a"))
	# Ripples flowing with the current.
	var dir := signf(speed)
	var step := 24.0
	var off := fmod(_t * absf(speed), step)
	var x := -step + off
	while x < size.x:
		var px := x if dir > 0 else size.x - x
		if px >= 0.0 and px <= size.x - 8.0:
			draw_line(Vector2(px, 3), Vector2(px + 8.0 * dir, 3), Color(0.7, 1, 1, 0.6), 2.0)
		x += step
