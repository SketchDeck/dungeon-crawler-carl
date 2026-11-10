class_name RoomManager
extends Node
## Loads room scenes, moves the player between them and remembers each room's
## persistent state (cleared, trial done, reward claimed, fountain used) for
## the current floor run.
##
## Transition: validate exit -> store current room state -> load destination
## -> place player at its entrance -> activate the room's encounter.

signal room_entered(room: RoomBase)
signal floor_started(floor_number: int)
## The player took the stairs out of the beaten boss room.
signal floor_exit_reached(floor_number: int)
## A treasure chest was opened: time to pick an upgrade.
signal treasure_opened(room: RoomBase)
## The player fell out of the bottom of the room.
signal player_fell

@export var transition_fade := 0.18
## Damage for falling out of the bottom of a room; the player returns to the entrance.
@export var fall_damage := 20.0

var floor_number := 1
var current_room: RoomBase
var current_room_id := ""
## room id -> persistent state Dictionary
var room_states := {}
var transitioning := false
## This floor run's picks: room id -> variant scene path, and room id -> seed
## for `?` spawn markers (so a restarted room spawns the same enemies).
var room_variants := {}
var room_seeds := {}
## Active floor modifiers and Hard mode (see Modifiers.gd).
var modifiers: Array[StringName] = []
var hard_mode := false
var rng := RandomNumberGenerator.new()

var player: Player
var room_slot: Node
var hud: HUD


func setup(p_player: Player, p_room_slot: Node, p_hud: HUD = null) -> void:
	player = p_player
	room_slot = p_room_slot
	hud = p_hud


## Starts (or restarts) a floor from its entrance with fresh room progress,
## picking a variant for each room. `run_seed` >= 0 makes the picks repeatable
## (Daily Run); otherwise they're random.
func start_floor(number: int, run_seed := -1) -> void:
	floor_number = number
	_unload_current_room()
	room_states.clear()
	if run_seed >= 0:
		rng.seed = run_seed
	else:
		rng.randomize()
	room_variants.clear()
	room_seeds.clear()
	for id: String in FloorData.room_ids(number):
		var paths := FloorData.room_scene_paths(number, id)
		room_variants[id] = paths[rng.randi_range(0, paths.size() - 1)]
		room_seeds[id] = rng.randi()
	load_room(FloorData.start_room(number))
	floor_started.emit(number)


## Reloads the current room from its stored state, resetting any in-progress
## encounter (used after losing a life).
func reload_current_room() -> void:
	load_room(current_room_id)


## Exit door `index` of the current room was used.
func request_exit(index: int) -> bool:
	if transitioning or current_room == null:
		return false
	if index < 0 or index >= current_room.exits.size():
		push_warning("Room %s has no exit %d" % [current_room_id, index])
		return false
	var target := current_room.exits[index]
	if not FloorData.has_room(floor_number, target):
		push_warning("Room %s exit %d points to unknown room %s" % [current_room_id, index, target])
		return false
	_transition(target)
	return true


func _transition(target: String) -> void:
	transitioning = true
	Audio.play("door", -4.0)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if hud:
		await hud.fade(1.0, transition_fade).finished
	load_room(target)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if hud:
		await hud.fade(0.0, transition_fade).finished
	transitioning = false


## Synchronously swaps in a room and places the player at its entrance.
func load_room(room_id: String) -> RoomBase:
	_store_current_state()
	_unload_current_room()

	var path: String = room_variants.get(room_id, FloorData.room_scene_path(floor_number, room_id))
	var scene := load(path) as PackedScene
	var room := scene.instantiate() as RoomBase
	room.state = (room_states.get(room_id, {}) as Dictionary).duplicate()
	room.enemy_pool = FloorData.enemy_pool(floor_number)
	room.spawn_seed = room_seeds.get(room_id, 0)
	room.modifiers = modifiers
	room.hard_mode = hard_mode
	room_slot.add_child(room)
	room.exit_requested.connect(request_exit)
	room.state_changed.connect(_on_room_state_changed.bind(room_id))
	room.boss_defeated.connect(_on_boss_defeated)
	room.floor_exit_requested.connect(_on_floor_exit)
	room.reward_claimed.connect(func() -> void: treasure_opened.emit(room))
	current_room = room
	current_room_id = room_id

	player.global_position = room.get_spawn_point()
	player.velocity = Vector2.ZERO
	player.facing = 1
	player.camera.set_room_bounds(room.bounds)
	player.camera.reset_smoothing()
	room.activate(player)
	room_entered.emit(room)
	return room


func _on_boss_defeated() -> void:
	GameManager.complete_floor(floor_number)


func _on_floor_exit() -> void:
	if transitioning:
		return
	floor_exit_reached.emit(floor_number)


func _unload_current_room() -> void:
	# Bolts still in flight belong to the old room.
	for bolt in get_tree().get_nodes_in_group(MagicProjectile.GROUP):
		bolt.queue_free()
	if current_room:
		room_slot.remove_child(current_room)
		current_room.queue_free()
		current_room = null


func _store_current_state() -> void:
	if current_room:
		room_states[current_room_id] = current_room.state.duplicate()


func _on_room_state_changed(state: Dictionary, room_id: String) -> void:
	room_states[room_id] = state.duplicate()


func _physics_process(_delta: float) -> void:
	if current_room == null or player == null or transitioning or player.health.is_dead:
		return
	if player.global_position.y > current_room.bounds.end.y + 48.0:
		_on_player_fell()


func _on_player_fell() -> void:
	player_fell.emit()
	player.health.take_damage(fall_damage, true)
	if player.health.is_dead:
		return
	player.global_position = current_room.get_spawn_point()
	player.velocity = Vector2.ZERO
	player.camera.reset_smoothing()
	Fx.text(player.global_position + Vector2(0, -50), "-%d  Watch your step!" % roundi(fall_damage), Color("#ff8080"), 15)
