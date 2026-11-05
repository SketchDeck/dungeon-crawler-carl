extends Node
## Visual check tool (not part of the automated tests). Runs the real game in a window, drives it
## through scripted moments, and saves PNGs. Usage:
##   godot --path . --scene res://tests/ScreenshotTour.tscn -- /absolute/output/dir

const MAIN := preload("res://scenes/main/Main.tscn")
var out_dir := ""
var main: Node = null


func _ready() -> void:
	# Watchdog: never leave a window hanging if a step fails.
	get_tree().create_timer(170.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(3))
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = MAIN.instantiate()
	add_child(main)
	await _frames(40)
	await _shot("01_title")

	main._hide_title()
	Game.start_new_game()
	main._build_world()
	main._fade.modulate.a = 0.0
	main._enter_floor(1, false)
	await _frames(40)
	await _shot("02_entrance")

	# Combat room B: goblins, a kick, Donut's magic, and the charged blast.
	main._load_room("f1_B", "left")
	await _frames(30)
	var player: Player = main.player
	player.global_position = Vector2(470.0, RoomData.STAND_Y)
	await _frames(20)
	await _shot("03_combat_room")
	await _tap(Controls.ATTACK, 3)
	await _frames(6)
	await _shot("04_kick_contact")
	await _frames(40)
	await _tap(Controls.SWITCH_MODE, 2)
	await _frames(20)
	await _shot("05_donut_mode")
	await _tap(Controls.ATTACK, 2)
	await _frames(12)
	await _shot("06_magic_bolt")
	await _frames(40)
	Input.action_press(Controls.CHARGE)
	await _frames(55)
	await _shot("07_charging_blast")
	Input.action_release(Controls.CHARGE)
	await _frames(12)
	await _shot("08_blast_released")
	await _frames(60)
	await _tap(Controls.SWITCH_MODE, 2)

	# Combat room E: a staircase up on the left shaft, a hole in the floor on the right shaft.
	main._load_room("f1_E", "left")
	await _frames(40)
	await _shot("09_shaft_room")

	# Challenge room D: spikes, an explosive barrel, enemies, and the locked chest.
	main._load_room("f1_D", "left")
	await _frames(40)
	await _shot("10_challenge_room")
	main._open_treasure(main.room)
	await _frames(15)
	await _shot("11_treasure_menu")
	main.menu._set_visible(false)
	main.menu._open = false
	get_tree().paused = false
	main._menu_mode = ""

	# Floor 1 boss.
	main._load_room("f1_N", "start")
	await _frames(120)
	await _shot("12_boss_arena")
	var boss = main.room.boss
	if boss != null:
		boss._start_attack("slam")
		await _frames(30)
		await _shot("13_boss_windup")
		await _frames(120)
		boss.hp_state.hp = boss.max_hp / 2 - 4
		boss.receive_hit(HitInfo.make(2, Vector2.ZERO, player, "kick"))
		await _frames(18)
		await _shot("14_boss_phase_two")

	main._open_pause()
	await _frames(10)
	await _shot("15_pause_menu")
	main.menu._set_visible(false)
	main.menu._open = false
	get_tree().paused = false

	DungeonAI.announced.emit("NEW ACHIEVEMENT!", "YOU KICKED A GOBLIN INTO ANOTHER GOBLIN!",
		"The dungeon AI appreciates your commitment to solving every problem with your feet.",
		"Reward: Increased knockback for the next three rooms.")
	await _frames(25)
	await _shot("16_achievement")

	main._on_game_over()
	await _frames(10)
	await _shot("17_game_over")
	get_tree().paused = false
	main.menu._set_visible(false)
	main.menu._open = false

	# Floor 2: a room with an up shaft and a down shaft, then the Mutating Slime.
	main._load_room("f2_Q", "left")
	await _frames(40)
	await _shot("18_floor2_shafts")
	main._load_room("f2_AD", "start")
	await _frames(120)
	await _shot("19_floor2_boss")
	var mutant = main.room.boss
	if mutant != null:
		mutant._start_attack("volley", 1.0)
		await _frames(30)
		await _shot("20_mutant_volley_windup")
		await _frames(90)
		mutant.hp_state.hp = mutant.max_hp / 2 - 4
		mutant.receive_hit(HitInfo.make(2, Vector2.ZERO, main.player, "kick"))
		await _frames(20)
		await _shot("21_mutant_phase_two")

	print("TOUR DONE: ", out_dir)
	get_tree().quit(0)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _tap(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	image.save_png(path)
	print("saved ", path)
