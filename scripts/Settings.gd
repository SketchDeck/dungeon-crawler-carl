extends Node
## Autoload: player settings (volume per audio bus, fullscreen, keyboard
## remapping). Applied on startup and saved under "settings" in the save file.

signal changed

const BUSES := ["Master", "Music", "SFX"]
## Actions the player may rebind on the keyboard, with their display names.
## Pause stays on Escape so you can never lock yourself out of the menu.
const REMAPPABLE := [
	["move_left", "Move left"], ["move_right", "Move right"], ["jump", "Jump"], ["dodge", "Dodge"],
	["basic_attack", "Kick / missile"], ["charged_attack", "Power kick / blast"],
	["special_attack", "Special"], ["switch_mode", "Switch Carl/Donut"],
	["use_potion", "Drink potion"], ["interact", "Interact"],
]

## Bus name -> linear volume 0..1.
var volumes := {"Master": 0.8, "Music": 0.7, "SFX": 0.8}
var fullscreen := false
## Action -> physical keycode replacing that action's first keyboard key.
var key_overrides := {}
## True after the player last used a controller (prompts show pad buttons).
var using_controller := false

const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}
const PAD_AXES := {JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


## Tracks whether the player is on keyboard or controller, for prompts.
func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton \
		or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var keys := event is InputEventKey or event is InputEventMouseButton
	if pad and not using_controller:
		using_controller = true
		changed.emit()
	elif keys and using_controller:
		using_controller = false
		changed.emit()


## What to show in prompts for `action`: the controller button while the player
## is using a controller, otherwise the keyboard key.
func prompt_label(action: String) -> String:
	if using_controller:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				return PAD_BUTTONS.get((event as InputEventJoypadButton).button_index, "Button")
			if event is InputEventJoypadMotion:
				return PAD_AXES.get((event as InputEventJoypadMotion).axis, "Stick")
	return key_label(action)


func load_settings() -> void:
	volumes = {"Master": 0.8, "Music": 0.7, "SFX": 0.8}
	fullscreen = false
	var data: Variant = SaveManager.load_data().get("settings", {})
	if data is Dictionary:
		var vols: Variant = data.get("volumes", {})
		if vols is Dictionary:
			for bus: String in BUSES:
				var v: Variant = vols.get(bus)
				if v is float or v is int:
					volumes[bus] = clampf(float(v), 0.0, 1.0)
		var fs: Variant = data.get("fullscreen", false)
		fullscreen = fs is bool and fs
		key_overrides.clear()
		var keys: Variant = data.get("keys", {})
		if keys is Dictionary:
			for action: Variant in keys:
				var code: Variant = keys[action]
				if action is String and InputMap.has_action(action) and _is_remappable(action) and (code is float or code is int):
					key_overrides[action] = int(code)
	apply()


func save_settings() -> void:
	SaveManager.update({"settings": {"volumes": volumes.duplicate(), "fullscreen": fullscreen,
		"keys": key_overrides.duplicate()}})


## Pushes every setting to the engine (audio buses, window, input map).
func apply() -> void:
	for bus: String in BUSES:
		_apply_volume(bus)
	_apply_fullscreen()
	InputMap.load_from_project_settings()
	for action: String in key_overrides:
		_apply_key(action, key_overrides[action])
	changed.emit()


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	save_settings()
	changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()
	changed.emit()


## Binds `action` to a new keyboard key (replacing its first keyboard key).
func rebind(action: String, physical_keycode: Key) -> void:
	if not _is_remappable(action):
		return
	key_overrides[action] = int(physical_keycode)
	_apply_key(action, physical_keycode)
	save_settings()
	changed.emit()


func reset_keys() -> void:
	key_overrides.clear()
	InputMap.load_from_project_settings()
	save_settings()
	changed.emit()


## The keyboard key currently bound to `action`, as text (e.g. "Space").
## Replaces {action_name} tokens with the current key or controller button,
## e.g. "{jump} jumps" -> "Space jumps" or "A jumps".
func format_prompts(text: String) -> String:
	if not "{" in text:
		return text
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	var out := text
	for m in re.search_all(text):
		var action := m.get_string(1)
		if InputMap.has_action(action):
			out = out.replace(m.get_string(0), prompt_label(action))
	return out


func key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "—"


func _is_remappable(action: String) -> bool:
	for entry: Array in REMAPPABLE:
		if entry[0] == action:
			return true
	return false


func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var v: float = volumes[bus]
	AudioServer.set_bus_mute(index, v <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(v, 0.001)))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_key(action: String, physical_keycode: int) -> void:
	# Rebuild the action: new key first (it's the one shown in the UI), then
	# secondary keys (e.g. arrow keys) that don't clash, then controller inputs.
	var keys: Array[InputEvent] = []
	var others: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(event)
		else:
			others.append(event)
	InputMap.action_erase_events(action)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)
	for i in range(1, keys.size()):
		if (keys[i] as InputEventKey).physical_keycode != physical_keycode:
			InputMap.action_add_event(action, keys[i])
	for event in others:
		InputMap.action_add_event(action, event)
