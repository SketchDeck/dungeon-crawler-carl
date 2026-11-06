class_name ChargedKick
extends Ability
## Carl's charged power kick. Hold to charge, release to kick.
## Damage scales 15 -> 35 and knockback grows with charge time.

enum Phase { IDLE, CHARGING, WINDUP, RECOVERY }

@export var min_damage := 15.0
@export var max_damage := 35.0
@export var max_charge_time := 1.0
@export var min_knockback := Vector2(300, -140)
@export var max_knockback := Vector2(780, -320)
@export var hitbox := Rect2(4, -18, 66, 48)
@export var windup := 0.08
@export var recovery := 0.3
@export var charging_move_factor := 0.45
@export var attacking_move_factor := 0.2

var phase := Phase.IDLE
var charge_time := 0.0
## Charge ratio captured at release, used for the strike and visuals.
var released_ratio := 0.0

var _t := 0.0


func _init() -> void:
	display_name = "Power Kick"
	# Starts when the kick lands, so it covers the 0.3s recovery too.
	cooldown = 0.9


func press() -> void:
	if phase == Phase.IDLE and is_ready():
		phase = Phase.CHARGING
		charge_time = 0.0


func release() -> void:
	if phase == Phase.CHARGING:
		released_ratio = charge_ratio()
		phase = Phase.WINDUP
		_t = windup


func tick(delta: float) -> void:
	match phase:
		Phase.CHARGING:
			charge_time = minf(charge_time + delta, max_charge_time)
		Phase.WINDUP:
			_t -= delta
			if _t <= 0.0:
				_strike()
				start_cooldown()
				phase = Phase.RECOVERY
				_t = recovery
		Phase.RECOVERY:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.IDLE


func cancel() -> void:
	phase = Phase.IDLE
	charge_time = 0.0


func charge_ratio() -> float:
	return clampf(charge_time / max_charge_time, 0.0, 1.0)


func is_charging() -> bool:
	return phase == Phase.CHARGING


func is_active() -> bool:
	return phase != Phase.IDLE


func is_busy() -> bool:
	return phase == Phase.WINDUP


func locks_facing() -> bool:
	return phase == Phase.WINDUP or phase == Phase.RECOVERY


func move_speed_factor() -> float:
	match phase:
		Phase.CHARGING:
			return charging_move_factor
		Phase.WINDUP, Phase.RECOVERY:
			return attacking_move_factor if player.is_on_floor() else 1.0
	return 1.0


func damage_for_ratio(ratio: float) -> float:
	return lerpf(min_damage, max_damage, clampf(ratio, 0.0, 1.0)) * combat.kick_damage_multiplier


func knockback_for_ratio(ratio: float) -> Vector2:
	return min_knockback.lerp(max_knockback, clampf(ratio, 0.0, 1.0)) * combat.knockback_multiplier


func _strike() -> void:
	var tags := PackedStringArray(["kick", "charged", "heavy"])
	var hit := Hit.new(damage_for_ratio(released_ratio), knockback_for_ratio(released_ratio), player, tags)
	combat.strike(hitbox, hit, true, Color("#ff7a2f").lerp(Color.WHITE, released_ratio * 0.5))
