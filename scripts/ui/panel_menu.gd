class_name PanelMenu
extends CanvasLayer
## A centered panel with a title, body text and buttons. Used for pause, game over, the treasure
## choice, and floor completion. Runs while the game is paused. Keyboard, gamepad and mouse work.

signal chosen(option_id: String)

## Option id to pick when Escape or the cancel button is pressed (for example "resume").
var cancel_option: String = ""

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _open: bool = false


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# A root Control under a CanvasLayer needs an explicit size; children then anchor to it.
	var root := Control.new()
	root.size = get_viewport().get_visible_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.05, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#15101f")
	style.border_color = Color("#ffb347")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color("#ffd166"))
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title.add_theme_constant_override("outline_size", 6)
	column.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size = Vector2(430, 0)
	_body.add_theme_color_override("font_color", Color("#d9d2e6"))
	column.add_child(_body)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)

	_set_visible(false)


func show_menu(title: String, body: String, options: Array) -> void:
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	for child in _buttons.get_children():
		child.queue_free()
	var first: Button = null
	for option in options:
		var button := Button.new()
		button.text = str(option.get("label", ""))
		button.custom_minimum_size = Vector2(430, 46)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_pressed.bind(str(option.get("id", ""))))
		_buttons.add_child(button)
		if first == null:
			first = button
	_set_visible(true)
	_open = true
	if first != null:
		first.call_deferred("grab_focus")


func is_open() -> bool:
	return _open


func _on_pressed(option_id: String) -> void:
	Sfx.play("ui")
	_close()
	chosen.emit(option_id)


func _close() -> void:
	_open = false
	_set_visible(false)


func _set_visible(value: bool) -> void:
	visible = value
	if _dim != null:
		_dim.visible = value
		_panel.visible = value


func _unhandled_input(event: InputEvent) -> void:
	if not _open or cancel_option == "":
		return
	if event.is_action_pressed(Controls.PAUSE) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		var option := cancel_option
		_close()
		chosen.emit(option)
