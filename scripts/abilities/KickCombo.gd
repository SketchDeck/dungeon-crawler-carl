class_name KickCombo
extends Ability
## Carl's basic attack: a three-hit kick combo (10 / 10 / 20).
## Press again during a kick to queue the next one, or within combo_window after it.

enum Phase { IDLE, WINDUP, RECOVERY }

@export var damages: Array[float] = [10.0, 10.0, 20.0]
## Knockback per hit, facing right. The finisher knocks back much harder.
@export var knockbacks: Array[Vector2] = [Vector2(140, -40), Vector2(160, -60), Vector2(480, -260)]
## Hitbox relative to the player's origin, facing right.
@export var hitbox := Rect2(6, -14, 54, 40)
@export var windup := 0.07
@export var recovery := 0.18
@export var finisher_recovery := 0.3
@export var combo_window := 0.35
@export var grounded_move_factor := 0.3

var phase := Phase.IDLE
## Index of the kick currently being performed (0..2).
var current := 0

var _t := 0.0
var _window := 0.0
var _next := 0
var _queued := false


func _init() -> void:
	display_name = "Kick Combo"
	cooldown = 0.25


func press() -> void:
	if phase == Phase.IDLE:
		if _window > 0.0:
			_begin(_next)
		elif is_ready():
			_begin(0)
	elif current < damages.size() - 1:
		_queued = true


func tick(delta: float) -> void:
	if _window > 0.0:
		_window -= delta
		if _window <= 0.0:
			_next = 0
	match phase:
		Phase.WINDUP:
			_t -= delta
			if _t <= 0.0:
				_strike()
				phase = Phase.RECOVERY
				_t = finisher_recovery if _is_finisher() else recovery
		Phase.RECOVERY:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.IDLE
				if _is_finisher():
					_next = 0
					start_cooldown()
				elif _queued:
					_begin(current + 1)
				else:
					_next = current + 1
					_window = combo_window


func cancel() -> void:
	phase = Phase.IDLE
	_queued = false
	_window = 0.0
	_next = 0


func is_active() -> bool:
	return phase != Phase.IDLE


func is_busy() -> bool:
	return phase == Phase.WINDUP


func move_speed_factor() -> float:
	return grounded_move_factor if is_active() and player.is_on_floor() else 1.0


func damage_for(index: int) -> float:
	return damages[index] * combat.kick_damage_multiplier


func _begin(index: int) -> void:
	current = index
	phase = Phase.WINDUP
	_t = windup
	_queued = false
	_window = 0.0


func _is_finisher() -> bool:
	return current >= damages.size() - 1


func _strike() -> void:
	var tags := PackedStringArray(["kick"])
	if _is_finisher():
		tags.append("heavy")
	var hit := Hit.new(damage_for(current), knockbacks[current] * combat.knockback_multiplier, player, tags)
	combat.strike(hitbox, hit, _is_finisher(), Color("#ffb347"))
