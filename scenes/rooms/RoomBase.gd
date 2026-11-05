class_name RoomBase
extends Node2D
## Base for every room scene: camera bounds, a player spawn point and a backdrop.
## Encounters, exits and locking arrive in Milestone 3.

@export var room_id := ""
## Camera limits and backdrop area, in room coordinates.
@export var bounds := Rect2(0, 0, 1920, 720)
@export var backdrop_color := Color("#1a2230")


func get_spawn_point() -> Vector2:
	var spawn := get_node_or_null("PlayerSpawn") as Node2D
	return spawn.global_position if spawn else global_position + bounds.get_center()


func _draw() -> void:
	draw_rect(bounds, backdrop_color)
	# Faint brick grid so movement reads against the background.
	var grid := Color(1, 1, 1, 0.025)
	var y := bounds.position.y
	var row := 0
	while y < bounds.end.y:
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), grid)
		var x := bounds.position.x + (32.0 if row % 2 == 1 else 0.0)
		while x < bounds.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + 32.0), grid)
			x += 64.0
		y += 32.0
		row += 1
