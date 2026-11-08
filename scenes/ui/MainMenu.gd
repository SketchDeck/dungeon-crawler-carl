class_name MainMenu
extends Control
## Title screen: Continue (once a game has been started; goes to the latest
## unlocked floor), floor select (once more than one floor is unlocked), New
## Game (asks before erasing progress), Settings and Quit (not on the web).
## Starting a floor from here is a fresh run: 3 lives, 3 potions, no upgrades.

const GAME_SCENE := "res://scenes/main/Main.tscn"

## Tests turn this off and read `requested_scene` instead of changing scenes.
var navigate := true
var requested_scene := ""

var continue_button: Button
var new_game_button: Button
var settings_button: Button
var quit_button: Button
var floor_buttons: Array[Button] = []

var _menu: VBoxContainer
var _floor_row: HBoxContainer
var _confirm: PanelContainer
var _settings: SettingsMenu
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Audio.play_music("menu")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)

	var title := Label.new()
	title.text = "DUNGEON CRAWLER CARL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#ffd34d"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	column.add_child(title)
	var tagline := Label.new()
	tagline.text = "Starring Carl (feet) and Princess Donut (magic). A fan-made prototype."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	column.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	column.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_menu)
	continue_button = _button("Continue", _on_continue)
	_floor_row = HBoxContainer.new()
	_floor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_floor_row.add_theme_constant_override("separation", 8)
	_menu.add_child(_floor_row)
	new_game_button = _button("New Game", _on_new_game)
	settings_button = _button("Settings", _on_settings)
	quit_button = _button("Quit", func() -> void: get_tree().quit())
	quit_button.visible = not OS.has_feature("web")

	_confirm = _make_confirm()
	center.add_child(_confirm)
	_settings = SettingsMenu.new()
	_settings.closed.connect(_on_settings_closed)
	center.add_child(_settings)
	refresh()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	_menu.add_child(b)
	return b


func _make_confirm() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.05, 1.0)
	style.border_color = Color("#d84a3a")
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var label := Label.new()
	label.text = "Start a new game?\nThis erases your completed floors and unlocked abilities.\nYour settings are kept."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var yes := Button.new()
	yes.name = "Confirm"
	yes.text = "Erase and start"
	yes.custom_minimum_size = Vector2(170, 40)
	yes.pressed.connect(start_new_game)
	row.add_child(yes)
	var no := Button.new()
	no.name = "Cancel"
	no.text = "Cancel"
	no.custom_minimum_size = Vector2(170, 40)
	no.pressed.connect(func() -> void:
		_confirm.hide()
		_menu.show()
		new_game_button.grab_focus())
	row.add_child(no)
	box.add_child(row)
	panel.hide()
	return panel


## Updates Continue and floor select from the saved progress.
func refresh() -> void:
	var can_continue := GameManager.can_continue()
	continue_button.visible = can_continue
	continue_button.text = "Continue - %s" % FloorData.floor_name(GameManager.continue_floor())
	for b in floor_buttons:
		b.queue_free()
	floor_buttons.clear()
	var last := GameManager.continue_floor()
	_floor_row.visible = can_continue and last > 1
	if _floor_row.visible:
		for f in range(1, last + 1):
			var b := Button.new()
			b.text = "Play %s" % FloorData.floor_name(f)
			b.custom_minimum_size = Vector2(136, 34)
			b.pressed.connect(start_floor.bind(f))
			_floor_row.add_child(b)
			floor_buttons.append(b)
	(continue_button if can_continue else new_game_button).grab_focus()


func is_confirming() -> bool:
	return _confirm.visible


func _on_continue() -> void:
	start_floor(GameManager.continue_floor())


func _on_new_game() -> void:
	if GameManager.can_continue():
		_menu.hide()
		_confirm.show()
		(_confirm.find_child("Cancel", true, false) as Button).grab_focus()
	else:
		start_new_game()


func start_new_game() -> void:
	GameManager.new_game()
	start_floor(1)


## Starts a fresh run of a floor (3 lives, 3 potions, no upgrades).
func start_floor(floor_number: int) -> void:
	GameManager.floor_number = floor_number
	GameManager.reset_lives()
	_go(GAME_SCENE)


func _on_settings() -> void:
	_menu.hide()
	_settings.open()


func _on_settings_closed() -> void:
	_menu.show()
	settings_button.grab_focus()


func _go(path: String) -> void:
	requested_scene = path
	if navigate:
		get_tree().change_scene_to_file(path)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#141a24"))
	# Dungeon bricks.
	var y := 0.0
	var row := 0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.03))
		var x := 32.0 if row % 2 == 1 else 0.0
		while x < size.x:
			draw_line(Vector2(x, y), Vector2(x, y + 32.0), Color(1, 1, 1, 0.03))
			x += 64.0
		y += 32.0
		row += 1
	# Torches.
	for tx in [size.x * 0.12, size.x * 0.88]:
		var flick := 1.0 + 0.1 * sin(_t * 12.0 + tx)
		draw_circle(Vector2(tx, 180), 60.0 * flick, Color(1.0, 0.6, 0.2, 0.06))
		draw_rect(Rect2(tx - 4, 180, 8, 40), Color("#5a4030"))
		draw_circle(Vector2(tx, 174), 10.0 * flick, Color("#ffb347"))
		draw_circle(Vector2(tx, 170), 5.0 * flick, Color("#fff0a0"))
