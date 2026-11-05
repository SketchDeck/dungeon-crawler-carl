class_name TutorialSign
extends Node2D
## A wooden sign with a short hint. The hint appears when the player comes close.

const REVEAL_RANGE := 230.0

var text: String = ""
var _age: float = 0.0


static func spawn(parent: Node, pos: Vector2, message: String) -> TutorialSign:
	var sign_node := TutorialSign.new()
	sign_node.position = pos
	sign_node.text = message
	sign_node.z_index = 3
	parent.add_child(sign_node)
	return sign_node


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 16.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-3.0, -56.0, 6.0, 56.0), Color("#5a3b22"))
	draw_rect(Rect2(-30.0, -88.0, 60.0, 34.0), Color("#8a5a2e"))
	draw_rect(Rect2(-27.0, -85.0, 54.0, 28.0), Color("#a77340"))
	draw_rect(Rect2(-30.0, -88.0, 60.0, 34.0), Color("#3b2612"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-30.0, -66.0), "i", HORIZONTAL_ALIGNMENT_CENTER, 60, 20,
		Color("#ffe27a"))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > REVEAL_RANGE:
		return
	var width := 300.0
	var lines := maxi(1, ceili(float(text.length()) * 7.4 / (width - 24.0)))
	var height := 26.0 + float(lines) * 18.0
	var top := -96.0 - height
	var panel := Rect2(-width * 0.5, top, width, height)
	draw_rect(panel, Color(0.05, 0.03, 0.09, 0.9))
	draw_rect(panel, Color(1.0, 0.7, 0.28, 0.7), false, 1.5)
	draw_multiline_string(ThemeDB.fallback_font, Vector2(-width * 0.5 + 12.0, top + 20.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, width - 24.0, 13, -1, Color("#f1ecff"))
