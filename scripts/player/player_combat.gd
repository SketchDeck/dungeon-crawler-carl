class_name PlayerCombat
extends Node
## Routes input to the attacks of the active mode. Carl: basic kick combo (J), charged kick
## (hold K), explosive kick (L). Donut: magic bolt (J), charged blast (hold K), area burst (L).
## Non-interruptible animations are "commitments": they block new attacks and hold back mode
## switches until they finish. Each ability keeps its own cooldown.

var player: Player

var kick := KickCombo.new()
var charged_kick := ChargedKick.new()
var explosive_kick := ExplosiveKick.new()
var bolt := MagicBolt.new()
var blast := ChargedBlast.new()
var burst := AreaBurst.new()

var anim_serial: int = 0
var _hitbox: Hitbox = null
var _commit_left: float = 0.0
var _anim: String = ""
var _attack_buffered: bool = false
var _charging: bool = false
var _charge_time: float = 0.0
var _charge_is_kick: bool = true


func physics_step(delta: float, locked: bool) -> void:
	kick.tick(delta)
	charged_kick.tick(delta)
	explosive_kick.tick(delta)
	bolt.tick(delta)
	blast.tick(delta)
	burst.tick(delta)

	if _commit_left > 0.0:
		_commit_left = maxf(0.0, _commit_left - delta)
		if _commit_left <= 0.0:
			_anim = ""
			player.on_commitment_finished()
			if _attack_buffered:
				_attack_buffered = false
				press_attack()
	if _hitbox != null and not _hitbox.step(player, delta, player.controller.facing):
		_hitbox = null
	if _charging:
		_charge_time = minf(_charge_time + delta, Config.CHARGE_TIME)

	if locked:
		return
	if Input.is_action_just_pressed(Controls.ATTACK):
		press_attack()
	if Input.is_action_just_pressed(Controls.CHARGE):
		begin_charge()
	if _charging and Input.is_action_just_released(Controls.CHARGE):
		release_charge()
	if Input.is_action_just_pressed(Controls.SPECIAL):
		press_special()


func press_attack() -> void:
	if _charging:
		return
	if is_committed():
		_attack_buffered = true
		return
	if player.mode == Player.Mode.CARL:
		kick.press(self)
	else:
		bolt.fire(self)


func begin_charge() -> void:
	if _charging or is_committed():
		return
	var ability: Ability = charged_kick if player.mode == Player.Mode.CARL else blast
	if not ability.is_ready():
		return
	_charging = true
	_charge_time = 0.0
	_charge_is_kick = player.mode == Player.Mode.CARL


func release_charge() -> void:
	if not _charging:
		return
	_charging = false
	var ratio := clampf(_charge_time / Config.CHARGE_TIME, 0.0, 1.0)
	_charge_time = 0.0
	if _charge_is_kick:
		charged_kick.release(self, ratio)
	else:
		blast.release(self, ratio)


func press_special() -> void:
	if is_committed() or _charging:
		return
	if player.mode == Player.Mode.CARL:
		if not Save.has_ability("explosive_kick"):
			_locked_text("Defeat Floor 1 to unlock")
		elif explosive_kick.is_ready():
			explosive_kick.fire(self)
	else:
		if not Save.has_ability("area_burst"):
			_locked_text("Defeat Floor 2 to unlock")
		elif burst.is_ready():
			burst.cast(self)


func set_hitbox(hitbox: Hitbox) -> void:
	_hitbox = hitbox


func commit(seconds: float, anim: String) -> void:
	_commit_left = maxf(_commit_left, seconds)
	_anim = anim
	anim_serial += 1


func is_committed() -> bool:
	return _commit_left > 0.0


func current_anim() -> String:
	return _anim


func is_charging() -> bool:
	return _charging


func charge_ratio() -> float:
	return clampf(_charge_time / Config.CHARGE_TIME, 0.0, 1.0)


func is_charging_kick() -> bool:
	return _charging and _charge_is_kick


func cancel_attacks() -> void:
	var was_committed := is_committed()
	_hitbox = null
	_commit_left = 0.0
	_anim = ""
	_attack_buffered = false
	kick.stage = 0
	kick.window_left = 0.0
	if was_committed:
		player.on_commitment_finished()


func cancel_charge() -> void:
	_charging = false
	_charge_time = 0.0


func reset() -> void:
	cancel_charge()
	cancel_attacks()
	for ability in [kick, charged_kick, explosive_kick, bolt, blast, burst]:
		ability.reset_cooldown()


func _locked_text(message: String) -> void:
	Fx.text(player.global_position + Vector2(0.0, -40.0), message, Color("#9aa4b2"), 14)
