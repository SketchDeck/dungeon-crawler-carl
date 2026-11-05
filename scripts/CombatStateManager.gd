class_name CombatStateManager
extends Node
## Tracks whether the player is in combat.
##
## In combat while any enemy is engaged with the player, or while a room/boss
## encounter is active. Enemies stay engaged until they die or explicitly
## disengage (after losing the player for a while), so momentary gaps in
## attack range never flicker the combat state.

signal combat_started
signal combat_ended

var in_combat := false

## instance_id -> Callable connected to that enemy's tree_exiting.
var _enemies := {}
## encounter id -> is_boss
var _encounters := {}


func set_enemy_engaged(enemy: Node, engaged: bool) -> void:
	var id := enemy.get_instance_id()
	if engaged and not _enemies.has(id):
		var on_exit := _on_enemy_exiting.bind(id)
		_enemies[id] = on_exit
		enemy.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	elif not engaged and _enemies.has(id):
		var on_exit: Callable = _enemies[id]
		if enemy.tree_exiting.is_connected(on_exit):
			enemy.tree_exiting.disconnect(on_exit)
		_enemies.erase(id)
	_refresh()


## A room encounter or boss fight keeps the player in combat until ended.
func begin_encounter(id: StringName, is_boss := false) -> void:
	_encounters[id] = is_boss
	_refresh()


func end_encounter(id: StringName) -> void:
	_encounters.erase(id)
	_refresh()


func is_boss_active() -> bool:
	return _encounters.values().has(true)


func engaged_enemy_count() -> int:
	return _enemies.size()


## Clears everything (respawn / floor restart).
func reset() -> void:
	for id: int in _enemies:
		var enemy := instance_from_id(id) as Node
		var on_exit: Callable = _enemies[id]
		if is_instance_valid(enemy) and enemy.tree_exiting.is_connected(on_exit):
			enemy.tree_exiting.disconnect(on_exit)
	_enemies.clear()
	_encounters.clear()
	_refresh()


func _on_enemy_exiting(id: int) -> void:
	_enemies.erase(id)
	_refresh()


func _refresh() -> void:
	var now := not _enemies.is_empty() or not _encounters.is_empty()
	if now == in_combat:
		return
	in_combat = now
	if in_combat:
		combat_started.emit()
	else:
		combat_ended.emit()
