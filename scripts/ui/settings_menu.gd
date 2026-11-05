class_name SettingsMenu
extends Control
## Settings: master, music and effects volume, and fullscreen. Values are saved to the save file.
## Input remapping is not included in this build (the spec lists it as "if feasible"); controls are
## defined in scripts/autoload/controls.gd.

signal back_pressed

var _sliders: Dictionary = {}
var _fullscreen: CheckBox


func _ready() -> void:
	# A Control directly under a CanvasLayer gets no parent rect, so give it the viewport size.
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#15101f")
	style.border_color = Color("#ffb347")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffd166"))
	column.add_child(title)

	_add_slider(column, "master", "Master volume")
	_add_slider(column, "music", "Music")
	_add_slider(column, "sfx", "Effects")

	_fullscreen = CheckBox.new()
	_fullscreen.text = "Fullscreen"
	_fullscreen.button_pressed = bool(Save.get_setting("fullscreen"))
	_fullscreen.add_theme_font_size_override("font_size", 18)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	column.add_child(_fullscreen)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(400, 46)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: back_pressed.emit())
	column.add_child(back)
	back.grab_focus.call_deferred()


func _add_slider(column: VBoxContainer, key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Save.get_setting(key))
	slider.custom_minimum_size = Vector2(230, 24)
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	_sliders[key] = slider


func _on_slider_changed(value: float, key: String) -> void:
	Save.set_setting(key, value)
	Sfx.apply_volumes()


func _on_fullscreen_toggled(on: bool) -> void:
	Save.set_setting("fullscreen", on)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
