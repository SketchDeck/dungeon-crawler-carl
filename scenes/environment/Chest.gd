class_name Chest
extends Interactable
## Challenge-room reward chest. Locked until the room's trial is complete.

signal opened

var locked := true
var is_open := false


func prompt() -> String:
	if is_open:
		return ""
	return "Locked" if locked else "Open chest"


func interact() -> bool:
	if is_open:
		return false
	if locked:
		Fx.text(global_position + Vector2(0, -60), "Complete the trial first", Color(1, 1, 1, 0.85), 13)
		return false
	is_open = true
	Audio.play("chest")
	Fx.burst(global_position + Vector2(0, -14), Color("#ffd34d"), 40.0, 0.45)
	Fx.shake(0.2)
	opened.emit()
	return true


func unlock() -> void:
	if locked:
		locked = false
		Fx.burst(global_position + Vector2(0, -14), Color("#ffd34d"), 26.0, 0.3)


func _draw() -> void:
	var wood := Color("#7a4a24")
	var gold := Color("#e8b838")
	# Glow when ready to open.
	if not locked and not is_open:
		draw_circle(Vector2(0, -12), 30.0, Color(1, 0.85, 0.3, 0.12 + 0.08 * sin(_t * 4.0)))
	draw_rect(Rect2(-18, -20, 36, 20), wood)
	draw_rect(Rect2(-18, -20, 36, 20), gold, false, 2.0)
	if is_open:
		draw_rect(Rect2(-18, -34, 36, 8), wood.darkened(0.2))
		draw_rect(Rect2(-14, -20, 28, 4), Color(1, 0.9, 0.5, 0.9))
	else:
		draw_rect(Rect2(-18, -30, 36, 11), wood.lightened(0.1))
		draw_rect(Rect2(-18, -30, 36, 11), gold, false, 2.0)
		draw_rect(Rect2(-4, -22, 8, 8), gold if not locked else Color("#888888"))
		if locked:
			draw_arc(Vector2(0, -23), 4.0, PI, TAU, 8, Color("#888888"), 2.0)
	draw_prompt(48.0)
