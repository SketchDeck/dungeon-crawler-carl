class_name PlayerHealth
extends Node
## Shared Carl + Donut health pool. Values are floats so regeneration
## (Milestone 2) can be smooth; the HUD rounds for display.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_health := 100.0
@export var hurt_invuln_time := 0.75

var current := 100.0
var is_dead := false
## Seconds since the last damage was taken (drives hurt flash).
var time_since_damage := 999.0

var _invuln := 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	time_since_damage += delta


func is_invulnerable() -> bool:
	return is_dead or _invuln > 0.0


func missing() -> float:
	return max_health - current


## Applies damage unless invulnerable. Returns true if damage was applied.
func take_damage(amount: float) -> bool:
	if amount <= 0.0 or is_invulnerable():
		return false
	current = clampf(current - amount, 0.0, max_health)
	_invuln = hurt_invuln_time
	time_since_damage = 0.0
	damaged.emit(amount)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()
	return true


## Heals up to max health. Returns the amount actually restored.
func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var before := current
	current = clampf(current + amount, 0.0, max_health)
	var restored := current - before
	if restored > 0.0:
		healed.emit(restored)
		health_changed.emit(current, max_health)
	return restored


func reset() -> void:
	current = max_health
	is_dead = false
	_invuln = 0.0
	time_since_damage = 999.0
	health_changed.emit(current, max_health)
