class_name FloorCompleteScreen
extends CanvasLayer
## Shown when the player takes the stairs out of a beaten boss room. Pauses
## the game. "Continue" only appears when the next floor exists.

signal continue_requested
signal replay_requested

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _continue: Button = %ContinueButton
@onready var _replay: Button = %ReplayButton


func _ready() -> void:
	hide()
	_continue.pressed.connect(_close.bind(continue_requested))
	_replay.pressed.connect(_close.bind(replay_requested))


func show_screen(floor_number: int, lives: int, potions: int) -> void:
	var has_next := FloorData.has_floor(floor_number + 1)
	_title.text = "%s COMPLETE" % FloorData.floor_name(floor_number).to_upper()
	var lines := [
		"The Goblin Brute is down. The crowd goes wild.",
		"Lives left: %d   ·   Potions: %d" % [lives, potions],
	]
	if has_next:
		lines.append("Continuing restores your health and lives. Unused potions come with you.")
	else:
		lines.append("Floor 2 isn't built yet (Milestone 8). You can replay this floor from the start.")
	_body.text = "\n".join(lines)
	_continue.visible = has_next
	_continue.text = "Continue to %s" % FloorData.floor_name(floor_number + 1) if has_next else ""
	_replay.text = "Replay %s" % FloorData.floor_name(floor_number)
	show()
	get_tree().paused = true
	(_continue if has_next else _replay).grab_focus()


func _close(sig: Signal) -> void:
	hide()
	get_tree().paused = false
	sig.emit()
