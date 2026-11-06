class_name GameOverScreen
extends CanvasLayer
## Shown when the last life is lost. Pauses the game until the player restarts.

signal restart_requested

@onready var _restart: Button = %RestartButton


func _ready() -> void:
	hide()
	_restart.pressed.connect(_on_restart)


func show_screen() -> void:
	show()
	get_tree().paused = true
	_restart.grab_focus()


func _on_restart() -> void:
	hide()
	get_tree().paused = false
	restart_requested.emit()
