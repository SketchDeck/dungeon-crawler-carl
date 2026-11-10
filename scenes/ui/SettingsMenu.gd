class_name SettingsMenu
extends PanelContainer
## Settings panel used by the main menu and the pause menu: volume sliders,
## fullscreen, and keyboard remapping (click a key, then press the new one;
## Escape cancels). Works while the game is paused. Every change is saved
## straight away.

signal closed

var _sliders := {}
var _fullscreen: CheckButton
var _options := {}
var _key_buttons := {}
var _waiting_action := ""
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 1.0)
	style.border_color = Color("#53657c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	box.add_child(_heading("SETTINGS", 26))
	for bus: String in Settings.BUSES:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = {"Master": "Master volume", "Music": "Music", "SFX": "Sound effects"}[bus]
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(240, 24)
		slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(bus, v))
		row.add_child(slider)
		_sliders[bus] = slider
		box.add_child(row)
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Fullscreen"
	_fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	box.add_child(_fullscreen)
	for entry: Array in [["screen_shake", "Screen shake"],
			["assist_mode", "Assist mode (5 lives, slower boss warnings; applies from the next floor start)"],
			["colorblind", "Colour-blind warnings (attack warnings flash yellow instead of red)"]]:
		var toggle := CheckButton.new()
		toggle.name = entry[0]
		toggle.text = entry[1]
		var option: String = entry[0]
		toggle.toggled.connect(func(on: bool) -> void: Settings.set_option(option, on))
		box.add_child(toggle)
		_options[option] = toggle

	box.add_child(_heading("Keyboard controls (click, then press a key)", 15))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for entry: Array in Settings.REMAPPABLE:
		var action: String = entry[0]
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size = Vector2(150, 0)
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 28)
		button.pressed.connect(_start_rebind.bind(action))
		grid.add_child(button)
		_key_buttons[action] = button
	box.add_child(grid)
	var note := Label.new()
	note.text = "Controller buttons stay as they are. Esc always pauses."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	box.add_child(note)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var reset := Button.new()
	reset.text = "Reset keys"
	reset.custom_minimum_size = Vector2(140, 36)
	reset.pressed.connect(func() -> void: Settings.reset_keys())
	buttons.add_child(reset)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(140, 36)
	_back.pressed.connect(close)
	buttons.add_child(_back)
	box.add_child(buttons)

	Settings.changed.connect(refresh)
	refresh()
	hide()


func _heading(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#ffd34d"))
	return label


func open() -> void:
	refresh()
	show()
	_back.grab_focus()


func close() -> void:
	_waiting_action = ""
	hide()
	closed.emit()


func is_waiting_for_key() -> bool:
	return _waiting_action != ""


## Shows the current settings (also called whenever a setting changes).
func refresh() -> void:
	for bus: String in _sliders:
		(_sliders[bus] as HSlider).set_value_no_signal(Settings.volumes[bus])
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	for option: String in _options:
		(_options[option] as CheckButton).set_pressed_no_signal(bool(Settings.get(option)))
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = "Press a key..." if action == _waiting_action else Settings.key_label(action)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if _waiting_action != "":
		if key and key.pressed and not key.echo:
			if key.physical_keycode != KEY_ESCAPE:
				Settings.rebind(_waiting_action, key.physical_keycode)
			_waiting_action = ""
			refresh()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
