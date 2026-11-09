class_name Fountain
extends Interactable
## Safe-room healing fountain: restores full health, once per floor run. If
## the Dungeon AI has given you loot boxes, the fountain opens those first.

signal used

var dry := false


func run_stats() -> RunStats:
	return get_tree().get_first_node_in_group(RunStats.GROUP) as RunStats


func prompt() -> String:
	var stats := run_stats()
	if stats and stats.has_boxes():
		var n := stats.boxes.size()
		return "Open %d loot box%s" % [n, "" if n == 1 else "es"]
	return "" if dry else "Drink from fountain"


func interact() -> bool:
	var stats := run_stats()
	if stats and stats.has_boxes():
		stats.loot_requested.emit()
		return true
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
	var stats := run_stats()
	if stats and stats.has_boxes():
		# A loot box bobbing over the fountain.
		var c := Achievements.tier_color(stats.boxes.max())
		var at := Vector2(0, -84 + sin(_t * 3.0) * 4.0)
		draw_circle(at, 18.0, Color(c, 0.15))
		draw_rect(Rect2(at - Vector2(10, 6), Vector2(20, 14)), c.darkened(0.25))
		draw_rect(Rect2(at - Vector2(12, 10), Vector2(24, 5)), c)
		draw_rect(Rect2(at - Vector2(2, 10), Vector2(4, 18)), Color(1, 1, 1, 0.8))
	draw_prompt(66.0 if not (stats and stats.has_boxes()) else 108.0)
