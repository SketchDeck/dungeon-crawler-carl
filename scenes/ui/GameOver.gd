class_name GameOverScreen
extends CanvasLayer
## Shown when the last life is lost. Pauses the game until the player restarts.

signal restart_requested
signal main_menu_requested

@onready var _restart: Button = %RestartButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	hide()
	_restart.pressed.connect(_on_restart)
	_menu.pressed.connect(func() -> void:
		hide()
		get_tree().paused = false
		main_menu_requested.emit())


func show_screen() -> void:
	show()
	get_tree().paused = true
	_restart.grab_focus()


func _on_restart() -> void:
	hide()
	get_tree().paused = false
	restart_requested.emit()
