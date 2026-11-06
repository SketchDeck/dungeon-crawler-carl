class_name AchievementPanel
extends PanelContainer
## Dungeon AI achievement announcement: slides in at the top right, holds,
## slides out. Several announcements queue up and play one after another.
## It never pauses the game or takes input.

const SLIDE_TIME := 0.35
const HOLD_TIME := 4.5
const WIDTH := 400.0

## Entries waiting to be shown ({title, description, reward}).
var queue: Array[Dictionary] = []
## The entry on screen, or empty.
var current: Dictionary = {}

var _header: Label
var _title: Label
var _description: Label
var _reward: Label
var _tween: Tween
var _home_x := 0.0
var _home_set := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.92)
	style.border_color = Color("#ffd34d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_header = _label(box, 13, Color("#ffd34d"))
	_header.text = "NEW ACHIEVEMENT!"
	_title = _label(box, 17, Color.WHITE)
	_description = _label(box, 13, Color(1, 1, 1, 0.8))
	_reward = _label(box, 13, Color("#7dff8a"))
	hide()


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 24.0, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func announce(entry: Dictionary) -> void:
	queue.append(entry)
	if current.is_empty():
		_show_next()


func is_showing() -> bool:
	return not current.is_empty()


func _show_next() -> void:
	if queue.is_empty():
		current = {}
		hide()
		return
	if not _home_set:
		# Layout is final by now; remember where the panel rests.
		_home_x = position.x
		_home_set = true
	current = queue.pop_front()
	_title.text = current.get("title", "")
	_description.text = current.get("description", "")
	_reward.text = current.get("reward", "")
	show()
	Fx.shake(0.15)
	if _tween:
		_tween.kill()
	position.x = _home_x + WIDTH + 40.0
	_tween = create_tween()
	_tween.tween_property(self, "position:x", _home_x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "position:x", _home_x + WIDTH + 40.0, SLIDE_TIME).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_show_next)
