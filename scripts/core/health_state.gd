class_name HealthState
extends RefCounted
## Pure health bookkeeping (no nodes), so it can be unit tested headlessly.
## Health never goes above max_hp or below 0.

signal changed(current: int, maximum: int)
signal died

var max_hp: int
var hp: int
var invuln_left: float = 0.0


func _init(maximum: int = Config.PLAYER_MAX_HP) -> void:
	max_hp = maxi(1, maximum)
	hp = max_hp


func tick(delta: float) -> void:
	invuln_left = maxf(0.0, invuln_left - delta)


func is_alive() -> bool:
	return hp > 0


func is_invulnerable() -> bool:
	return invuln_left > 0.0


func missing() -> int:
	return max_hp - hp


## Applies damage unless dead or invulnerable. Returns the HP actually removed.
func take_damage(amount: int, invuln_time: float = Config.PLAYER_HIT_INVULN) -> int:
	if amount <= 0 or not is_alive() or is_invulnerable():
		return 0
	var before := hp
	hp = clampi(hp - amount, 0, max_hp)
	invuln_left = invuln_time
	changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()
	return before - hp


## Heals up to max. Dead characters cannot be healed. Returns the HP actually restored.
func heal(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var before := hp
	hp = clampi(hp + amount, 0, max_hp)
	if hp != before:
		changed.emit(hp, max_hp)
	return hp - before


## Changes the maximum. When raising it, `also_heal` adds the same amount to current HP.
func set_max_hp(value: int, also_heal: bool = false) -> void:
	var old_max := max_hp
	max_hp = maxi(1, value)
	if also_heal and max_hp > old_max:
		hp = mini(max_hp, hp + (max_hp - old_max))
	else:
		hp = mini(hp, max_hp)
	changed.emit(hp, max_hp)


func restore_full() -> void:
	hp = max_hp
	invuln_left = 0.0
	changed.emit(hp, max_hp)
