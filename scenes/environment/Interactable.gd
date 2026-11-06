class_name Interactable
extends Node2D
## Base for objects the player uses with the Interact button when nearby.

@export var interact_radius := 60.0

var _t := 0.0
var _player: Player


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var p := get_player()
	if p and p.read_input and is_player_near(p) and Input.is_action_just_pressed("interact"):
		interact()


func get_player() -> Player:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func is_player_near(p: Player) -> bool:
	return not p.health.is_dead and p.global_position.distance_to(global_position + Vector2(0, -24)) <= interact_radius


## Draws "[E] <prompt>" above the object while the player is in range.
func draw_prompt(height := 56.0) -> void:
	var p := get_player()
	var text := prompt()
	if p == null or text == "" or not is_player_near(p):
		return
	var font := ThemeDB.fallback_font
	var pos := Vector2(-80, -height)
	draw_string_outline(font, pos, "[E] " + text, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color.BLACK)
	draw_string(font, pos, "[E] " + text, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(1, 1, 1, 0.9))


# --- Overridables -----------------------------------------------------------

func prompt() -> String:
	return ""


## Returns true if the interaction did something.
func interact() -> bool:
	return false
