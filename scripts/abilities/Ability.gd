class_name Ability
extends Node
## Base class for player abilities. Each ability owns its own cooldown, so
## switching combat modes (Milestone 4) never resets another ability's timer.

@export var display_name := ""
@export var cooldown := 0.3

var cooldown_remaining := 0.0
var player: Player
var combat: PlayerCombat


func setup(p_player: Player, p_combat: PlayerCombat) -> void:
	player = p_player
	combat = p_combat


func _physics_process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	tick(delta)


func is_ready() -> bool:
	return cooldown_remaining <= 0.0


func start_cooldown() -> void:
	cooldown_remaining = cooldown * combat.cooldown_multiplier


func cooldown_ratio() -> float:
	if cooldown <= 0.0:
		return 0.0
	return cooldown_remaining / (cooldown * combat.cooldown_multiplier)


# --- Overridables -----------------------------------------------------------

func tick(_delta: float) -> void:
	pass


func press() -> void:
	pass


func release() -> void:
	pass


func cancel() -> void:
	pass


## The ability is doing something (charging, attacking, recovering).
func is_active() -> bool:
	return false


## The ability is in a non-interruptible window (mode switches get queued).
func is_busy() -> bool:
	return false


## Multiplier applied to horizontal movement speed while this ability runs.
func move_speed_factor() -> float:
	return 1.0


func locks_facing() -> bool:
	return is_active()
