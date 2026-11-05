extends Node2D
## Game root: owns the persistent player and HUD, and the current room.
## Milestone 1: a single test room; death respawns at the room spawn after a
## short delay (lives and room resets arrive in Milestone 3).

@export var respawn_delay := 1.5

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var room_slot: Node2D = $Room


func _ready() -> void:
	var room := current_room()
	player.global_position = room.get_spawn_point()
	player.camera.set_room_bounds(room.bounds)
	player.health.died.connect(_on_player_died)
	hud.bind_player(player)


func current_room() -> RoomBase:
	return room_slot.get_child(0) as RoomBase


func _on_player_died() -> void:
	Fx.shake(0.6)
	Fx.text(player.global_position + Vector2(0, -50), "OUCH.", Color("#ff6060"), 22)
	await get_tree().create_timer(respawn_delay).timeout
	player.respawn(current_room().get_spawn_point())
