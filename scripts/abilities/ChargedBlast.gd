class_name ChargedBlast
extends Ability
## Donut's charged magic blast. Hold to charge, release to fire a larger bolt.
## Damage scales 18 -> 35; size and knockback grow with charge time.

enum Phase { IDLE, CHARGING, CAST, RECOVERY }

@export var min_damage := 18.0
@export var max_damage := 35.0
@export var max_charge_time := 1.0
@export var min_knockback := Vector2(200, -110)
@export var max_knockback := Vector2(560, -260)
@export var min_radius := 10.0
@export var max_radius := 18.0
@export var speed := 500.0
@export var max_range := 460.0
@export var cast_time := 0.08
@export var recovery := 0.2
@export var charging_move_factor := 0.6

var phase := Phase.IDLE
var charge_time := 0.0
## Charge ratio captured at release.
var released_ratio := 0.0

var _t := 0.0


func _init() -> void:
	display_name = "Magic Blast"
	mode = PlayerCombat.Mode.DONUT
	cooldown = 0.8


func press() -> void:
	if phase == Phase.IDLE and is_ready():
		phase = Phase.CHARGING
		charge_time = 0.0


func release() -> void:
	if phase == Phase.CHARGING:
		released_ratio = charge_ratio()
		phase = Phase.CAST
		_t = cast_time


func tick(delta: float) -> void:
	match phase:
		Phase.CHARGING:
			charge_time = minf(charge_time + delta, max_charge_time)
		Phase.CAST:
			_t -= delta
			if _t <= 0.0:
				_fire()
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
	return phase == Phase.CAST


func locks_facing() -> bool:
	return phase == Phase.CAST


func move_speed_factor() -> float:
	return charging_move_factor if phase == Phase.CHARGING else 1.0


func damage_for_ratio(ratio: float) -> float:
	return lerpf(min_damage, max_damage, clampf(ratio, 0.0, 1.0)) * combat.magic_damage_multiplier


func knockback_for_ratio(ratio: float) -> Vector2:
	return min_knockback.lerp(max_knockback, clampf(ratio, 0.0, 1.0)) * combat.knockback_multiplier


func radius_for_ratio(ratio: float) -> float:
	return lerpf(min_radius, max_radius, clampf(ratio, 0.0, 1.0))


func _fire() -> void:
	var tags := PackedStringArray(["magic", "charged"])
	if released_ratio >= 0.5:
		tags.append("heavy")
	var hit := Hit.new(damage_for_ratio(released_ratio), knockback_for_ratio(released_ratio), player, tags)
	Audio.play("magic_blast", -2.0)
	combat.fire_projectile(hit, radius_for_ratio(released_ratio), speed, max_range, true)
