class_name ExplosiveKick
extends ChargedKick
## Carl's unlockable special (L in Carl mode; unlocked by beating Floor 1).
## A charged kick (tap or hold, then release) that explodes on impact: the
## kick itself hits like a power kick, then a blast at Carl's foot damages
## everything nearby, knocks it away from the blast, and sets off explosive
## barrels. The blast grows with charge.

@export var explosion_damage := 20.0
@export var min_explosion_radius := 70.0
@export var max_explosion_radius := 110.0
@export var explosion_knockback := 460.0


func _init() -> void:
	display_name = "Explosive Kick"
	cooldown = 3.5
	unlock_id = &"explosive_kick"


func explosion_radius(ratio: float) -> float:
	return lerpf(min_explosion_radius, max_explosion_radius, clampf(ratio, 0.0, 1.0))


func _strike() -> void:
	super._strike()
	var at := player.global_position + Vector2((hitbox.end.x - 10.0) * player.facing, hitbox.get_center().y)
	Explosion.detonate(player, at, explosion_radius(released_ratio),
		explosion_damage * combat.kick_damage_multiplier, explosion_knockback * combat.knockback_multiplier,
		combat.target_mask, player, PackedStringArray(["explosion", "kick", "heavy"]), Color("#ff6a2a"))
