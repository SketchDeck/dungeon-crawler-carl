class_name ChargedKick
extends Ability
## Carl's charged power kick: hold to charge, release to kick. Damage and knockback grow with
## charge time, and even a tap produces the minimum kick.

func release(combat: PlayerCombat, ratio: float) -> void:
	var damage := roundi(lerpf(Config.CHARGE_KICK_MIN_DAMAGE, Config.CHARGE_KICK_MAX_DAMAGE, ratio)
		* Game.modifier("kick_damage") * DungeonAI.damage_mult())
	var knock := lerpf(Config.CHARGE_KICK_MIN_KNOCKBACK, Config.CHARGE_KICK_MAX_KNOCKBACK, ratio) \
		* Game.modifier("knockback") * DungeonAI.knockback_mult()
	var reach := Config.KICK_RANGE + 24.0 * ratio
	var shape := RectangleShape2D.new()
	shape.size = Vector2(reach, 34.0 + 12.0 * ratio)
	var hitbox := Hitbox.new(
		shape,
		Vector2(reach * 0.5 + 8.0, -2.0),
		0.18,
		damage,
		Vector2(knock, -knock * 0.2),
		"charged_kick",
		Config.LAYER_ENEMY | Config.LAYER_HAZARD
	)
	hitbox.charged = true
	combat.set_hitbox(hitbox)
	combat.player.velocity.x = float(combat.player.controller.facing) * (160.0 + 140.0 * ratio)
	Sfx.play("charge_release")
	combat.commit(0.26, "charge_kick")
	start_cooldown(Config.CHARGE_KICK_COOLDOWN)
	var at: Vector2 = combat.player.global_position + Vector2(combat.player.controller.facing * 28.0, -2.0)
	Fx.ring(at, Color("#ffb347"), 26.0 + 30.0 * ratio, 0.22, 5.0)
	Fx.shake(4.0 + 6.0 * ratio)
	if ratio > 0.8:
		Fx.hitstop(0.03, 0.2)
