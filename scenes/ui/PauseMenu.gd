class_name PauseMenu
extends CanvasLayer
## Esc / Start pauses: Resume, Settings, Main Menu. Doesn't open over the
## Game Over, Floor Complete or treasure screens (they already pause the game).

signal main_menu_requested

var resume_button: Button
var settings_button: Button
var controls_button: Button
var controls_label: Label
var menu_button: Button

var _panel: PanelContainer
var _settings: SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 1.0)
	style.border_color = Color("#ffd34d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#ffd34d"))
	box.add_child(title)
	resume_button = _button(box, "Resume", close)
	controls_button = _button(box, "Controls", toggle_controls)
	controls_label = Label.new()
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.hide()
	box.add_child(controls_label)
	settings_button = _button(box, "Settings", _open_settings)
	menu_button = _button(box, "Main Menu", func() -> void:
		close()
		main_menu_requested.emit())
	var note := Label.new()
	note.text = "Leaving restarts this floor next time\n(completed floors and unlocks are saved)."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	box.add_child(note)
	_settings = SettingsMenu.new()
	_settings.closed.connect(func() -> void:
		_panel.show()
		settings_button.grab_focus())
	center.add_child(_settings)
	hide()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 42)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Shows or hides the list of controls (current keys or controller buttons).
func toggle_controls() -> void:
	controls_label.visible = not controls_label.visible
	if controls_label.visible:
		controls_label.text = controls_text()


static func controls_text() -> String:
	var rows := [
		["Move", Settings.format_prompts("{move_left} / {move_right}")],
		["Jump (hold for higher)", Settings.prompt_label("jump")],
		["Dodge (brief invulnerability)", Settings.prompt_label("dodge")],
		["Switch Carl / Donut", Settings.prompt_label("switch_mode")],
		["Kick combo / magic missile", Settings.prompt_label("basic_attack")],
		["Hold: power kick / charged blast", Settings.prompt_label("charged_attack")],
		["Special (once unlocked)", Settings.prompt_label("special_attack")],
		["Drink potion", Settings.prompt_label("use_potion")],
		["Interact (chests, fountains, shops)", Settings.prompt_label("interact")],
	]
	var lines: Array[String] = []
	for r: Array in rows:
		lines.append("%-36s %s" % [r[0], r[1]])
	lines.append("")
	lines.append("Boot icon over an enemy = use kicks. Star = use magic.")
	lines.append("Power-kick an enemy up, then hit it with magic: double damage.")
	return "\n".join(lines)


func is_open() -> bool:
	return visible


## Pauses the game and shows the menu. Returns false if something else has
## already paused the game.
func open() -> bool:
	if visible or get_tree().paused:
		return false
	show()
	_panel.show()
	_settings.hide()
	controls_label.hide()
	get_tree().paused = true
	resume_button.grab_focus()
	return true


func close() -> void:
	if not visible:
		return
	_settings.hide()
	hide()
	get_tree().paused = false


func _open_settings() -> void:
	_panel.hide()
	_settings.open()


func _unhandled_input(event: InputEvent) -> void:
	# B / Esc backs out of the pause menu too.
	if visible and not _settings.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause"):
		return
	if visible:
		if not _settings.visible:
			close()
	else:
		open()
	get_viewport().set_input_as_handled()
