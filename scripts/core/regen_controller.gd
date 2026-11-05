class_name RegenController
extends RefCounted
## Out-of-combat healing. Pure logic: the caller feeds it time and state and applies the
## HP it returns.
##
## Rules implemented here:
## - Healing waits REGEN_DELAY seconds after combat ends.
## - Once started it fills the missing HP over REGEN_DURATION seconds, so the rate is
##   missing_hp / REGEN_DURATION, recalculated each time it starts.
## - Entering combat cancels healing immediately and restarts the delay when combat ends.
## - Healing never consumes potions, and it stops at full health.

signal regen_started(rate: float)
signal regen_stopped

var in_combat: bool = false
var active: bool = false
var rate: float = 0.0
var delay_left: float = Config.REGEN_DELAY


func on_combat_started() -> void:
	in_combat = true
	_stop()


func on_combat_ended() -> void:
	in_combat = false
	delay_left = Config.REGEN_DELAY


## Called on death and respawn: cancel everything and wait the full delay again.
func reset() -> void:
	in_combat = false
	_stop()
	delay_left = Config.REGEN_DELAY


## True while the out-of-combat wait is running (used for the HUD "healing pending" hint).
func is_pending(hp: float, max_hp: float) -> bool:
	return not in_combat and not active and delay_left > 0.0 and hp < max_hp


## Returns the amount of HP to add this frame (not yet clamped to max).
func tick(delta: float, hp: float, max_hp: float, alive: bool) -> float:
	if in_combat or not alive or hp >= max_hp:
		_stop()
		return 0.0
	if not active:
		if delay_left > 0.0:
			delay_left = maxf(0.0, delay_left - delta)
			return 0.0
		active = true
		rate = (max_hp - hp) / Config.REGEN_DURATION
		regen_started.emit(rate)
	return rate * delta


func _stop() -> void:
	if active:
		active = false
		rate = 0.0
		regen_stopped.emit()
