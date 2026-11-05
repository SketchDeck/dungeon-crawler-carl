extends Node2D

const ROOM := Rect2(32, 64, 896, 544)
const PLAYER_RADIUS := 14.0
const SPEED := 240.0

var player_position := ROOM.get_center()


func _process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	direction = (direction + wasd).limit_length()
	player_position += direction * SPEED * delta
	player_position = player_position.clamp(
		ROOM.position + Vector2.ONE * PLAYER_RADIUS,
		ROOM.end - Vector2.ONE * PLAYER_RADIUS
	)
	queue_redraw()


func _draw() -> void:
	draw_rect(ROOM, Color("#202b3b"))
	draw_rect(ROOM, Color("#53657c"), false, 2.0)
	draw_circle(player_position, PLAYER_RADIUS, Color("#f4bd50"))
