extends Node2D
## Game root: owns the persistent player, HUD and room manager, and runs the
## lives flow.
##
## Losing a life: death effect -> lose one life -> restart the current room
## (its encounter resets) -> respawn at full health, keeping potions.
## Losing the last life: Game Over -> restart the floor with 3 lives, full
## health, 3 potions and fresh room progress.
## Beating the boss and taking the stairs: Floor Complete screen -> continue
## to the next floor (full health, 3 lives, potions kept) or replay this one.

@export var respawn_delay := 1.5
## Debug: N jumps through the current room's first exit, ignoring locks.
@export var debug_keys := true

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var room_slot: Node2D = $Room
@onready var room_manager: RoomManager = $RoomManager
@onready var game_over: GameOverScreen = $GameOver
@onready var floor_complete: FloorCompleteScreen = $FloorComplete


func _ready() -> void:
	hud.bind_player(player)
	hud.bind_rooms(room_manager)
	room_manager.setup(player, room_slot, hud)
	player.health.died.connect(_on_player_died)
	game_over.restart_requested.connect(restart_floor)
	room_manager.floor_exit_reached.connect(_on_floor_exit_reached)
	floor_complete.continue_requested.connect(continue_to_next_floor)
	floor_complete.replay_requested.connect(restart_floor)
	GameManager.reset_lives()
	room_manager.start_floor(GameManager.floor_number)


func _on_player_died() -> void:
	var remaining := GameManager.lose_life()
	Fx.shake(0.6)
	Fx.burst(player.global_position, Color("#ff5050"), 48.0, 0.5)
	Fx.text(player.global_position + Vector2(0, -60),
		"-1 LIFE" if remaining > 0 else "OUT OF LIVES", Color("#ff6060"), 22)
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	if remaining > 0:
		respawn_in_current_room()
	else:
		game_over.show_screen()


func respawn_in_current_room() -> void:
	# Respawn first (clears combat state), then reload the room, which
	# re-activates its encounter and places the player at the entrance.
	player.respawn(player.global_position)
	room_manager.reload_current_room()


func restart_floor() -> void:
	GameManager.reset_lives()
	player.potions.reset()
	player.respawn(player.global_position)
	room_manager.start_floor(GameManager.floor_number)


func _on_floor_exit_reached(floor_number: int) -> void:
	floor_complete.show_screen(floor_number, GameManager.lives, player.potions.count)


## Next floor: full health, lives back to 3, unused potions carried over.
func continue_to_next_floor() -> void:
	if not FloorData.has_floor(GameManager.floor_number + 1):
		return
	GameManager.floor_number += 1
	GameManager.reset_lives()
	player.respawn(player.global_position)
	room_manager.start_floor(GameManager.floor_number)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if debug_keys and key and key.pressed and not key.echo and key.physical_keycode == KEY_N:
		var room := room_manager.current_room
		if room and not room.exits.is_empty():
			room_manager.request_exit(0)
