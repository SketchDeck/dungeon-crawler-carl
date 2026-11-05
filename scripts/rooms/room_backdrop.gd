class_name RoomBackdrop
extends Node2D
## Static room art: background, brick walls, pillars, platforms and shafts. Drawn once (no
## per-frame redraw), so it stays cheap. Animated parts (torches, exit glows) live in RoomBase.

var _shell: Array = []
var _platforms: Array = []
var _one_way: Array = []
var _openings: Dictionary = {}
var _size: Vector2 = Vector2(1280.0, 640.0)
var _theme: String = "warrens"


func setup(layout: Dictionary) -> void:
	_shell = layout.get("shell", [])
	_platforms = layout.get("platforms", [])
	_one_way = layout.get("one_way", [])
	_openings = layout.get("openings", {})
	_size = layout.get("size", _size)
	_theme = str(layout.get("theme", "warrens"))
	z_index = -10
	queue_redraw()


func _draw() -> void:
	var pal := Decor.palette(_theme)
	Decor.draw_background(self, pal, _size)
	Decor.draw_pillars(self, pal, _size)
	for rect in _shell:
		Decor.draw_shell_block(self, pal, rect)
	for rect in _platforms:
		Decor.draw_platform(self, pal, rect, false)
	for rect in _one_way:
		Decor.draw_platform(self, pal, rect, true)
	for side in ["up", "down"]:
		if _openings.has(side):
			draw_rect(_openings[side]["barrier"], Color("#0a0710"))
