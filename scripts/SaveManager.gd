extends Node
## Autoload: reads and writes the local save file (JSON in user://). A missing,
## unreadable or malformed file falls back to an empty save without crashing.
## The file holds progress (completed floors, unlocked floor, ability unlocks,
## whether a game has been started) at the top level and the player's settings
## under "settings". Never an in-progress room.
##
## Callers update their part with `update()`, which merges into the file, so
## saving progress never wipes settings and vice versa.

const DEFAULT_PATH := "user://save.json"
const VERSION := 1

## Tests point this at a separate file so they never touch the real save.
var save_path := DEFAULT_PATH:
	set(value):
		save_path = value
		_cache = {}
		_loaded = false

var _cache := {}
var _loaded := false


## The whole save (a copy). Empty if there is no valid save.
func load_data() -> Dictionary:
	_ensure_loaded()
	return _cache.duplicate(true)


## Merges `values` into the save and writes it. Returns false if writing failed.
func update(values: Dictionary) -> bool:
	_ensure_loaded()
	for key: Variant in values:
		_cache[key] = values[key]
	return _write()


## Replaces the whole save.
func save_data(data: Dictionary) -> bool:
	_cache = data.duplicate(true)
	_loaded = true
	return _write()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_cache = {}
	_loaded = true


## Forget the cached copy and read the file again (tests simulate a new session).
func reload() -> void:
	_loaded = false
	_ensure_loaded()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_cache = _read()


func _read() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file %s; using defaults." % save_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save file %s is invalid; using defaults." % save_path)
		return {}
	return parsed


func _write() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file %s." % save_path)
		return false
	var out := _cache.duplicate(true)
	out["version"] = VERSION
	file.store_string(JSON.stringify(out, "\t"))
	return true
