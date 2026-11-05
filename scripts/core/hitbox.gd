class_name Hitbox
extends RefCounted
## A short-lived melee hitbox that lives in front of its owner for `duration` seconds.
## Each body is hit at most once per activation.

var shape: Shape2D
var offset: Vector2
var time_left: float
var damage: int
var knockback: Vector2
var kind: String
var mask: int
var charged: bool = false
## Optional: called as on_hit(body, center) after each successful hit.
var on_hit: Callable = Callable()
var _hit_ids: Dictionary = {}


func _init(hit_shape: Shape2D, hit_offset: Vector2, duration: float, dmg: int, knock: Vector2, hit_kind: String, hit_mask: int) -> void:
	shape = hit_shape
	offset = hit_offset
	time_left = duration
	damage = dmg
	knockback = knock
	kind = hit_kind
	mask = hit_mask


## Advances the hitbox and delivers hits. Returns true while the hitbox is still active.
func step(owner: Node2D, delta: float, facing: int, origin_offset: Vector2 = Vector2.ZERO) -> bool:
	time_left -= delta
	var center := owner.global_position + Vector2(offset.x * facing, offset.y) + origin_offset
	var xform := Transform2D(0.0, center)
	for body in AttackQuery.overlapping(owner, shape, xform, mask, owner):
		var id: int = body.get_instance_id()
		if _hit_ids.has(id):
			continue
		_hit_ids[id] = true
		if body.has_method("receive_hit"):
			var info := HitInfo.make(damage, Vector2(knockback.x * facing, knockback.y), owner, kind)
			info.from_player = true
			info.charged = charged
			body.receive_hit(info)
			if on_hit.is_valid():
				on_hit.call(body, center)
	return time_left > 0.0
