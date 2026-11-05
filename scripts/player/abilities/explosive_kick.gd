class_name ExplosiveKick
extends Ability
## Carl's special (unlocked by defeating Floor 1). An explosive kick: it detonates where it
## connects, damaging and blasting everything nearby. A whiff does not explode.

var _exploded: bool = false


func fire(combat: PlayerCombat) -> void:
	_exploded = false
	var damage := roundi(Config.EXPLOSIVE_KICK_DAMAGE * 0.6 * Game.modifier("kick_damage") * DungeonAI.damage_mult())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72.0, 40.0)
	var hitbox := Hitbox.new(
		shape,
		Vector2(42.0, -2.0),
		0.2,
		damage,
		Vector2(Config.KICK_KNOCKBACK[2], -60.0),
		"explosive_kick",
		Config.LAYER_ENEMY | Config.LAYER_HAZARD
	)
	hitbox.charged = true
	hitbox.on_hit = Callable(self, "_on_impact").bind(combat.player)
	combat.set_hitbox(hitbox)
	combat.player.velocity.x = float(combat.player.controller.facing) * 200.0
	Sfx.play("kick_heavy")
	combat.commit(0.3, "charge_kick")
	start_cooldown(Config.EXPLOSIVE_KICK_COOLDOWN)
	Fx.ring(combat.player.global_position, Color("#ff7a3c"), 36.0, 0.2, 4.0)


func _on_impact(_body: Node2D, center: Vector2, player: Player) -> void:
	if _exploded:
		return
	_exploded = true
	var damage := roundi(Config.EXPLOSIVE_KICK_DAMAGE * Game.modifier("kick_damage") * DungeonAI.damage_mult())
	var knock := Config.EXPLOSIVE_KICK_KNOCKBACK * Game.modifier("knockback") * DungeonAI.knockback_mult()
	Explosion.detonate(player, center, Config.EXPLOSIVE_KICK_RADIUS, damage, knock,
		"explosion", Config.LAYER_ENEMY | Config.LAYER_HAZARD, Color("#ff8a3c"))
