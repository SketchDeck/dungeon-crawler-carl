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
## Temporary upgrades come from treasure chests and are cleared whenever the
## floor restarts or is completed.

@export var respawn_delay := 1.5
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

## Debug: N jumps through the current room's first exit, ignoring locks;
## U unlocks both special abilities.
@export var debug_keys := true

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var room_slot: Node2D = $Room
@onready var room_manager: RoomManager = $RoomManager
@onready var game_over: GameOverScreen = $GameOver
@onready var floor_complete: FloorCompleteScreen = $FloorComplete
@onready var upgrade_selection: UpgradeSelectionScreen = $UpgradeSelection
@onready var dungeon_ai: DungeonAIManager = $DungeonAI
@onready var pause_menu: PauseMenu = $PauseMenu

## Tests turn this off and read `requested_scene` instead of changing scenes.
var navigate := true
var requested_scene := ""

## Abilities unlocked since the floor started, shown on Floor Complete.
var _new_unlocks: Array[StringName] = []


func _ready() -> void:
	hud.bind_player(player)
	hud.bind_rooms(room_manager)
	room_manager.setup(player, room_slot, hud)
	dungeon_ai.setup(player, room_manager, hud)
	player.health.died.connect(_on_player_died)
	game_over.restart_requested.connect(restart_floor)
	room_manager.floor_exit_reached.connect(_on_floor_exit_reached)
	floor_complete.continue_requested.connect(continue_to_next_floor)
	floor_complete.replay_requested.connect(restart_floor)
	floor_complete.main_menu_requested.connect(go_to_main_menu)
	game_over.main_menu_requested.connect(go_to_main_menu)
	pause_menu.main_menu_requested.connect(go_to_main_menu)
	room_manager.treasure_opened.connect(_on_treasure_opened)
	upgrade_selection.chosen.connect(_on_upgrade_chosen)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	room_manager.room_entered.connect(_on_room_entered_music)
	GameManager.reset_lives()
	room_manager.start_floor(GameManager.floor_number)


## Floor music, switching to the boss theme while a boss fight is on.
func floor_music() -> String:
	return "floor%d" % GameManager.floor_number


func _on_room_entered_music(room: RoomBase) -> void:
	Audio.play_music(floor_music())
	room.boss_started.connect(func(_boss: BossBase) -> void: Audio.play_music("boss"))
	room.boss_defeated.connect(func() -> void:
		Audio.play("floor_complete", 0.0, 0.0)
		Audio.play_music(floor_music()))


func _on_player_died() -> void:
	var remaining := GameManager.lose_life()
	Audio.play("life_lost", 0.0, 0.0)
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
		Audio.play_music("")
		Audio.play("game_over", 0.0, 0.0)
		game_over.show_screen()


func respawn_in_current_room() -> void:
	# Respawn first (clears combat state), then reload the room, which
	# re-activates its encounter and places the player at the entrance.
	player.respawn(player.global_position)
	room_manager.reload_current_room()


func restart_floor() -> void:
	GameManager.reset_lives()
	player.potions.reset()
	player.upgrades.clear()
	dungeon_ai.reset()
	_new_unlocks.clear()
	player.respawn(player.global_position)
	room_manager.start_floor(GameManager.floor_number)


## Back to the title screen. Completed floors and unlocks are already saved.
func go_to_main_menu() -> void:
	get_tree().paused = false
	requested_scene = MENU_SCENE
	if navigate:
		get_tree().change_scene_to_file(MENU_SCENE)


func _on_floor_exit_reached(floor_number: int) -> void:
	Audio.play_music("menu")
	Audio.play("achievement", 0.0, 0.0)
	floor_complete.show_screen(floor_number, GameManager.lives, player.potions.count, _new_unlocks)


func _on_ability_unlocked(id: StringName) -> void:
	Audio.play("achievement", 0.0, 0.0)
	_new_unlocks.append(id)
	Fx.text(player.global_position + Vector2(0, -90), "NEW ABILITY: %s" % GameManager.ABILITY_NAMES.get(id, String(id)),
		Color("#ffd34d"), 18)


func _on_treasure_opened(_room: RoomBase) -> void:
	upgrade_selection.show_choices(player.upgrades.roll(3))


func _on_upgrade_chosen(upgrade: Upgrade) -> void:
	player.upgrades.apply(upgrade)
	Fx.text(player.global_position + Vector2(0, -70), upgrade.title.to_upper() + "!", Color("#ffd34d"), 18)


## Next floor: full health, lives back to 3, unused potions carried over.
func continue_to_next_floor() -> void:
	if not FloorData.has_floor(GameManager.floor_number + 1):
		return
	GameManager.floor_number += 1
	GameManager.reset_lives()
	player.upgrades.clear()
	dungeon_ai.reset()
	_new_unlocks.clear()
	player.respawn(player.global_position)
	room_manager.start_floor(GameManager.floor_number)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if debug_keys and key and key.pressed and not key.echo and key.physical_keycode == KEY_U:
		GameManager.debug_unlock_all()
		Fx.text(player.global_position + Vector2(0, -60), "DEBUG: specials unlocked", Color("#8ec5ff"), 14)
	if debug_keys and key and key.pressed and not key.echo and key.physical_keycode == KEY_N:
		var room := room_manager.current_room
		if room and not room.exits.is_empty():
			room_manager.request_exit(0)
