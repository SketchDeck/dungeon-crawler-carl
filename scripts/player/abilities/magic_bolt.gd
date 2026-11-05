class_name MagicBolt
extends Ability
## Donut's basic attack: a magic bolt fired in the facing direction. Short cooldown, limited range.

func fire(combat: PlayerCombat) -> void:
	if not is_ready():
		return
	var player := combat.player
	var facing := float(player.controller.facing)
	var damage := roundi(Config.MAGIC_DAMAGE * Game.modifier("magic_damage") * DungeonAI.damage_mult())
	var knock := 150.0 * Game.modifier("knockback") * DungeonAI.knockback_mult()
	var origin := player.global_position + Vector2(facing * 22.0, -8.0)
	Projectile.spawn(player.get_parent(), origin, Vector2(facing, 0.0), Config.MAGIC_SPEED, damage,
		Vector2(knock, -50.0), Config.MAGIC_RANGE, 6.0, Color("#b57bff"), false, "magic")
	Sfx.play("magic")
	start_cooldown(Config.MAGIC_COOLDOWN)
	combat.commit(0.12, "cast")
	Fx.flash(origin, Color("#c79bff"), 14.0, 0.12)
