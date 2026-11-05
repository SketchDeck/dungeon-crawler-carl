extends Node
## The Dungeon AI watches for notable player actions, rewards them with temporary boosts, and
## announces them. Announcements are signals, so the HUD shows them without pausing play.

signal announced(title: String, headline: String, description: String, reward: String)

var _knockback_rooms: int = 0
var _damage_rooms: int = 0
var _fired_this_encounter: Dictionary = {}


func reset_run() -> void:
	_knockback_rooms = 0
	_damage_rooms = 0
	_fired_this_encounter.clear()


## Called whenever a new encounter starts, so each achievement can fire once per encounter.
func begin_encounter() -> void:
	_fired_this_encounter.clear()


func knockback_mult() -> float:
	return Config.ACH_KNOCKBACK_MULT if _knockback_rooms > 0 else 1.0


func damage_mult() -> float:
	return Config.ACH_ENV_DAMAGE_MULT if _damage_rooms > 0 else 1.0


## Enemy kicked into another enemy.
func on_enemy_collision(kicked: Node, victim: Node) -> void:
	if not _once("collision"):
		return
	_knockback_rooms = Config.ACH_KNOCKBACK_ROOMS
	var kicked_name := _enemy_name(kicked)
	var victim_name := _enemy_name(victim)
	announced.emit("NEW ACHIEVEMENT!",
		"YOU KICKED A %s INTO ANOTHER %s!" % [kicked_name, victim_name],
		"The dungeon AI appreciates your commitment to solving every problem with your feet.",
		"Reward: Increased knockback for the next three rooms.")


## Enemy killed by a spike, explosive object, or other hazard.
func on_environment_kill() -> void:
	if not _once("environment"):
		return
	_damage_rooms = Config.ACH_ENV_DAMAGE_ROOMS
	announced.emit("NEW ACHIEVEMENT!",
		"DEATH BY DECOR!",
		"The dungeon AI is deeply offended by how tidy your room was.",
		"Reward: Increased damage for the next two rooms.")


## Called when a combat room is cleared. Returns the HP reward for a flawless clear (0 if none).
func on_room_cleared(flawless: bool) -> int:
	if _knockback_rooms > 0:
		_knockback_rooms -= 1
	if _damage_rooms > 0:
		_damage_rooms -= 1
	if not flawless or not _once("flawless"):
		return 0
	announced.emit("NEW ACHIEVEMENT!",
		"UNTOUCHABLE, APPARENTLY",
		"The dungeon AI checked twice. You took no damage. It is not happy about it.",
		"Reward: +%d HP." % Config.ACH_ROOM_CLEAR_HEAL)
	return Config.ACH_ROOM_CLEAR_HEAL


func _once(key: String) -> bool:
	if _fired_this_encounter.has(key):
		return false
	_fired_this_encounter[key] = true
	return true


func _enemy_name(node: Node) -> String:
	if node != null and node.has_method("display_name"):
		return str(node.call("display_name")).to_upper()
	return "ENEMY"
