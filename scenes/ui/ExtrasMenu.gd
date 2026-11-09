class_name ExtrasMenu
extends PanelContainer
## Main menu "Extras": the Dungeon AI's trophy case (every achievement, with
## locked ones shown as ???), Carl's hat wardrobe and the best run on each
## floor. Profile data lives in GameManager and survives New Game.

signal closed

var _list: VBoxContainer
var _hats: HBoxContainer
var _best: Label
var _summary: Label
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 1.0)
	style.border_color = Color("#ffd34d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(_label("THE DUNGEON AI'S TROPHY CASE", 24, Color("#ffd34d")))
	_summary = _label("", 14, Color(1, 1, 1, 0.7))
	box.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	box.add_child(_label("CARL'S HATS (won from gold loot boxes)", 16, Color("#ffd34d")))
	_hats = HBoxContainer.new()
	_hats.add_theme_constant_override("separation", 6)
	box.add_child(_hats)
	box.add_child(_label("BEST RUNS", 16, Color("#ffd34d")))
	_best = _label("", 14, Color.WHITE)
	box.add_child(_best)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(160, 38)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	box.add_child(_back)
	hide()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func open() -> void:
	refresh()
	show()
	_back.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var earned := 0
	for id: StringName in Achievements.ids():
		var tier := Achievements.tier(id)
		var have := GameManager.has_achievement(id)
		if have:
			earned += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var badge := _label(Achievements.tier_name(tier).to_upper(), 12, Achievements.tier_color(tier) if have else Color(1, 1, 1, 0.3))
		badge.custom_minimum_size = Vector2(64, 0)
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(badge)
		var name_label := _label(Achievements.display_name(id) if have else "???", 15, Color.WHITE if have else Color(1, 1, 1, 0.4))
		name_label.custom_minimum_size = Vector2(210, 0)
		row.add_child(name_label)
		var detail := Achievements.hint(id)
		if have:
			var times := int(GameManager.achievements.get(String(id), 1))
			if times > 1:
				detail += "  (x%d)" % times
		else:
			detail = "Keep crawling. The Dungeon AI is watching."
		var hint := _label(detail, 13, Color(1, 1, 1, 0.75 if have else 0.35))
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
		_list.add_child(row)
	_summary.text = "%d of %d achievements earned. They survive New Game." % [earned, Achievements.ids().size()]

	for c in _hats.get_children():
		c.queue_free()
	_add_hat_button("", "No hat")
	for id: String in GameManager.HATS:
		_add_hat_button(id, GameManager.HATS[id] if GameManager.owned_hats.has(id) else "???")

	var lines: Array[String] = []
	var f := 1
	while FloorData.has_floor(f):
		var best := GameManager.best_run(f)
		if best.is_empty():
			lines.append("%s: not beaten yet" % FloorData.floor_name(f))
		else:
			lines.append("%s: grade %s, %d viewers, %s" % [FloorData.floor_name(f), best["grade"], best["viewers"],
				RunStats.format_time(best["time"])])
		f += 1
	_best.text = "\n".join(lines)


func _add_hat_button(id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = GameManager.equipped_hat == id
	b.disabled = id != "" and not GameManager.owned_hats.has(id)
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(func() -> void:
		GameManager.equip_hat(id)
		refresh()
		_back.grab_focus())
	_hats.add_child(b)
