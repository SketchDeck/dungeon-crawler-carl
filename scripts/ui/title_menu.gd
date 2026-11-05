class_name TitleMenu
extends Control
## Main menu: New Game, Continue (when a save exists), Settings, Quit. Drawn with a slow animated
## dungeon backdrop so the first thing players see already feels alive.

signal new_game_pressed
signal continue_pressed
signal settings_pressed

var _t: float = 0.0
var _embers: Array = []
var _buttons: VBoxContainer
var _quit_button: Button = null


func _ready() -> void:
	# A Control directly under a CanvasLayer gets no parent rect, so give it the viewport size.
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in range(46):
		_embers.append({
			"x": Decor.hash_float(i * 7 + 1), "y": Decor.hash_float(i * 13 + 5),
			"s": 0.4 + Decor.hash_float(i * 3 + 9) * 1.2, "p": Decor.hash_float(i + 21) * TAU,
		})
	var title := Label.new()
	title.text = "DUNGEON CRAWLER CARL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-480, 70)
	title.size = Vector2(960, 70)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#ffd166"))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	add_child(title)

	var sub := Label.new()
	sub.text = "a 2D platformer with a princess on his shoulder"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-480, 140)
	sub.size = Vector2(960, 26)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color("#c9b8d8"))
	add_child(sub)

	_buttons = VBoxContainer.new()
	_buttons.set_anchors_preset(Control.PRESET_CENTER)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buttons.grow_vertical = Control.GROW_DIRECTION_BOTH
	_buttons.position = Vector2(-150, -40)
	_buttons.custom_minimum_size = Vector2(300, 0)
	_buttons.add_theme_constant_override("separation", 12)
	add_child(_buttons)

	var new_button := _make_button("New Game")
	new_button.pressed.connect(func() -> void: new_game_pressed.emit())
	var continue_button := _make_button("Continue")
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	continue_button.visible = Save.has_save()
	var settings_button := _make_button("Settings")
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	if not OS.has_feature("web"):
		_quit_button = _make_button("Quit")
		_quit_button.pressed.connect(func() -> void: get_tree().quit())

	var help := Label.new()
	help.text = "Move: A/D or arrows   Jump: Space   Dodge: Shift   Attack: J   Charge: hold K   Special: L\nSwitch Carl/Donut: Tab   Potion: H   Interact: E   Pause: Esc"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.position = Vector2(-480, -60)
	help.size = Vector2(960, 40)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9, 0.7))
	add_child(help)
	new_button.grab_focus.call_deferred()


## Gives keyboard and gamepad focus to the first button again (after returning from settings).
func focus_default() -> void:
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus.call_deferred()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 48)
	button.add_theme_font_size_override("font_size", 20)
	_buttons.add_child(button)
	return button


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var pal := Decor.palette("warrens")
	Decor.draw_background(self, pal, Vector2(size.x, size.y))
	var glow := 0.08 + 0.02 * sin(_t * 1.4)
	var centre := Vector2(size.x * 0.5, size.y * 0.55)
	for k in range(9):
		draw_circle(centre, 360.0 - k * 38.0, Color(1.0, 0.7, 0.3, glow * 0.55))
	for i in range(_embers.size()):
		var e: Dictionary = _embers[i]
		var px := fposmod(float(e.x) * size.x + sin(_t * 0.3 + e.p) * 26.0, size.x)
		var py := fposmod(float(e.y) * size.y - _t * 18.0 * e.s, size.y)
		var a := 0.3 + 0.3 * sin(_t * 2.0 + e.p)
		draw_circle(Vector2(px, py), 1.2 + e.s, Color(1.0, 0.75, 0.4, a))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.12))
