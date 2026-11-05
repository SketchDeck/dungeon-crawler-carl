class_name KickCombo
extends Ability
## Carl's basic attack: a three-hit kick combo. The third kick hits harder and knocks back more.
## Hits must chain inside the combo window, otherwise the combo resets to the first kick.

var stage: int = 0
var window_left: float = 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	window_left = maxf(0.0, window_left - delta)
	if window_left <= 0.0:
		stage = 0


func press(combat: PlayerCombat) -> void:
	var index := stage if window_left > 0.0 else 0
	var damage := roundi(Config.KICK_DAMAGE[index] * Game.modifier("kick_damage") * DungeonAI.damage_mult())
	var knock: float = Config.KICK_KNOCKBACK[index] * Game.modifier("knockback") * DungeonAI.knockback_mult()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Config.KICK_RANGE, 30.0)
	var hitbox := Hitbox.new(
		shape,
		Vector2(Config.KICK_RANGE * 0.5 + 8.0, -2.0),
		Config.KICK_DURATION,
		damage,
		Vector2(knock, -knock * 0.15),
		"kick",
		Config.LAYER_ENEMY | Config.LAYER_HAZARD
	)
	combat.set_hitbox(hitbox)
	Sfx.play("kick")
	combat.player.velocity.x = float(combat.player.controller.facing) * 120.0
	Fx.ring(combat.player.global_position + Vector2(combat.player.controller.facing * 26.0, -2.0),
		Color("#ffd27a"), 22.0 + index * 4.0, 0.18, 3.0)
	var commit_time := Config.KICK_DURATION + Config.KICK_RECOVERY
	combat.commit(commit_time, "kick")
	stage = index + 1 if index < 2 else 0
	window_left = Config.KICK_COMBO_WINDOW + commit_time
