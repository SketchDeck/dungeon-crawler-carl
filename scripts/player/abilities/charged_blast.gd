class_name ChargedBlast
extends Ability
## Donut's charged magic blast: hold to charge, release to fire a larger, harder-hitting orb.

func release(combat: PlayerCombat, ratio: float) -> void:
	var player := combat.player
	var facing := float(player.controller.facing)
	var damage := roundi(lerpf(Config.BLAST_MIN_DAMAGE, Config.BLAST_MAX_DAMAGE, ratio)
		* Game.modifier("magic_damage") * DungeonAI.damage_mult())
	var knock := lerpf(190.0, 360.0, ratio) * Game.modifier("knockback") * DungeonAI.knockback_mult()
	var radius := lerpf(8.0, 17.0, ratio)
	var origin := player.global_position + Vector2(facing * 24.0, -8.0)
	Projectile.spawn(player.get_parent(), origin, Vector2(facing, 0.0), Config.BLAST_SPEED, damage,
		Vector2(knock, -70.0), Config.BLAST_RANGE, radius, Color("#9d6bff"), false, "blast", true)
	Sfx.play("blast")
	start_cooldown(Config.BLAST_COOLDOWN)
	combat.commit(0.2, "cast")
	Fx.ring(origin, Color("#b57bff"), 24.0 + 20.0 * ratio, 0.22, 4.0)
	Fx.shake(3.0 + 5.0 * ratio)
