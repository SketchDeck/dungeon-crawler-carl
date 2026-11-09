extends Node
## Autoload: run-wide state that outlives individual rooms (lives, current
## floor) plus permanent progress (completed floors, unlocked floor, ability
## unlocks), which is saved through SaveManager.

signal lives_changed(lives: int)
signal floor_completed(floor_number: int)
signal ability_unlocked(id: StringName)
## Gameplay events the Dungeon AI listens to (emitted by every enemy).
signal enemy_collided(enemy: EnemyBase, other: EnemyBase)
signal enemy_died(enemy: EnemyBase)
## A magic hit landed on a launched enemy.
signal enemy_juggled(enemy: EnemyBase)
## An enemy shrugged off a hit (shield, shell).
signal enemy_resisted(enemy: EnemyBase, hit: Hit)
## An Armored Slime's shell was cracked.
signal shell_cracked(enemy: EnemyBase)

const MAX_LIVES := 3
const EXPLOSIVE_KICK := &"explosive_kick"
const AREA_BURST := &"area_burst"
## Beating a floor permanently unlocks this ability.
const FLOOR_UNLOCKS := {1: EXPLOSIVE_KICK, 2: AREA_BURST}
const ABILITY_NAMES := {
	EXPLOSIVE_KICK: "Explosive Kick (Carl: press or hold L)",
	AREA_BURST: "Area Magic Burst (Donut: press L)",
}

var lives := MAX_LIVES
var floor_number := 1
var completed_floors: Array[int] = []
## Highest floor the player may start from (Floor 1 beaten unlocks Floor 2).
var highest_unlocked_floor := 1
var unlocked_abilities: Array[StringName] = []
## A game has been started (New Game), so the main menu offers Continue.
var game_started := false


func _ready() -> void:
	load_progress()


## Removes exactly one life. Returns the lives remaining.
func lose_life() -> int:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives


func reset_lives() -> void:
	lives = MAX_LIVES
	lives_changed.emit(lives)


func complete_floor(number: int) -> void:
	if not completed_floors.has(number):
		completed_floors.append(number)
	highest_unlocked_floor = maxi(highest_unlocked_floor, number + 1)
	if FLOOR_UNLOCKS.has(number):
		unlock_ability(FLOOR_UNLOCKS[number])
	save_progress()
	floor_completed.emit(number)


## Permanently unlocks a special ability. Returns false if already unlocked.
func unlock_ability(id: StringName) -> bool:
	if unlocked_abilities.has(id):
		return false
	unlocked_abilities.append(id)
	save_progress()
	ability_unlocked.emit(id)
	return true


func is_unlocked(id: StringName) -> bool:
	return unlocked_abilities.has(id)


## Debug option: unlock both special abilities.
func debug_unlock_all() -> void:
	for id: StringName in FLOOR_UNLOCKS.values():
		unlock_ability(id)


## Forgets all progress in memory (tests, and New Game in Milestone 8).
func reset_progress() -> void:
	completed_floors.clear()
	highest_unlocked_floor = 1
	unlocked_abilities.clear()
	game_started = false


## Erases progress (keeps settings) and starts a fresh game record.
func new_game() -> void:
	reset_progress()
	game_started = true
	save_progress()


## Main menu Continue is available once a game has been started.
func can_continue() -> bool:
	return game_started


## The latest floor the player can start from that actually exists.
func continue_floor() -> int:
	var f := highest_unlocked_floor
	while f > 1 and not FloorData.has_floor(f):
		f -= 1
	return f


func save_progress() -> void:
	var abilities: Array[String] = []
	for id in unlocked_abilities:
		abilities.append(String(id))
	SaveManager.update({
		"game_started": game_started,
		"completed_floors": completed_floors.duplicate(),
		"highest_unlocked_floor": highest_unlocked_floor,
		"unlocked_abilities": abilities,
	})


## Reads progress from the save file, ignoring anything malformed.
func load_progress() -> void:
	reset_progress()
	var data := SaveManager.load_data()
	var floors: Variant = data.get("completed_floors", [])
	if floors is Array:
		for f: Variant in floors:
			if (f is float or f is int) and not completed_floors.has(int(f)):
				completed_floors.append(int(f))
	var highest: Variant = data.get("highest_unlocked_floor", 1)
	if highest is float or highest is int:
		highest_unlocked_floor = maxi(1, int(highest))
	var started: Variant = data.get("game_started", false)
	# Saves from before the flag existed count as started if they have progress.
	game_started = (started is bool and started) or not completed_floors.is_empty()
	var abilities: Variant = data.get("unlocked_abilities", [])
	if abilities is Array:
		for a: Variant in abilities:
			if a is String and FLOOR_UNLOCKS.values().has(StringName(a)) and not unlocked_abilities.has(StringName(a)):
				unlocked_abilities.append(StringName(a))


func is_floor_completed(number: int) -> bool:
	return completed_floors.has(number)
