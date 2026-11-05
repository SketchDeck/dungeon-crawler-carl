class_name Breakable
extends StaticBody2D
## A cracked stone crate. Normal kicks crack it; strong attacks (charged kicks, blasts,
## explosions) break it. Breaking it reveals health potions.

const HALF := Vector2(18.0, 18.0)

var hp: int = Config.BREAKABLE_HP
var _shake: float = 0.0
var _broken: bool = false


static func spawn(parent: Node, pos: Vector2) -> Breakable:
	var crate := Breakable.new()
	crate.position = pos
	crate.z_index = 3
	crate.collision_layer = Config.LAYER_WORLD | Config.LAYER_HAZARD
	crate.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = HALF * 2.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	crate.add_child(collider)
	parent.add_child(crate)
	return crate


func receive_hit(hit: HitInfo) -> bool:
	if _broken:
		return false
	_shake = 0.25
	if hit.is_strong():
		hp = 0
	else:
		hp -= 1
	Fx.burst(global_position, Color("#c9a071"), 10, 180.0, 0.4)
	Fx.shake(3.0)
	if hp <= 0:
		_break()
	return true


func _break() -> void:
	_broken = true
	collision_layer = 0
	Sfx.play("breakable")
	Fx.burst(global_position, Color("#e0b07a"), 30, 320.0, 0.6)
	Fx.ring(global_position, Color("#ffd27a"), 40.0, 0.3, 4.0)
	Fx.shake(9.0)
	Fx.hitstop(0.05, 0.1)
	var parent := get_parent()
	PotionPickup.spawn(parent, global_position + Vector2(-14.0, -10.0))
	PotionPickup.spawn(parent, global_position + Vector2(14.0, -10.0))
	queue_free()


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	queue_redraw()


func _draw() -> void:
	var jitter := Vector2(sin(_shake * 90.0), 0.0) * _shake * 4.0
	var r := Rect2(-HALF + jitter, HALF * 2.0)
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, Color("#8a5f36"))
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color("#a8723f"))
	for i in range(3):
		var y := r.position.y + 6.0 + i * 11.0
		draw_line(Vector2(r.position.x + 3.0, y), Vector2(r.end.x - 3.0, y), Color("#6b4426"), 2.0, true)
	draw_line(r.position + Vector2(4, 4), r.end + Vector2(-6, -6), Color("#4a2e18"), 2.0, true)
	draw_rect(r, Color("#3b2612"), false, 2.0)
