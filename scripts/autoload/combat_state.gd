extends Node
## Combat-state controller. Combat is active while any enemy is engaged, a combat room encounter
## is active, or a boss is active. It drives the out-of-combat regeneration and nothing else.

signal combat_started
signal combat_ended

var regen := RegenController.new()

var _engaged: Dictionary = {}
var _room_active: bool = false
var _boss_active: bool = false
var _was_in_combat: bool = false
var _player_health: HealthState = null
var _heal_carry: float = 0.0


func bind_player(health: HealthState) -> void:
	_player_health = health
	_heal_carry = 0.0


## Clears engagement and encounter flags, e.g. after death or when a room is reset.
func reset() -> void:
	_engaged.clear()
	_room_active = false
	_boss_active = false
	_heal_carry = 0.0
	regen.reset()
	_was_in_combat = false


func engage(enemy: Node) -> void:
	_engaged[enemy.get_instance_id()] = enemy
	_refresh()


func disengage(enemy: Node) -> void:
	_engaged.erase(enemy.get_instance_id())
	_refresh()


func set_room_encounter(active: bool) -> void:
	_room_active = active
	_refresh()


func set_boss_active(active: bool) -> void:
	_boss_active = active
	_refresh()


func is_boss_active() -> bool:
	return _boss_active


func in_combat() -> bool:
	return not _engaged.is_empty() or _room_active or _boss_active


func is_regen_pending() -> bool:
	if _player_health == null:
		return false
	return regen.is_pending(_player_health.hp, _player_health.max_hp)


func is_regen_active() -> bool:
	return regen.active


func _process(delta: float) -> void:
	_refresh()
	if _player_health == null:
		return
	var amount := regen.tick(delta, _player_health.hp, _player_health.max_hp, _player_health.is_alive())
	if amount <= 0.0:
		return
	_heal_carry += amount
	var whole := int(floor(_heal_carry))
	if whole >= 1:
		_heal_carry -= whole
		_player_health.heal(whole)


func _refresh() -> void:
	for key in _engaged.keys():
		if not is_instance_valid(_engaged[key]):
			_engaged.erase(key)
	var now := in_combat()
	if now == _was_in_combat:
		return
	_was_in_combat = now
	if now:
		regen.on_combat_started()
		combat_started.emit()
	else:
		regen.on_combat_ended()
		combat_ended.emit()
