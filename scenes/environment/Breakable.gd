class_name Breakable
extends StaticBody2D
## Something only strong attacks can break: the kick finisher, power kicks,
## charged blasts, explosions and the Magic Burst (hits tagged "heavy").
##   CRATE - small, doesn't block movement, may hold a potion.
##   WALL  - cracked wall that blocks movement; breaking it opens a path.
## Origin is the top-left corner.

signal broken(breakable: Breakable)

enum Kind { CRATE, WALL }

const POTION_SCENE := preload("res://scenes/pickups/PotionPickup.tscn")

@export var kind := Kind.CRATE
@export var size := Vector2(28, 28)
@export var drops_potion := true

var is_broken := false
var _notice := 0.0


func _ready() -> void:
	collision_layer = HitQuery.LAYER_HITTABLE | (HitQuery.LAYER_WORLD if kind == Kind.WALL else 0)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size * 0.5
	add_child(shape)


func _physics_process(delta: float) -> void:
	_notice = maxf(_notice - delta, 0.0)


static func can_break(hit: Hit) -> bool:
	return hit.has_tag("heavy") or hit.has_tag("explosion")


func take_hit(hit: Hit) -> void:
	if is_broken:
		return
	if not can_break(hit):
		if _notice <= 0.0:
			_notice = 0.6
			Fx.text(global_position + Vector2(size.x * 0.5, -10), "Needs a strong hit", Color(1, 1, 1, 0.8), 13)
		Fx.burst(global_position + size * 0.5, Color("#c8a070"), 10.0, 0.12)
		return
	break_apart()


func break_apart() -> void:
	if is_broken:
		return
	is_broken = true
	collision_layer = 0
	var center := global_position + size * 0.5
	Fx.burst(center, Color("#c8a070"), maxf(size.x, size.y) * 0.8, 0.35)
	Fx.shake(0.25 if kind == Kind.WALL else 0.12)
	if kind == Kind.CRATE and drops_potion:
		var potion := POTION_SCENE.instantiate() as PotionPickup
		potion.position = position + size * 0.5
		potion.launch(Vector2(0, -220))
		get_parent().add_child.call_deferred(potion)
	broken.emit(self)
	queue_free()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if kind == Kind.CRATE:
		var wood := Color("#9a6a38")
		draw_rect(rect, wood)
		draw_rect(rect, wood.darkened(0.4), false, 2.0)
		draw_line(Vector2(2, 2), size - Vector2(2, 2), wood.darkened(0.3), 2.0)
		draw_line(Vector2(size.x - 2, 2), Vector2(2, size.y - 2), wood.darkened(0.3), 2.0)
	else:
		var stone := Color("#56606e")
		draw_rect(rect, stone)
		# Brick courses with a big crack down the middle.
		var y := 0.0
		var row := 0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), stone.darkened(0.3), 1.0)
			var x := 8.0 if row % 2 == 1 else 0.0
			while x < size.x:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 16.0, size.y)), stone.darkened(0.3), 1.0)
				x += 16.0
			y += 16.0
			row += 1
		var cx := size.x * 0.5
		draw_polyline(PackedVector2Array([Vector2(cx - 3, 0), Vector2(cx + 4, size.y * 0.3), Vector2(cx - 5, size.y * 0.55),
			Vector2(cx + 3, size.y * 0.8), Vector2(cx - 2, size.y)]), Color("#1a1d22"), 2.5)
		draw_rect(rect, stone.darkened(0.45), false, 2.0)
