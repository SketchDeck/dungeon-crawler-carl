class_name FloorCompleteScreen
extends CanvasLayer
## Shown when the player takes the stairs out of a beaten boss room. Pauses
## the game. "Continue" only appears when the next floor exists.

signal continue_requested
signal replay_requested
signal main_menu_requested

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _continue: Button = %ContinueButton
@onready var _replay: Button = %ReplayButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	hide()
	_continue.pressed.connect(_close.bind(continue_requested))
	_replay.pressed.connect(_close.bind(replay_requested))
	_menu.pressed.connect(_close.bind(main_menu_requested))


func show_screen(floor_number: int, lives: int, potions: int, unlocks: Array[StringName] = [], summary := {}) -> void:
	var has_next := FloorData.has_floor(floor_number + 1)
	_title.text = "%s COMPLETE" % FloorData.floor_name(floor_number).to_upper()
	var lines := [
		"The %s is down. The crowd goes wild." % FloorData.boss_name(floor_number),
		"Lives left: %d   ·   Potions: %d" % [lives, potions],
	]
	if not summary.is_empty():
		lines.append("")
		lines.append("GRADE %s%s" % [summary["grade"], "   ·   NEW BEST!" if summary.get("new_best", false) else ""])
		lines.append("Viewers: %d   ·   Time: %s   ·   Kills: %d" % [summary["viewers"], RunStats.format_time(summary["time"]),
			summary["kills"]])
		lines.append("Damage taken: %d   ·   Deaths: %d   ·   Potions drunk: %d" % [roundi(summary["damage_taken"]),
			summary["deaths"], summary["potions_used"]])
		var best := GameManager.best_run(floor_number)
		if not best.is_empty() and not summary.get("new_best", false):
			lines.append("Best: %d viewers (grade %s, %s)" % [best["viewers"], best["grade"], RunStats.format_time(best["time"])])
		lines.append("")
	for id in unlocks:
		lines.append("NEW ABILITY UNLOCKED: %s" % GameManager.ABILITY_NAMES.get(id, String(id)))
	lines.append("Temporary upgrades end with the floor.")
	if has_next:
		lines.append("Continuing restores your health and lives. Unused potions come with you.")
	else:
		lines.append("You've cleared every floor in this build. Thanks for playing! You can replay this floor from the start.")
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
