class_name LootBoxScreen
extends CanvasLayer
## Opens the player's loot boxes one at a time: pauses the game, shows the
## box (coloured by tier), "Open!" reveals the reward, "Next" moves on.
## `opener` turns a tier into a reward line (Main applies the reward). Gold
## boxes may also grant upgrade picks, which Main shows after the screen closes.

signal closed

## Callable(tier: int) -> String
var opener: Callable
var queue: Array[int] = []
var current_tier := -1
var revealed := false

var _panel: PanelContainer
var _title: Label
var _box: Control
var _reward: Label
var _button: Button
var _count: Label
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.09, 0.97)
	style.border_color = Color("#ffd34d")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(420, 0)
	_panel.add_child(col)
	var header := Label.new()
	header.text = "LOOT BOX TIME!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color("#ffd34d"))
	col.add_child(header)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(_count)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	col.add_child(_title)
	_box = Control.new()
	_box.custom_minimum_size = Vector2(0, 110)
	_box.draw.connect(_draw_box)
	col.add_child(_box)
	_reward = Label.new()
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward.custom_minimum_size = Vector2(380, 48)
	_reward.add_theme_font_size_override("font_size", 16)
	_reward.add_theme_color_override("font_color", Color("#7dff8a"))
	col.add_child(_reward)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(200, 42)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(advance)
	col.add_child(_button)
	hide()


func open_boxes(tiers: Array[int]) -> void:
	queue = tiers.duplicate()
	if queue.is_empty():
		return
	show()
	get_tree().paused = true
	_next_box()


func is_open() -> bool:
	return visible


## The button: open the current box, or move to the next one / close.
func advance() -> void:
	if not visible:
		return
	if not revealed:
		revealed = true
		_shake = 0.35
		Audio.play("chest", 0.0, 0.0)
		_reward.text = opener.call(current_tier) if opener.is_valid() else ""
		_button.text = "Next box" if not queue.is_empty() else "Done"
	elif queue.is_empty():
		hide()
		get_tree().paused = false
		current_tier = -1
		closed.emit()
	else:
		_next_box()
	_button.grab_focus()


func _next_box() -> void:
	current_tier = queue.pop_front()
	revealed = false
	_title.text = "%s Box" % Achievements.tier_name(current_tier)
	_title.add_theme_color_override("font_color", Achievements.tier_color(current_tier))
	_count.text = "%d more after this" % queue.size() if not queue.is_empty() else "Last one"
	_reward.text = ""
	_button.text = "Open!"
	_button.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(_shake - delta, 0.0)
	if visible:
		_box.queue_redraw()


func _draw_box() -> void:
	if current_tier < 0:
		return
	var c := Achievements.tier_color(current_tier)
	var mid := Vector2(_box.size.x * 0.5, _box.size.y * 0.55)
	if _shake > 0.0:
		mid.x += sin(_t * 80.0) * 6.0 * _shake / 0.35
	var w := 90.0
	var h := 62.0
	var lid_lift := 26.0 if revealed and _shake <= 0.0 else 0.0
	if revealed:
		# Light pouring out.
		for i in 6:
			var a := -PI * 0.5 + (i - 2.5) * 0.28
			_box.draw_line(mid + Vector2(0, -h * 0.5), mid + Vector2(cos(a), sin(a)) * 90.0, Color(c, 0.35), 6.0)
	_box.draw_rect(Rect2(mid - Vector2(w * 0.5, h * 0.5 - 8), Vector2(w, h - 8)), c.darkened(0.25))
	_box.draw_rect(Rect2(mid - Vector2(w * 0.5 + 4, h * 0.5 + 4 + lid_lift), Vector2(w + 8, 16)), c)
	_box.draw_rect(Rect2(mid - Vector2(8, h * 0.5 + 4 + lid_lift), Vector2(16, h + 4 + lid_lift)), Color(1, 1, 1, 0.75))
	if not revealed:
		var font := ThemeDB.fallback_font
		_box.draw_string(font, mid + Vector2(-6, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.6))
