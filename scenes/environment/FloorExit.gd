class_name FloorExit
extends Node2D
## Stairs down to the next floor. Hidden until the boss is beaten; walking
## onto them while open finishes the floor.

signal entered

const SIZE := Vector2(56, 64)

var open := false

var _area: Area2D
var _t := 0.0
var _fired := false


func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = HitQuery.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE.x - 24.0, SIZE.y)
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y * 0.5)
	_area.add_child(shape)
	add_child(_area)


func reveal() -> void:
	if open:
		return
	open = true
	Fx.burst(global_position + Vector2(0, -30), Color("#ffd34d"), 50.0, 0.5)
	Fx.text(global_position + Vector2(0, -80), "STAIRS DOWN", Color("#ffd34d"), 18)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not open or _fired:
		return
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player and not player.health.is_dead:
			_fired = true
			entered.emit()
			return


func _draw() -> void:
	if not open:
		return
	var r := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	draw_rect(r.grow(4), Color("#6a5430"))
	draw_rect(r, Color("#07080b"))
	# Steps going down into the dark.
	for i in 4:
		var w := SIZE.x - 8.0 - i * 10.0
		draw_rect(Rect2(-w * 0.5, -14.0 - i * 13.0, w, 5), Color(0.45, 0.4, 0.32, 0.9 - i * 0.2))
	var glow := 0.3 + 0.15 * sin(_t * 3.0)
	draw_rect(r.grow(-2), Color(1.0, 0.83, 0.3, glow * 0.3))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-SIZE.x * 0.5 - 10, -SIZE.y - 10), "STAIRS", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x + 20, 12,
		Color(1.0, 0.85, 0.4, 0.95))
