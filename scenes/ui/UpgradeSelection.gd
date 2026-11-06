class_name UpgradeSelectionScreen
extends CanvasLayer
## Treasure reward: pauses the game, shows up to three upgrades (name and
## description), and resumes once the player picks one. Works with mouse,
## keyboard (arrows + Enter/Space) and controller (D-pad + south button).

signal chosen(upgrade: Upgrade)

const CARD_SIZE := Vector2(220, 150)

var choices: Array[Upgrade] = []

@onready var _cards: HBoxContainer = %Cards


func _ready() -> void:
	hide()


func show_choices(options: Array[Upgrade]) -> void:
	choices = options
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for upgrade in options:
		_cards.add_child(_make_card(upgrade))
	show()
	get_tree().paused = true
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Button).grab_focus()


func _make_card(upgrade: Upgrade) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.pressed.connect(choose.bind(upgrade))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = upgrade.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ffd34d"))
	var desc := Label.new()
	desc.text = upgrade.description()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	for label in [title, desc]:
		(label as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	card.add_child(box)
	return card


func cards() -> Array[Button]:
	var list: Array[Button] = []
	for child in _cards.get_children():
		list.append(child as Button)
	return list


func choose(upgrade: Upgrade) -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	chosen.emit(upgrade)
