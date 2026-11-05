class_name TreasureChest
extends Node2D
## Treasure chest. In a challenge room it unlocks when the room is cleared. Stand near it and press
## E to open it and choose one of three temporary upgrades.

var room: RoomBase = null
var available: bool = false
var opened: bool = false
var _age: float = 0.0
var _open: float = 0.0


static func spawn(parent: Node, pos: Vector2, is_available: bool, already_opened: bool) -> TreasureChest:
	var chest := TreasureChest.new()
	chest.position = pos
	chest.z_index = 4
	chest.available = is_available
	chest.opened = already_opened
	chest.room = parent as RoomBase
	parent.add_child(chest)
	if chest.room != null:
		chest.room.register_interactable(chest)
	return chest


func can_interact(player_pos: Vector2) -> bool:
	return available and not opened and global_position.distance_to(player_pos) < 80.0


func interact(_room_ref: RoomBase) -> void:
	if room != null and available and not opened:
		room.interact_requested.emit(room, "treasure")


## Called by RoomBase when the room's encounter is cleared.
func on_room_cleared() -> void:
	if not opened:
		available = true


## Called once an upgrade has been chosen.
func open() -> void:
	if opened:
		return
	opened = true
	available = false
	_open = 1.0
	Fx.burst(global_position + Vector2(0.0, -20.0), Color("#ffd166"), 40, 380.0, 0.8)
	Fx.glow(global_position + Vector2(0.0, -20.0), Color("#ffd166"), 60.0, 0.6)
	Fx.shake(6.0)


func _process(delta: float) -> void:
	_age += delta
	_open = maxf(0.0, _open - delta * 1.2)
	modulate = Color.WHITE if (available or opened) else Color(0.45, 0.45, 0.5)
	queue_redraw()


func _draw() -> void:
	var wood := Color("#7a4a26")
	var wood_dark := Color("#4f2e17")
	var gold := Color("#ffd166")
	var pulse := 0.5 + 0.5 * sin(_age * 3.0)
	if available and not opened:
		draw_circle(Vector2(0.0, -10.0), 30.0, Color(1.0, 0.82, 0.4, 0.05 + 0.04 * pulse))
	draw_set_transform(Vector2(0.0, 14.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 26.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2(-22.0, -14.0), Vector2(44.0, 26.0)), wood)
	draw_rect(Rect2(Vector2(-22.0, -14.0), Vector2(44.0, 26.0)), wood_dark, false, 2.0)
	draw_rect(Rect2(Vector2(-22.0, -3.0), Vector2(44.0, 3.0)), gold)
	draw_rect(Rect2(Vector2(-4.0, -6.0), Vector2(8.0, 10.0)), gold)
	var lift := _open * 14.0
	var lid := PackedVector2Array([
		Vector2(-22.0, -14.0), Vector2(-18.0, -26.0 - lift), Vector2(18.0, -26.0 - lift), Vector2(22.0, -14.0),
	])
	if opened:
		draw_rect(Rect2(Vector2(-18.0, -14.0), Vector2(36.0, 4.0)), Color(1.0, 0.91, 0.66, 0.8))
	draw_colored_polygon(lid, wood)
	draw_polyline(PackedVector2Array([lid[0], lid[1], lid[2], lid[3], lid[0]]), wood_dark, 2.0, true)
	draw_line(Vector2(-18.0, -26.0 - lift + 3.0), Vector2(18.0, -26.0 - lift + 3.0), gold, 2.0, true)
	if available and not opened:
		var sparkle := Vector2(sin(_age * 2.1) * 16.0, -30.0 + cos(_age * 1.7) * 4.0)
		draw_circle(sparkle, 2.0, Color(1.0, 1.0, 0.8, 0.8))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and can_interact(player.global_position):
		draw_rect(Rect2(Vector2(-16.0, -48.0), Vector2(32.0, 16.0)), Color(0.05, 0.04, 0.08, 0.85))
		draw_rect(Rect2(Vector2(-16.0, -48.0), Vector2(32.0, 16.0)), gold, false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-16.0, -36.0), "E", HORIZONTAL_ALIGNMENT_CENTER, 32, 13, gold)
