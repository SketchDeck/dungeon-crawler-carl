class_name Ability
extends RefCounted
## Base for player abilities. Each ability owns its own cooldown, so switching modes never
## resets or shares cooldowns.

var cooldown_left: float = 0.0
var _cooldown_total: float = 1.0


func tick(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)


func is_ready() -> bool:
	return cooldown_left <= 0.0


func reset_cooldown() -> void:
	cooldown_left = 0.0


## Starts the cooldown, scaled by temporary "Reduced cooldown" upgrades.
func start_cooldown(base_seconds: float) -> void:
	_cooldown_total = maxf(0.05, base_seconds * Game.modifier("cooldown"))
	cooldown_left = _cooldown_total


## 0 when ready, 1 right after use. Used by the HUD ring.
func cooldown_ratio() -> float:
	return clampf(cooldown_left / _cooldown_total, 0.0, 1.0)
