class_name AreaBurst
extends Ability
## Donut's unlockable special (L in Donut mode; unlocked by beating Floor 2,
## or with the debug key). A magical shockwave all around the player that
## damages everything in the radius and pushes it away.

enum Phase { IDLE, CAST, RECOVERY }

@export var damage := 22.0
@export var radius := 140.0
@export var knockback := 380.0
@export var cast_time := 0.15
@export var recovery := 0.2

var phase := Phase.IDLE
var _t := 0.0


func _init() -> void:
	display_name = "Magic Burst"
	mode = PlayerCombat.Mode.DONUT
	cooldown = 6.0
	unlock_id = &"area_burst"


func press() -> void:
	if phase == Phase.IDLE and is_ready():
		phase = Phase.CAST
		_t = cast_time


func tick(delta: float) -> void:
	match phase:
		Phase.CAST:
			_t -= delta
			if _t <= 0.0:
				_burst()
				start_cooldown()
				phase = Phase.RECOVERY
				_t = recovery
		Phase.RECOVERY:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.IDLE


func cancel() -> void:
	phase = Phase.IDLE


## 0..1 progress through the cast, for the visual radius preview.
func cast_ratio() -> float:
	return 1.0 - clampf(_t / cast_time, 0.0, 1.0) if phase == Phase.CAST else 0.0


func is_active() -> bool:
	return phase != Phase.IDLE


func is_busy() -> bool:
	return phase == Phase.CAST


func locks_facing() -> bool:
	return phase == Phase.CAST


func move_speed_factor() -> float:
	return 0.3 if phase == Phase.CAST else 1.0


func damage_value() -> float:
	return damage * combat.magic_damage_multiplier


func _burst() -> void:
	Audio.play("magic_blast")
	Explosion.detonate(player, player.global_position, radius, damage_value(),
		knockback * combat.knockback_multiplier, combat.target_mask, player,
		PackedStringArray(["magic", "burst", "heavy"]), PlayerCombat.DONUT_COLOR)
