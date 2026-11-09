extends Node
## Autoload: run-wide state that outlives individual rooms (lives, current
## floor) plus permanent progress (completed floors, unlocked floor, ability
## unlocks), which is saved through SaveManager. The "profile" (achievements
## ever earned, hats, best runs) is saved separately and survives New Game.

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
## Any enemy took damage from a hit.
signal enemy_damaged(enemy: EnemyBase, amount: float, hit: Hit)
## A cracked wall was broken open.
signal wall_broken
signal profile_changed

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

## Cosmetic hats for Carl, won from gold loot boxes: id -> display name.
const HATS := {
	"party_hat": "Party Hat", "crown": "Tiny Crown", "traffic_cone": "Traffic Cone",
	"viking": "Viking Helmet", "propeller": "Propeller Cap", "chef": "Chef's Toque",
}
## Profile: achievement id (String) -> times earned.
var achievements := {}
var owned_hats: Array[String] = []
var equipped_hat := ""
## Floor number (String) -> {"viewers", "time", "grade"} of the best run.
var best_runs := {}
## Date ("YYYY-MM-DD") -> best Daily Run viewers.
var daily_best := {}
## One-time tips already shown (profile).
var tips_seen: Array[String] = []

## Hard mode (unlocked by beating Floor 2): tougher enemies, a sponsor event
## on every floor, more viewers. Saved with progress.
var hard_mode := false
## The current run is today's Daily Run (fixed seed, two sponsor events).
var daily_run := false


func _ready() -> void:
	load_progress()
	load_profile()


## Removes exactly one life. Returns the lives remaining.
func lose_life() -> int:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives


## 3 lives, or 5 in assist mode.
func max_lives() -> int:
	return Settings.max_lives()


func reset_lives() -> void:
	lives = max_lives()
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
	hard_mode = false
	daily_run = false
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
		"hard_mode": hard_mode,
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
	var hard: Variant = data.get("hard_mode", false)
	hard_mode = hard is bool and hard and completed_floors.has(2)
	var abilities: Variant = data.get("unlocked_abilities", [])
	if abilities is Array:
		for a: Variant in abilities:
			if a is String and FLOOR_UNLOCKS.values().has(StringName(a)) and not unlocked_abilities.has(StringName(a)):
				unlocked_abilities.append(StringName(a))


# --- Profile -------------------------------------------------------------------

func record_achievement(id: StringName) -> bool:
	var key := String(id)
	var first := not achievements.has(key)
	achievements[key] = int(achievements.get(key, 0)) + 1
	save_profile()
	return first


func has_achievement(id: StringName) -> bool:
	return achievements.has(String(id))


## Unlocks a random hat you don't own yet and wears it. Returns its id, or ""
## if you have them all.
func unlock_random_hat(rng: RandomNumberGenerator) -> String:
	var missing: Array[String] = []
	for id: String in HATS:
		if not owned_hats.has(id):
			missing.append(id)
	if missing.is_empty():
		return ""
	var id := missing[rng.randi_range(0, missing.size() - 1)]
	owned_hats.append(id)
	equipped_hat = id
	save_profile()
	return id


func equip_hat(id: String) -> void:
	if id != "" and not owned_hats.has(id):
		return
	equipped_hat = id
	save_profile()


## Saves a floor run if it beats the best viewer count. Returns true if it did.
func record_run(summary: Dictionary) -> bool:
	var key := str(summary.get("floor", 1))
	var best: Dictionary = best_runs.get(key, {})
	if not best.is_empty() and int(best.get("viewers", 0)) >= int(summary.get("viewers", 0)):
		return false
	best_runs[key] = {"viewers": int(summary.get("viewers", 0)), "time": float(summary.get("time", 0.0)),
		"grade": String(summary.get("grade", "D"))}
	save_profile()
	return true


func best_run(floor_number: int) -> Dictionary:
	return best_runs.get(str(floor_number), {})


## Forgets achievements, hats and best runs (tests).
func reset_profile() -> void:
	achievements.clear()
	owned_hats.clear()
	equipped_hat = ""
	best_runs.clear()
	daily_best.clear()
	tips_seen.clear()


func save_profile() -> void:
	SaveManager.update({"profile": {
		"achievements": achievements.duplicate(),
		"hats": owned_hats.duplicate(),
		"equipped_hat": equipped_hat,
		"best_runs": best_runs.duplicate(true),
		"daily_best": daily_best.duplicate(),
		"tips_seen": tips_seen.duplicate(),
	}})
	profile_changed.emit()


func load_profile() -> void:
	reset_profile()
	var data: Variant = SaveManager.load_data().get("profile", {})
	if not data is Dictionary:
		return
	var ach: Variant = data.get("achievements", {})
	if ach is Dictionary:
		for k: Variant in ach:
			if k is String and Achievements.has(StringName(k)) and (ach[k] is float or ach[k] is int):
				achievements[k] = int(ach[k])
	var hats: Variant = data.get("hats", [])
	if hats is Array:
		for h: Variant in hats:
			if h is String and HATS.has(h) and not owned_hats.has(h):
				owned_hats.append(h)
	var eq: Variant = data.get("equipped_hat", "")
	equipped_hat = eq if eq is String and owned_hats.has(eq) else ""
	var tips: Variant = data.get("tips_seen", [])
	if tips is Array:
		for t: Variant in tips:
			if t is String and not tips_seen.has(t):
				tips_seen.append(t)
	var daily: Variant = data.get("daily_best", {})
	if daily is Dictionary:
		for k: Variant in daily:
			if k is String and (daily[k] is float or daily[k] is int):
				daily_best[k] = int(daily[k])
	var runs: Variant = data.get("best_runs", {})
	if runs is Dictionary:
		for k: Variant in runs:
			var r: Variant = runs[k]
			if k is String and r is Dictionary:
				best_runs[k] = {"viewers": int(r.get("viewers", 0)), "time": float(r.get("time", 0.0)),
					"grade": str(r.get("grade", "D"))}


func can_use_hard_mode() -> bool:
	return completed_floors.has(2)


func set_hard_mode(value: bool) -> void:
	hard_mode = value and can_use_hard_mode()
	save_progress()


static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


## The seed for a day's Daily Run (the same for everyone on that day).
static func daily_seed(date: String) -> int:
	return absi(hash("dcc-daily-" + date))


func can_play_daily() -> bool:
	return completed_floors.has(1)


func record_daily(date: String, viewers: int) -> bool:
	if int(daily_best.get(date, -1)) >= viewers:
		return false
	daily_best[date] = viewers
	save_profile()
	return true


## Marks a tip as shown. Returns true the first time only.
func see_tip(id: String) -> bool:
	if tips_seen.has(id):
		return false
	tips_seen.append(id)
	save_profile()
	return true


func is_floor_completed(number: int) -> bool:
	return completed_floors.has(number)
