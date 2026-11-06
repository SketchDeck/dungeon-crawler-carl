extends Node
## Autoload: reads and writes the local save file (JSON in user://). A missing,
## unreadable or malformed file falls back to an empty save without crashing.
## Holds progress only (completed floors, unlocked floor, permanent ability
## unlocks); never an in-progress room. Settings are added in Milestone 8.

const DEFAULT_PATH := "user://save.json"
const VERSION := 1

## Tests point this at a separate file so they never touch the real save.
var save_path := DEFAULT_PATH


func load_data() -> Dictionary:
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


func save_data(data: Dictionary) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file %s." % save_path)
		return false
	var out := data.duplicate()
	out["version"] = VERSION
	file.store_string(JSON.stringify(out, "\t"))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
