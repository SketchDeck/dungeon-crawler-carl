class_name Hit
extends RefCounted
## A single instance of damage delivered to something that implements take_hit(hit).

var damage: float
## World-space knockback velocity (already facing-adjusted).
var knockback: Vector2
var source: Node
## Free-form tags, e.g. "kick", "heavy", "charged".
var tags: PackedStringArray


func _init(p_damage := 0.0, p_knockback := Vector2.ZERO, p_source: Node = null, p_tags := PackedStringArray()) -> void:
	damage = p_damage
	knockback = p_knockback
	source = p_source
	tags = p_tags


func has_tag(tag: String) -> bool:
	return tags.has(tag)
