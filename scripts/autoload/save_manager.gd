extends Node
## Local save file in user:// (JSON). Missing or corrupt files fall back to defaults and never crash.
## Saves only progression and settings, never the state of an active room.

const VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_save()


static func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"unlocked_floor": 1,
		"completed_floors": [],
		"abilities": {"explosive_kick": false, "area_burst": false},
		"settings": {"master": 1.0, "music": 0.8, "sfx": 1.0, "fullscreen": false},
	}


func has_save() -> bool:
	return FileAccess.file_exists(Config.SAVE_PATH)


func load_save() -> void:
	data = default_data()
	if not FileAccess.file_exists(Config.SAVE_PATH):
		return
	var file := FileAccess.open(Config.SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file; using defaults.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is not valid JSON; using defaults.")
		return
	data = _sanitize(parsed)


func save_game() -> bool:
	var file := FileAccess.open(Config.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func unlocked_floor() -> int:
	return int(data.get("unlocked_floor", 1))


func is_floor_completed(floor_number: int) -> bool:
	return floor_number in data.get("completed_floors", [])


func complete_floor(floor_number: int) -> void:
	var done: Array = data.get("completed_floors", [])
	if floor_number not in done:
		done.append(floor_number)
	data["completed_floors"] = done
	data["unlocked_floor"] = clampi(maxi(unlocked_floor(), floor_number + 1), 1, Config.FLOOR_COUNT)
	save_game()


func has_ability(ability_id: String) -> bool:
	return bool(data.get("abilities", {}).get(ability_id, false))


func unlock_ability(ability_id: String) -> void:
	var abilities: Dictionary = data.get("abilities", {})
	abilities[ability_id] = true
	data["abilities"] = abilities
	save_game()


func get_setting(key: String) -> Variant:
	return data.get("settings", {}).get(key, default_data()["settings"][key])


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	save_game()


static func _sanitize(raw: Dictionary) -> Dictionary:
	var clean := default_data()
	var floor_value: Variant = raw.get("unlocked_floor", 1)
	if typeof(floor_value) == TYPE_FLOAT or typeof(floor_value) == TYPE_INT:
		clean["unlocked_floor"] = clampi(int(floor_value), 1, Config.FLOOR_COUNT)
	var done: Variant = raw.get("completed_floors", [])
	if typeof(done) == TYPE_ARRAY:
		var valid: Array = []
		for item in done:
			if typeof(item) in [TYPE_FLOAT, TYPE_INT] and int(item) >= 1 and int(item) <= Config.FLOOR_COUNT:
				valid.append(int(item))
		clean["completed_floors"] = valid
	var abilities: Variant = raw.get("abilities", {})
	if typeof(abilities) == TYPE_DICTIONARY:
		for key in ["explosive_kick", "area_burst"]:
			var flag: Variant = abilities.get(key, false)
			clean["abilities"][key] = typeof(flag) == TYPE_BOOL and bool(flag)
	var settings: Variant = raw.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		for key in ["master", "music", "sfx"]:
			var value: Variant = settings.get(key, clean["settings"][key])
			if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
				clean["settings"][key] = clampf(float(value), 0.0, 1.0)
		if typeof(settings.get("fullscreen", false)) == TYPE_BOOL:
			clean["settings"]["fullscreen"] = settings["fullscreen"]
	return clean
