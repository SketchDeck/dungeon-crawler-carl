class_name HitInfo
extends RefCounted
## Everything a target needs to know about one hit. Passed to receive_hit() on any target.

var amount: int = 0
var knockback: Vector2 = Vector2.ZERO
var source: Node = null
var kind: String = "generic"  # kick, charged_kick, explosive_kick, magic, blast, burst, explosion, hazard, contact, projectile, slam, charge, swing
var from_player: bool = false
var environmental: bool = false
var charged: bool = false


static func make(damage: int, knock: Vector2, src: Node, hit_kind: String) -> HitInfo:
	var info := HitInfo.new()
	info.amount = damage
	info.knockback = knock
	info.source = src
	info.kind = hit_kind
	return info


## Hits that can break breakable walls and crates.
func is_strong() -> bool:
	return charged or kind in ["explosive_kick", "blast", "burst", "explosion"]
