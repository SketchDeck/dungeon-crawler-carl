extends Node
## Run-level state: current floor, lives, potions, temporary upgrades and cleared rooms.
## Permanent progress (completed floors, ability unlocks) is delegated to the Save autoload.

signal lives_changed(lives: int)
signal floor_changed(floor_number: int)
signal upgrades_changed
signal game_over
signal floor_completed(floor_number: int)

const UPGRADE_INFO := {
	"kick_damage": {"name": "Steel-Toed Boots", "desc": "Kicks deal +25% damage."},
	"magic_damage": {"name": "Donut's Sparkle", "desc": "Magic deals +25% damage."},
	"knockback": {"name": "Mighty Shoves", "desc": "Knockback is +30% stronger."},
	"cooldown": {"name": "Caffeinated Reflexes", "desc": "All ability cooldowns are 20% shorter."},
	"max_hp": {"name": "Stubborn Constitution", "desc": "+25 maximum health for this floor."},
	"move_speed": {"name": "Sprinter's Socks", "desc": "Move 15% faster."},
}

var floor_number: int = 1
var lives: int = Config.LIVES
var potions := PotionInventory.new()
var upgrades: Array[String] = []
var cleared_rooms: Dictionary = {}
var reward_taken: Dictionary = {}


func start_new_game() -> void:
	_enter_floor(1, false)


func continue_game() -> void:
	_enter_floor(Save.unlocked_floor(), false)


func start_floor(number: int, carry_potions: bool) -> void:
	_enter_floor(clampi(number, 1, Config.FLOOR_COUNT), carry_potions)


func _enter_floor(number: int, carry_potions: bool) -> void:
	floor_number = number
	lives = Config.LIVES
	if not carry_potions:
		potions = PotionInventory.new(Config.POTION_START)
		DungeonAI.reset_run()
	upgrades.clear()
	cleared_rooms.clear()
	reward_taken.clear()
	floor_changed.emit(floor_number)
	lives_changed.emit(lives)
	upgrades_changed.emit()


## Called when the player dies. Returns true while lives remain.
func lose_life() -> bool:
	lives = maxi(0, lives - 1)
	lives_changed.emit(lives)
	if lives == 0:
		game_over.emit()
		return false
	return true


## Game over: restart the current floor with a fresh run state for that floor.
func restart_floor() -> void:
	_enter_floor(floor_number, false)


func mark_room_cleared(room_id: String) -> void:
	cleared_rooms[room_id] = true


func is_room_cleared(room_id: String) -> bool:
	return cleared_rooms.has(room_id)


## A challenge room's upgrade chest was used. Separate from clearing, so the chest can wait.
func mark_reward_taken(room_id: String) -> void:
	reward_taken[room_id] = true


func is_reward_taken(room_id: String) -> bool:
	return reward_taken.has(room_id)


func add_upgrade(upgrade_id: String) -> void:
	if upgrade_id not in upgrades:
		upgrades.append(upgrade_id)
	upgrades_changed.emit()


func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in upgrades


## Multiplier for a stat from temporary upgrades. Stats: kick_damage, magic_damage,
## knockback, cooldown, move_speed.
func modifier(stat: String) -> float:
	match stat:
		"kick_damage":
			return 1.0 + (Config.UPGRADE_KICK_DAMAGE if has_upgrade("kick_damage") else 0.0)
		"magic_damage":
			return 1.0 + (Config.UPGRADE_MAGIC_DAMAGE if has_upgrade("magic_damage") else 0.0)
		"knockback":
			return 1.0 + (Config.UPGRADE_KNOCKBACK if has_upgrade("knockback") else 0.0)
		"cooldown":
			return 1.0 - (Config.UPGRADE_COOLDOWN if has_upgrade("cooldown") else 0.0)
		"move_speed":
			return 1.0 + (Config.UPGRADE_MOVE_SPEED if has_upgrade("move_speed") else 0.0)
	return 1.0


func bonus_max_hp() -> int:
	return Config.UPGRADE_MAX_HP if has_upgrade("max_hp") else 0


## Called after a floor boss is defeated. Permanent unlocks go to the save file.
func complete_floor() -> void:
	var finished := floor_number
	Save.complete_floor(finished)
	if finished == 1:
		Save.unlock_ability("explosive_kick")
	elif finished == 2:
		Save.unlock_ability("area_burst")
	upgrades.clear()
	floor_completed.emit(finished)


func debug_unlock_everything() -> void:
	Save.unlock_ability("explosive_kick")
	Save.unlock_ability("area_burst")
	Save.complete_floor(1)
	Save.complete_floor(2)
