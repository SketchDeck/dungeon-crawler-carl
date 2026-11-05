class_name ExplosiveBarrel
extends StaticBody2D
## An explosive barrel. Any attack sets it off. The blast damages enemies and the player,
## applies radial knockback, and can chain into other barrels.

const RADIUS := 110.0

var _spent: bool = false
var _age: float = 0.0


static func spawn(parent: Node, pos: Vector2) -> ExplosiveBarrel:
	var barrel := ExplosiveBarrel.new()
	barrel.position = pos
	barrel.z_index = 3
	barrel.collision_layer = Config.LAYER_WORLD | Config.LAYER_HAZARD
	barrel.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26.0, 36.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	barrel.add_child(collider)
	parent.add_child(barrel)
	return barrel


func receive_hit(hit: HitInfo) -> bool:
	if _spent:
		return false
	_spent = true
	collision_layer = 0
	var mask := Config.LAYER_ENEMY | Config.LAYER_PLAYER | Config.LAYER_HAZARD
	Explosion.detonate(self, global_position + Vector2(0.0, -6.0), RADIUS, Config.EXPLOSIVE_OBJECT_DAMAGE,
		420.0, "explosion", mask, Color("#ff8a3c"), false, true)
	queue_free()
	return true


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_age * 6.0)
	draw_circle(Vector2(0.0, -4.0), 22.0, Color(1.0, 0.45, 0.15, 0.08 + 0.06 * pulse))
	draw_rect(Rect2(Vector2(-12.0, -18.0), Vector2(24.0, 34.0)), Color("#b23a2a"))
	draw_rect(Rect2(Vector2(-12.0, -6.0), Vector2(24.0, 5.0)), Color("#2b2d36"))
	draw_rect(Rect2(Vector2(-12.0, -14.0), Vector2(24.0, 4.0)), Color("#2b2d36"))
	draw_rect(Rect2(Vector2(-12.0, 4.0), Vector2(24.0, 4.0)), Color("#2b2d36"))
	draw_rect(Rect2(Vector2(-4.0, -12.0), Vector2(8.0, 8.0)), Color("#ffd166"))
	draw_rect(Rect2(Vector2(-12.0, -18.0), Vector2(24.0, 34.0)), Color("#2a0f0b"), false, 1.5)
	draw_circle(Vector2(0.0, -20.0), 2.5, Color(1.0, 0.8, 0.3, 0.6 + 0.4 * pulse))
