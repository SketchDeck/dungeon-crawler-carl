class_name RoomSign
extends Node2D
## Wooden sign that shows its text when the player is close.

const SHOW_DISTANCE := 130.0
const TEXT_WIDTH := 280.0
const FONT_SIZE := 14

var text := ""

var _alpha := 0.0
var _player: Player


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var near := _player != null and absf(_player.global_position.x - global_position.x) < SHOW_DISTANCE \
		and absf(_player.global_position.y - global_position.y) < 120.0
	_alpha = move_toward(_alpha, 1.0 if near else 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var wood := Color("#8a5a2b")
	draw_rect(Rect2(-3, -30, 6, 30), wood.darkened(0.2))
	draw_rect(Rect2(-16, -40, 32, 18), wood)
	draw_rect(Rect2(-12, -35, 24, 2), wood.lightened(0.3))
	draw_rect(Rect2(-12, -30, 18, 2), wood.lightened(0.3))
	if _alpha <= 0.0 or text == "":
		return
	var font := ThemeDB.fallback_font
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, FONT_SIZE)
	var box := Rect2(-size.x * 0.5 - 10, -52 - size.y - 10, size.x + 20, size.y + 12)
	# Keep the bubble inside the room (rooms start at x = 0, inside a 32px wall).
	box.position.x = maxf(box.position.x, 40.0 - position.x)
	draw_rect(box, Color(0.05, 0.06, 0.09, 0.85 * _alpha))
	draw_rect(box, Color(0.85, 0.65, 0.35, 0.8 * _alpha), false, 2.0)
	draw_multiline_string(font, Vector2(box.position.x + 10, box.position.y + 6 + font.get_ascent(FONT_SIZE)), text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, -1, Color(1, 1, 1, _alpha))
