class_name MagicMissile
extends Ability
## Donut's basic attack: a quick magic bolt in the facing direction (12 damage).
## A press shortly before the cooldown ends is buffered and fires as soon as it can.

enum Phase { IDLE, CAST, RECOVERY }

@export var damage := 12.0
@export var knockback := Vector2(110, -60)
@export var speed := 560.0
## How far the bolt flies before fizzling out.
@export var max_range := 380.0
@export var radius := 7.0
@export var cast_time := 0.06
@export var recovery := 0.1
@export var buffer_time := 0.12

var phase := Phase.IDLE
var _t := 0.0
var _buffer := 0.0


func _init() -> void:
	display_name = "Magic Missile"
	mode = PlayerCombat.Mode.DONUT
	cooldown = 0.3


func press() -> void:
	if phase == Phase.IDLE and is_ready():
		phase = Phase.CAST
		_t = cast_time
		_buffer = 0.0
	else:
		_buffer = buffer_time


func tick(delta: float) -> void:
	_buffer = maxf(_buffer - delta, 0.0)
	match phase:
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
	if phase == Phase.IDLE and _buffer > 0.0 and is_ready():
		press()


func cancel() -> void:
	phase = Phase.IDLE
	_buffer = 0.0


func is_active() -> bool:
	return phase != Phase.IDLE


func is_busy() -> bool:
	return phase == Phase.CAST


func locks_facing() -> bool:
	return phase == Phase.CAST


func damage_value() -> float:
	return damage * combat.magic_damage_multiplier


func _fire() -> void:
	var hit := Hit.new(damage_value(), knockback * combat.knockback_multiplier, player, PackedStringArray(["magic"]))
	Audio.play("magic_missile", -5.0)
	combat.fire_projectile(hit, radius, speed, max_range, false)
	if combat.twin_bolt_factor > 0.0:
		var twin := Hit.new(damage_value() * combat.twin_bolt_factor, knockback * combat.knockback_multiplier * 0.5, player,
			PackedStringArray(["magic"]))
		combat.fire_projectile(twin, radius * 0.75, speed * 1.1, max_range, false, -14.0)
