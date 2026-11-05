extends Node2D
## Root of the game. Shows the title screen, then owns the world (rooms, player, camera, HUD)
## and drives the flow: rooms and doors, floors, death and respawn, game over, treasure choices,
## floor completion, pause, settings, and the return to the title screen.

const ROOM_SCENE := preload("res://scenes/rooms/RoomBase.tscn")
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const FADE_TIME := 0.25
const DEATH_DELAY := 1.4

var world: Node2D = null
var camera: Camera2D = null
var player: Player = null
var room: RoomBase = null
var hud: Hud = null
var menu: PanelMenu
var title: TitleMenu = null
var settings: SettingsMenu = null

var _hud_layer: CanvasLayer = null
var _title_layer: CanvasLayer
var _fade: ColorRect
var _room_list: Array = []
var _busy: bool = false
var _in_game: bool = false
var _menu_mode: String = ""
var _treasure_room: RoomBase = null
var _settings_return: String = ""


func _ready() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 90
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)
	var fade_root := Control.new()
	fade_root.size = get_viewport().get_visible_rect().size
	fade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_root)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.01, 0.04, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	fade_root.add_child(_fade)

	_title_layer = CanvasLayer.new()
	_title_layer.layer = 40
	add_child(_title_layer)

	menu = PanelMenu.new()
	add_child(menu)
	menu.chosen.connect(_on_menu_chosen)
	_show_title()


# --- Title, settings and world lifecycle -----------------------------------------

func _show_title() -> void:
	_teardown_world()
	_busy = false
	get_tree().paused = false
	_menu_mode = ""
	menu.cancel_option = ""
	if settings != null:
		settings.queue_free()
		settings = null
	title = TitleMenu.new()
	_title_layer.add_child(title)
	title.new_game_pressed.connect(_on_new_game)
	title.continue_pressed.connect(_on_continue)
	title.settings_pressed.connect(func() -> void: _open_settings("title"))
	Sfx.start_music()


func _on_new_game() -> void:
	Sfx.play("ui")
	_hide_title()
	Game.start_new_game()
	_build_world()
	_fade.modulate.a = 1.0
	_enter_floor(Game.floor_number, false)
	await _fade_in()


func _on_continue() -> void:
	Sfx.play("ui")
	_hide_title()
	Game.continue_game()
	_build_world()
	_fade.modulate.a = 1.0
	_enter_floor(Game.floor_number, false)
	await _fade_in()


func _hide_title() -> void:
	if title != null:
		title.queue_free()
		title = null


func _open_settings(return_to: String) -> void:
	_settings_return = return_to
	if title != null:
		title.visible = false
	if _in_game:
		menu.visible = false
	settings = SettingsMenu.new()
	_title_layer.add_child(settings)
	settings.back_pressed.connect(_close_settings)


func _close_settings() -> void:
	Sfx.play("ui")
	if settings != null:
		settings.queue_free()
		settings = null
	if _settings_return == "title" and title != null:
		title.visible = true
		title.focus_default()
	elif _settings_return == "pause":
		_open_pause()
	_settings_return = ""


func _build_world() -> void:
	_teardown_world()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.limit_left = -40
	camera.limit_top = -40
	camera.limit_right = 1320
	camera.limit_bottom = 640
	player.add_child(camera)
	camera.make_current()
	Fx.bind(world, camera)

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	hud = Hud.new()
	_hud_layer.add_child(hud)
	hud.bind(player)

	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	if not DungeonAI.announced.is_connected(hud.announce):
		DungeonAI.announced.connect(hud.announce)
	if not Game.game_over.is_connected(_on_game_over):
		Game.game_over.connect(_on_game_over)
	_in_game = true
	Sfx.start_music()


func _teardown_world() -> void:
	_in_game = false
	room = null
	player = null
	camera = null
	hud = null
	if world != null:
		world.queue_free()
		world = null
	if _hud_layer != null:
		_hud_layer.queue_free()
		_hud_layer = null
	Fx.bind(null, null)
	CombatState.reset()
	if menu != null:
		menu.visible = false


# --- Input ----------------------------------------------------------------------

## Safety net: a player who somehow falls out of a room goes back to its start, without losing
## health or a life.
func _process(_delta: float) -> void:
	if player == null or room == null or _busy or not player.alive:
		return
	if player.global_position.y > 900.0:
		Fx.text(player.global_position + Vector2(0.0, -30.0), "Back to the start", Color("#ffb347"), 15)
		player.global_position = room.spawn_point("start")
		player.velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not _in_game or _busy or menu.is_open() or settings != null:
		return
	if event.is_action_pressed(Controls.PAUSE):
		_open_pause()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not OS.is_debug_build():
		return
	match event.keycode:
		KEY_F1:
			Game.debug_unlock_everything()
			hud.announce("DEBUG", "ALL ABILITIES UNLOCKED", "Permanent unlocks granted for testing.", "")
		KEY_F2:
			_debug_warp(false)
		KEY_F3:
			_debug_warp(true)


func _debug_warp(to_boss: bool) -> void:
	if _busy or room == null:
		return
	var order := _room_list
	var here: int = order.find(room.room_id)
	var target := str(order[order.size() - 1]) if to_boss else str(order[mini(here + 1, order.size() - 1)])
	_busy = true
	await _fade_out()
	_load_room(target, "start")
	player.respawn_at(room.spawn_point("start"), 1)
	await _fade_in()
	_busy = false


# --- Floors and rooms -----------------------------------------------------------

func _enter_floor(number: int, carry_potions: bool) -> void:
	Game.start_floor(number, carry_potions)
	_room_list = RoomData.path(Game.floor_number)
	player.apply_floor_stats()
	_load_room(RoomData.start_room(Game.floor_number), "start")
	player.respawn_at(room.spawn_point("start"), 1)
	hud.set_floor(Game.floor_number)


func _load_room(room_id: String, entry: String) -> void:
	if room != null:
		room.queue_free()
		room = null
	CombatState.reset()
	room = ROOM_SCENE.instantiate() as RoomBase
	room.setup(room_id, Game.is_room_cleared(room_id))
	world.add_child(room)
	room.encounter_started.connect(_on_encounter_started)
	room.encounter_cleared.connect(_on_encounter_cleared)
	room.door_requested.connect(_on_door_requested)
	room.interact_requested.connect(_on_interact)
	player.global_position = room.spawn_point(entry)
	player.velocity = Vector2.ZERO
	player.controller.facing = -1 if entry == "right" else 1
	camera.limit_right = int(room.size.x) + 40
	camera.reset_smoothing()
	hud.set_room(room.display_name(), room.kind)
	hud.clear_boss()


func _on_door_requested(_room_ref: RoomBase, side: String) -> void:
	if _busy or room == null:
		return
	var target := str(room.layout["exits"].get(side, ""))
	if target == "":
		return
	var entry: String = FloorMaps.OPPOSITE[side]
	_busy = true
	Sfx.play("door")
	await _fade_out()
	_load_room(target, entry)
	await _fade_in()
	_busy = false


func _on_encounter_started(room_ref: RoomBase) -> void:
	if room_ref.boss != null:
		hud.show_boss(room_ref.boss)
		Sfx.play("roar")
	hud.set_room(room_ref.display_name(), "combat")


func _on_encounter_cleared(room_ref: RoomBase, flawless: bool) -> void:
	Game.mark_room_cleared(room_ref.room_id)
	var heal := DungeonAI.on_room_cleared(flawless)
	if heal > 0:
		var healed := player.health.heal(heal)
		Fx.text(player.global_position + Vector2(0.0, -48.0), "+%d HP" % healed, Color("#6dff9a"), 18)
	hud.clear_boss()
	hud.set_room(room_ref.display_name(), "cleared")
	Sfx.play("pickup")
	Fx.text(player.global_position + Vector2(0.0, -70.0), "ROOM CLEARED", Color("#ffe27a"), 16)
	if room_ref.kind == "challenge":
		Fx.text(player.global_position + Vector2(0.0, -94.0), "TREASURE UNLOCKED", Color("#ffb347"), 16)
	if room_ref.kind == "boss":
		_on_floor_boss_defeated()


func _on_player_damaged(_amount: int) -> void:
	if room != null:
		room.note_player_damaged()


# --- Death, respawn and game over ---------------------------------------------------

func _on_player_died() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("death")
	hud.set_room(room.display_name(), "fallen")
	await get_tree().create_timer(DEATH_DELAY, true, false, true).timeout
	var still_alive := Game.lose_life()
	if not still_alive:
		return
	await _fade_out()
	_load_room(room.room_id, "start")
	player.respawn_at(room.spawn_point("start"), 1)
	await _fade_in()
	_busy = false


func _on_game_over() -> void:
	_busy = true
	_menu_mode = "game_over"
	menu.cancel_option = ""
	get_tree().paused = true
	menu.show_menu("GAME OVER", "The dungeon wins this round.\nYour floor restarts with three lives and three potions.",
		[{"id": "restart", "label": "Restart Floor"}, {"id": "title", "label": "Main Menu"}])


func _restart_floor() -> void:
	_busy = true
	hud.clear_boss()
	await _fade_out()
	Game.restart_floor()
	_enter_floor(Game.floor_number, false)
	await _fade_in()
	_busy = false


# --- Interactables, treasure and bonfires --------------------------------------------

func _on_interact(room_ref: RoomBase, what: String) -> void:
	if what == "bonfire":
		var healed := player.health.heal(Bonfire.HEAL)
		Sfx.play("heal")
		Fx.glow(player.global_position, Color("#ffb347"), 60.0, 0.5)
		Fx.text(player.global_position + Vector2(0.0, -44.0), "+%d HP" % healed, Color("#ffb347"), 18)
		hud.announce_simple("Bonfire", "You feel a little less like a pile of bruises.")
	elif what == "treasure":
		_open_treasure(room_ref)


func _open_treasure(room_ref: RoomBase) -> void:
	var pool: Array = []
	for id in Game.UPGRADE_INFO.keys():
		if not Game.has_upgrade(id):
			pool.append(id)
	pool.shuffle()
	var offers: Array = pool.slice(0, mini(3, pool.size()))
	var options: Array = []
	for id in offers:
		var info: Dictionary = Game.UPGRADE_INFO[id]
		options.append({"id": id, "label": "%s:  %s" % [info.name, info.desc]})
	if options.is_empty():
		options.append({"id": "none", "label": "Nothing left to choose"})
	Sfx.play("treasure")
	_menu_mode = "treasure"
	menu.cancel_option = ""
	_treasure_room = room_ref
	get_tree().paused = true
	menu.show_menu("TREASURE!", "Choose one temporary upgrade. It lasts until this floor ends.", options)


# --- Pause and floor completion ---------------------------------------------------------

func _open_pause() -> void:
	if menu.is_open():
		return
	_menu_mode = "pause"
	menu.cancel_option = "resume"
	get_tree().paused = true
	var options: Array = [
		{"id": "resume", "label": "Resume"},
		{"id": "settings", "label": "Settings"},
		{"id": "restart", "label": "Restart Floor"},
		{"id": "title", "label": "Main Menu"},
	]
	if not OS.has_feature("web"):
		options.append({"id": "quit", "label": "Quit"})
	menu.show_menu("PAUSED", "Floor %d  -  Lives %d  -  Potions %d" % [Game.floor_number, Game.lives, Game.potions.count], options)


func _on_floor_boss_defeated() -> void:
	var floor_done := Game.floor_number
	Game.complete_floor()
	var unlock_text := ""
	if floor_done == 1:
		unlock_text = "Unlocked: Carl's Explosive Kick (special, L)."
	elif floor_done == 2:
		unlock_text = "Unlocked: Donut's Area Magic Burst (special, L)."
	var options: Array = []
	var body := "The boss is down. Health and lives reset for the next floor. Unused potions carry over.\n%s" % unlock_text
	if floor_done < Config.FLOOR_COUNT:
		options.append({"id": "next", "label": "Continue to Floor %d" % (floor_done + 1)})
	else:
		body = "Both floors are cleared. Carl and Donut made it out.\n%s" % unlock_text
		options.append({"id": "title", "label": "Main Menu"})
	_menu_mode = "floor_complete"
	menu.cancel_option = ""
	get_tree().paused = true
	menu.show_menu("FLOOR %d COMPLETE" % floor_done, body, options)


func _on_menu_chosen(option_id: String) -> void:
	var mode := _menu_mode
	_menu_mode = ""
	menu.cancel_option = ""
	match mode:
		"pause":
			match option_id:
				"resume":
					get_tree().paused = false
				"settings":
					menu.visible = false
					_open_settings("pause")
				"restart":
					get_tree().paused = false
					_restart_floor()
				"title":
					_show_title()
				"quit":
					get_tree().quit()
		"game_over":
			get_tree().paused = false
			if option_id == "restart":
				_restart_floor()
			else:
				_show_title()
		"treasure":
			get_tree().paused = false
			if option_id != "none" and _treasure_room != null:
				Game.add_upgrade(option_id)
				player.refresh_max_hp()
				_treasure_room.complete_treasure()
				Game.mark_reward_taken(_treasure_room.room_id)
				var info: Dictionary = Game.UPGRADE_INFO[option_id]
				hud.announce_simple("Upgrade acquired", "%s: %s" % [info.name, info.desc])
			_treasure_room = null
		"floor_complete":
			get_tree().paused = false
			if option_id == "next":
				_advance_floor()
			else:
				_show_title()


func _advance_floor() -> void:
	_busy = true
	await _fade_out()
	_enter_floor(Game.floor_number + 1, true)
	await _fade_in()
	_busy = false


# --- Fades ------------------------------------------------------------------------

func _fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tw.finished


func _fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await tw.finished
