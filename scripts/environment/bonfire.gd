class_name Bonfire
extends Node2D
## A safe-room bonfire. Press E near it once per visit to restore health.

const HEAL := 50

var room: RoomBase = null
var used: bool = false
var _age: float = 0.0


static func spawn(parent: Node, pos: Vector2) -> Bonfire:
	var fire := Bonfire.new()
	fire.position = pos
	fire.z_index = 4
	fire.room = parent as RoomBase
	parent.add_child(fire)
	if fire.room != null:
		fire.room.register_interactable(fire)
	return fire


func can_interact(player_pos: Vector2) -> bool:
	return not used and global_position.distance_to(player_pos) < 80.0


func interact(_room_ref: RoomBase) -> void:
	if used or room == null:
		return
	used = true
	room.interact_requested.emit(room, "bonfire")


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var lit := 0.35 if used else 1.0
	var flicker := sin(_age * 17.0) * 0.5 + sin(_age * 9.0) * 0.5
	draw_circle(Vector2(0.0, -16.0), 54.0, Color(1.0, 0.55, 0.2, (0.07 + 0.02 * flicker) * lit))
	draw_circle(Vector2(0.0, -14.0), 30.0, Color(1.0, 0.7, 0.3, (0.1 + 0.04 * flicker) * lit))
	draw_set_transform(Vector2(0.0, 14.0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2(-22.0, 2.0), Vector2(44.0, 14.0)), Color("#4a4658"))
	draw_rect(Rect2(Vector2(-22.0, 2.0), Vector2(44.0, 3.0)), Color("#6b6880"))
	draw_line(Vector2(-16.0, 8.0), Vector2(14.0, -4.0), Color("#5b3a1e"), 5.0, true)
	draw_line(Vector2(16.0, 8.0), Vector2(-12.0, -2.0), Color("#6d4624"), 5.0, true)
	if not used:
		var h := 26.0 + flicker * 3.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-14.0, 0.0), Vector2(-8.0, -h * 0.6), Vector2(-2.0, -h), Vector2(4.0, -h * 0.55), Vector2(14.0, 0.0),
		]), Color("#ff8a3c"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(-3.0, -h * 0.5), Vector2(1.0, -h * 0.75), Vector2(7.0, 0.0),
		]), Color("#ffd166"))
		for i in range(4):
			var t := fposmod(_age * 0.7 + i * 0.25, 1.0)
			var ember := Vector2(sin(i * 2.3 + _age) * 8.0, -h - t * 36.0)
			draw_circle(ember, 1.6, Color(1.0, 0.8, 0.4, 1.0 - t))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-30.0, -34.0), "embers", HORIZONTAL_ALIGNMENT_CENTER, 60, 12,
			Color(0.8, 0.7, 0.6, 0.6))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and can_interact(player.global_position):
		draw_rect(Rect2(Vector2(-16.0, -50.0), Vector2(32.0, 16.0)), Color(0.05, 0.04, 0.08, 0.85))
		draw_rect(Rect2(Vector2(-16.0, -50.0), Vector2(32.0, 16.0)), Color("#ffb347"), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-16.0, -38.0), "E", HORIZONTAL_ALIGNMENT_CENTER, 32, 13, Color("#ffb347"))
