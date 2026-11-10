class_name ShopScreen
extends CanvasLayer
## The safe-room shop: pauses the game and lists what your gold can buy. Main
## supplies the stock and applies purchases (some open the upgrade picker
## after the shop closes).

signal closed
signal purchased(item_id: String)

## [{id, name, description, price}]
var items: Array[Dictionary] = []
## Callable(item_id: String) -> String (a message; "" means it failed)
var buyer: Callable
var gold_source: Callable

var _list: VBoxContainer
var _gold: Label
var _message: Label
var _leave: Button


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
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.04, 0.97)
	style.border_color = Color("#e0a020")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(520, 0)
	panel.add_child(col)
	var title := Label.new()
	title.text = "MORDECAI'S DISCOUNT EMPORIUM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ffd34d"))
	col.add_child(title)
	_gold = Label.new()
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.add_theme_color_override("font_color", Color("#ffd34d"))
	col.add_child(_gold)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	col.add_child(_list)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(480, 40)
	_message.add_theme_color_override("font_color", Color("#7dff8a"))
	col.add_child(_message)
	_leave = Button.new()
	_leave.text = "Leave shop"
	_leave.custom_minimum_size = Vector2(180, 40)
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave.pressed.connect(close)
	col.add_child(_leave)
	hide()


func open(stock: Array[Dictionary]) -> void:
	items = stock
	_message.text = "\"Everything's priced to move. Mostly because I stole it.\""
	show()
	get_tree().paused = true
	_refresh()
	var first := item_buttons()
	(first[0] if not first.is_empty() else _leave).grab_focus()


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func item_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for c in _list.get_children():
		if c is Button:
			out.append(c)
	return out


## Buys an item by id. Returns the result message ("" if it couldn't be bought).
func buy(item_id: String) -> String:
	var msg: String = buyer.call(item_id) if buyer.is_valid() else ""
	if msg != "":
		Audio.play("buy", 0.0, 0.0)
		purchased.emit(item_id)
		_message.add_theme_color_override("font_color", Color("#7dff8a"))
		_message.text = msg
	else:
		_message.add_theme_color_override("font_color", Color("#ff8080"))
		_message.text = "You can't afford that (or can't carry it)."
	_refresh()
	return msg


func _refresh() -> void:
	var gold: int = gold_source.call() if gold_source.is_valid() else 0
	_gold.text = "Your gold: %d" % gold
	var focused := get_viewport().gui_get_focus_owner()
	var focus_index := item_buttons().find(focused)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for item in items:
		var b := Button.new()
		b.text = "%s  -  %d gold\n%s" % [item["name"], item["price"], item["description"]]
		b.custom_minimum_size = Vector2(480, 54)
		b.disabled = gold < int(item["price"])
		b.pressed.connect(buy.bind(String(item["id"])))
		_list.add_child(b)
	var buttons := item_buttons()
	if focus_index >= 0 and focus_index < buttons.size() and not buttons[focus_index].disabled:
		buttons[focus_index].grab_focus()
	elif visible:
		_leave.grab_focus()
