class_name AreaBurst
extends Ability
## Donut's special (unlocked by defeating Floor 2): a magical shockwave around the player.
## Damages and pushes back every enemy inside a visible radius. Never hurts the player.

func cast(combat: PlayerCombat) -> void:
	if not is_ready():
		return
	var player := combat.player
	var damage := roundi(Config.AREA_BURST_DAMAGE * Game.modifier("magic_damage") * DungeonAI.damage_mult())
	var knock := Config.AREA_BURST_KNOCKBACK * Game.modifier("knockback") * DungeonAI.knockback_mult()
	Explosion.detonate(player, player.global_position, Config.AREA_BURST_RADIUS, damage, knock,
		"burst", Config.LAYER_ENEMY | Config.LAYER_HAZARD, Color("#b57bff"))
	Fx.ring(player.global_position, Color("#e0c6ff"), Config.AREA_BURST_RADIUS, 0.5, 3.0)
	start_cooldown(Config.AREA_BURST_COOLDOWN)
	combat.commit(0.25, "cast")
