class_name Fountain
extends Interactable
## Safe-room healing fountain: restores full health, once per floor run.

signal used

var dry := false


func prompt() -> String:
	return "" if dry else "Drink from fountain"


func interact() -> bool:
	var p := get_player()
	if dry or p == null or p.health.is_dead:
		return false
	if p.health.current >= p.health.max_health:
		Fx.text(global_position + Vector2(0, -64), "Already at full health", Color(1, 1, 1, 0.85), 13)
		return false
	var healed := p.health.heal(p.health.max_health)
	dry = true
	Fx.burst(p.global_position, Color("#7ad8ff"), 36.0, 0.4)
	Fx.text(p.global_position + Vector2(0, -52), "+%d" % roundi(healed), Color("#7dff8a"), 18)
	Audio.play("heal")
	used.emit()
	return true


func _draw() -> void:
	var stone := Color("#6c7484")
	draw_rect(Rect2(-26, -18, 52, 18), stone)
	draw_rect(Rect2(-30, -22, 60, 6), stone.lightened(0.15))
	draw_rect(Rect2(-5, -46, 10, 26), stone)
	draw_circle(Vector2(0, -48), 9.0, stone.lightened(0.1))
	if not dry:
		draw_rect(Rect2(-24, -18, 48, 6), Color("#4aa8e0"))
		for i in 3:
			var k := fmod(_t * 1.5 + i / 3.0, 1.0)
			draw_circle(Vector2(-6 + i * 6, -50 + k * 30.0), 2.0, Color(0.6, 0.85, 1.0, 1.0 - k))
	draw_prompt(66.0)
