extends Node
## Headless test runner. Run with:
##   godot --headless --path . --scene res://tests/TestRunner.tscn
## Exit code 0 means every check passed. Unit checks run on pure logic; integration checks load the
## real Main scene and drive it through the input map and the room graph.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _checks: int = 0
var _failures: Array[String] = []
var _section: String = ""


func _ready() -> void:
	await get_tree().process_frame
	await _run_all()
	Sfx.stop_all()
	var passed := _checks - _failures.size()
	print("")
	print("Checks: %d   Passed: %d   Failed: %d" % [_checks, passed, _failures.size()])
	for failure in _failures:
		print("  FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run_all() -> void:
	_section = "Health"
	_test_health()
	_section = "Potions"
	_test_potions()
	_section = "Regeneration"
	_test_regen()
	_section = "Save data"
	_test_save_sanitize()
	_section = "Floor maps"
	_test_floor_maps()
	_section = "Room layouts"
	_test_room_layouts()
	_section = "Map walk (integration)"
	await _test_map_walk()
	_section = "Lives and death (integration)"
	await _test_death_and_lives()
	_section = "Every room builds (integration)"
	await _test_all_rooms_build()
	_section = "Shafts in play (integration)"
	await _test_shafts_in_play()
	_section = "Floor advance (integration)"
	await _test_floor_advance()


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_section, label])


# --- Unit tests: rules -----------------------------------------------------------

func _test_health() -> void:
	var h := HealthState.new(100)
	check(h.hp == 100 and h.max_hp == 100, "starts at full health")
	check(h.take_damage(30, 0.0) == 30 and h.hp == 70, "damage reduces HP")
	check(h.take_damage(20, 0.75) == 20 and h.is_invulnerable(), "damage starts invulnerability")
	check(h.take_damage(50, 0.0) == 0 and h.hp == 50, "no damage while invulnerable")
	h.tick(0.8)
	check(not h.is_invulnerable(), "invulnerability expires")
	check(h.heal(500) == 50 and h.hp == 100, "healing never exceeds max HP")
	check(h.take_damage(999, 0.0) == 100 and h.hp == 0, "HP never drops below zero")
	check(not h.is_alive(), "dead at zero HP")
	check(h.heal(50) == 0, "dead characters cannot be healed")


func _test_potions() -> void:
	var inv := PotionInventory.new(3, 10)
	var h := HealthState.new(100)
	h.take_damage(45, 0.0)
	check(inv.drink(h) == 30 and inv.count == 2, "drinking heals 30 and consumes exactly one")
	check(h.hp == 85, "drinking heals up to the 30 HP amount")
	h.take_damage(10, 0.0)
	check(inv.drink(h) == 25 and h.hp == 100 and inv.count == 1, "healing is capped at max HP (heals only the 25 missing)")
	check(inv.drink(h) == 0 and inv.count == 1, "full health: no effect, no potion consumed")
	var empty := PotionInventory.new(0, 10)
	h.take_damage(20, 0.0)
	check(empty.drink(h) == 0 and h.hp == 80, "empty inventory cannot be used")
	var full := PotionInventory.new(10, 10)
	check(full.add(3) == 0 and full.count == 10, "inventory never exceeds 10")
	var partial := PotionInventory.new(8, 10)
	check(partial.add(5) == 2 and partial.count == 10, "pickups stop at capacity")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var drops := 0
	for i in range(5000):
		if PotionInventory.roll_drop(rng, 0.2):
			drops += 1
	var rate := float(drops) / 5000.0
	check(absf(rate - 0.2) < 0.03, "drop chance is configurable and close to 20 percent (got %.3f)" % rate)


func _test_regen() -> void:
	var regen := RegenController.new()
	var hp := 50.0
	var max_hp := 100.0
	var healed := 0.0
	regen.on_combat_ended()
	for i in range(2 * 60):
		healed += regen.tick(1.0 / 60.0, hp + healed, max_hp, true)
	check(healed == 0.0, "no healing during the 3 second delay (2 s elapsed)")
	for i in range(60 * 2):
		healed += regen.tick(1.0 / 60.0, hp + healed, max_hp, true)
	check(regen.active, "healing begins after the 3 second delay")
	check(absf(regen.rate - 5.0) < 0.001, "rate is missing HP / 10 seconds (50 missing = 5 HP/s)")
	for i in range(60 * 4):
		healed += regen.tick(1.0 / 60.0, hp + healed, max_hp, true)
	check(absf(healed - 25.0) < 0.5, "5 HP/s from second 3 to second 8 restores 25 HP in total (got %.2f)" % healed)
	regen.on_combat_started()
	var during := regen.tick(1.0, hp + healed, max_hp, true)
	check(during == 0.0 and not regen.active, "entering combat cancels regeneration immediately")
	regen.on_combat_ended()
	var paused := 0.0
	for i in range(60 * 2):
		paused += regen.tick(1.0 / 60.0, hp + healed, max_hp, true)
	check(paused == 0.0, "the 3 second delay restarts after leaving combat")
	var from_full_missing := regen.tick(10.0, max_hp, max_hp, true)
	check(from_full_missing == 0.0, "no healing at full health")
	regen.reset()
	check(not regen.active and not regen.in_combat, "reset clears regeneration state")


func _test_save_sanitize() -> void:
	var clean: Dictionary = Save.default_data()
	var bad := {"unlocked_floor": "nope", "completed_floors": [1, "x", 9], "abilities": {"explosive_kick": "yes"},
		"settings": {"master": 4.0, "fullscreen": "maybe"}}
	var sanitized: Dictionary = Save._sanitize(bad)
	check(sanitized.unlocked_floor == 1, "invalid unlocked floor falls back to 1")
	check(sanitized.completed_floors == [1], "invalid completed floors are dropped")
	check(sanitized.abilities.explosive_kick == false, "non-boolean ability flags are ignored")
	check(sanitized.settings.master == 1.0 and sanitized.settings.fullscreen == false, "settings are clamped and typed")
	check(clean.has("unlocked_floor"), "default save has the expected keys")


# --- Unit tests: the floor maps and room layouts ------------------------------------

func _reachable(floor_number: int) -> Dictionary:
	var rooms := FloorMaps.rooms(floor_number)
	var start := FloorMaps.entrance_letter(floor_number)
	var seen: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for side in rooms[current]["exits"].keys():
			var next: String = rooms[current]["exits"][side]
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _test_floor_maps() -> void:
	for floor_number in [1, 2]:
		var rooms := FloorMaps.rooms(floor_number)
		var total := 14 if floor_number == 1 else 15
		var combat := 5 if floor_number == 1 else 6
		check(rooms.size() == total, "floor %d has the %d rooms on its map" % [floor_number, total])
		var counts: Dictionary = {}
		for letter in rooms.keys():
			var kind: String = rooms[letter]["kind"]
			counts[kind] = int(counts.get(kind, 0)) + 1
		check(counts.get("entrance", 0) == 1 and counts.get("boss", 0) == 1,
			"floor %d has one entrance and one boss" % floor_number)
		check(counts.get("combat", 0) == combat, "floor %d has %d combat rooms" % [floor_number, combat])
		check(counts.get("challenge", 0) == 4, "floor %d has four challenge rooms" % floor_number)
		check(counts.get("safe", 0) == 3, "floor %d has three safe rooms" % floor_number)
		for letter in rooms.keys():
			for side in rooms[letter]["exits"].keys():
				var other: String = rooms[letter]["exits"][side]
				var back: String = FloorMaps.OPPOSITE[side]
				check(rooms[other]["exits"].get(back, "") == letter,
					"floor %d: %s %s to %s is a two-way link" % [floor_number, letter, side, other])
				if side == "up" or side == "down":
					check(rooms[other]["vertical"].get(back, -1.0) == rooms[letter]["vertical"][side],
						"floor %d: the shafts between %s and %s line up" % [floor_number, letter, other])
		check(_reachable(floor_number).size() == total, "every room on floor %d is reachable from the entrance" % floor_number)
		var route := RoomData.path(floor_number)
		check(not route.is_empty() and route[0] == RoomData.start_room(floor_number)
			and route[route.size() - 1] == RoomData.boss_room(floor_number),
			"floor %d has a route from the entrance to the boss" % floor_number)
	check(FloorMaps.tutorial_letters(1) == ["A", "B", "C", "D"], "floor 1's tutorial covers the first four rooms")


func _overlaps_shaft(rect: Rect2, x: float) -> bool:
	return rect.position.x < x + 90.0 and rect.end.x > x - 90.0


func _test_room_layouts() -> void:
	for floor_number in [1, 2]:
		var rooms := FloorMaps.rooms(floor_number)
		for letter in rooms.keys():
			var id := FloorMaps.room_id(floor_number, letter)
			var layout := RoomData.layout(id)
			check(not layout.is_empty(), "%s builds a layout" % id)
			if layout.is_empty():
				continue
			var kind: String = layout["kind"]
			var exits: Dictionary = layout["exits"]
			check(layout["openings"].size() == exits.size(), "%s has one opening per exit" % id)
			for side in exits.keys():
				check(layout["spawn"].has(side), "%s can be entered from %s" % [id, side])
			check(layout["spawn"].has("start"), "%s has a start point" % id)
			var enemy_count: int = layout["enemies"].size()
			match kind:
				"entrance":
					check(enemy_count == 0, "%s (entrance) has no enemies" % id)
				"safe":
					check(enemy_count == 0 and layout["bonfire"] != Vector2.ZERO, "%s (safe) has no enemies and a bonfire" % id)
				"combat":
					check(enemy_count >= 2 and enemy_count <= 3, "%s (combat) has two or three enemies" % id)
				"challenge":
					check(enemy_count >= 2 and layout["chest"] != Vector2.ZERO, "%s (challenge) has enemies and a chest" % id)
				"boss":
					check(enemy_count == 1, "%s (boss) has exactly one boss" % id)
			var content := RoomData.content(id)
			for side in ["up", "down"]:
				if not exits.has(side):
					continue
				var x: float = layout["vertical"][side]
				for rect in content.get("platforms", []) + content.get("one_way", []):
					check(not _overlaps_shaft(rect, x), "%s keeps platforms clear of its %s shaft" % [id, side])
				for spec in content.get("enemies", []):
					var pos: Vector2 = spec["pos"]
					check(absf(pos.x - x) > 80.0, "%s starts no enemy in its %s shaft" % [id, side])
					if side == "down":
						var patrol: Array = spec["patrol"]
						check(float(patrol[1]) < x - 80.0 or float(patrol[0]) > x + 80.0,
							"%s keeps the patrol of an enemy off its floor hole" % id)
				for hazard_rect in content.get("spikes", []):
					check(not _overlaps_shaft(hazard_rect, x), "%s keeps spikes clear of its %s shaft" % [id, side])
	for letter in FloorMaps.tutorial_letters(1):
		var tutorial := RoomData.layout(FloorMaps.room_id(1, letter))
		check(tutorial["signs"].size() > 0, "tutorial room %s has a hint sign" % letter)


# --- Integration tests: driving the real game --------------------------------------

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _tap(action: String, frames: int = 3) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)


func _start_game_in_main(main: Node) -> void:
	Game.start_new_game()
	main._build_world()
	main._enter_floor(1, false)


## Takes an exit from the current room and waits for the transition to finish.
func _go(main: Node, side: String, expected_id: String) -> void:
	main._on_door_requested(main.room, side)
	var waited := 0
	while main._busy and waited < 240:
		await get_tree().process_frame
		waited += 1
	await _frames(3)
	check(main.room.room_id == expected_id, "going %s leads to %s (got %s)" % [side, expected_id, main.room.room_id])


func _kill_all(room: RoomBase, player: Player) -> void:
	for enemy in room.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var info := HitInfo.make(9999, Vector2.ZERO, player, "kick")
			info.from_player = true
			enemy.receive_hit(info)


func _chest_in(room: RoomBase) -> TreasureChest:
	for child in room.get_children():
		if child is TreasureChest:
			return child
	return null


func _test_map_walk() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(2)
	_start_game_in_main(main)
	await _frames(4)
	var player: Player = main.player
	check(main.room.room_id == "f1_A", "a new game starts in the floor's entrance room")
	check(player.health.hp == Config.PLAYER_MAX_HP and Game.potions.count == Config.POTION_START,
		"a new game starts with full health and three potions")

	# Entrance A -> combat B: the encounter starts on entry and the exits lock.
	await _go(main, "right", "f1_B")
	var room: RoomBase = main.room
	check(room.enemies.size() == 2 and room.active and room.is_locked(), "B wakes its goblins and locks its exits")
	check(CombatState.in_combat(), "the encounter counts as combat")
	var goblin: Node = room.enemies[0]
	goblin.global_position = player.global_position + Vector2(40.0, 0.0)
	goblin.process_mode = Node.PROCESS_MODE_INHERIT
	goblin.velocity = Vector2.ZERO
	await _frames(2)
	var before: int = goblin.hp_state.hp
	await _tap(Controls.ATTACK, 4)
	await _frames(20)
	check(goblin.hp_state.hp < before, "a kick damages a goblin in front of the player")
	check(goblin.engaged, "a hit engages the enemy")
	_kill_all(room, player)
	await _frames(40)
	check(room.cleared and not room.is_locked(), "clearing B unlocks its exits")
	check(Game.is_room_cleared("f1_B") and not CombatState.in_combat(), "B is remembered as cleared and combat ends")

	# Potions and mode switching, while the room is quiet.
	player.health.hp = 60
	player.health.invuln_left = 0.0
	var count_before := Game.potions.count
	await _tap(Controls.POTION, 2)
	check(Game.potions.count == count_before - 1, "pressing H consumes exactly one potion")
	check(player.health.hp >= 60 + Config.POTION_HEAL - 1, "H heals 30 HP (got %d)" % player.health.hp)
	var pos_before := player.global_position
	var hp_before := player.health.hp
	await _tap(Controls.SWITCH_MODE, 2)
	check(player.mode == Player.Mode.DONUT, "Tab switches to Donut mode")
	check(player.global_position.distance_to(pos_before) < 1.0 and player.health.hp == hp_before,
		"switching modes keeps position and health")
	await _tap(Controls.SWITCH_MODE, 2)
	check(player.mode == Player.Mode.CARL, "Tab switches back to Carl mode")

	# Safe room C: no enemies, a bonfire.
	await _go(main, "right", "f1_C")
	check(main.room.enemies.is_empty() and main.room.layout["bonfire"] != Vector2.ZERO, "C is a quiet room with a bonfire")

	# Challenge room D: the chest only opens after the fight.
	await _go(main, "right", "f1_D")
	var chest := _chest_in(main.room)
	check(chest != null and not chest.available, "D's chest is locked while the challenge is on")
	_kill_all(main.room, player)
	await _frames(40)
	check(main.room.cleared and chest.available, "clearing D unlocks its chest")
	main._open_treasure(main.room)
	check(main.menu.is_open() and get_tree().paused, "the treasure menu pauses the game")
	main._on_menu_chosen("kick_damage")
	main.menu._close()
	check(Game.has_upgrade("kick_damage") and Game.is_reward_taken("f1_D"), "choosing an upgrade grants it and is remembered")
	check(chest.opened and not chest.available and not get_tree().paused, "the chest opens and the game resumes")
	var hp_before_upgrade: int = player.health.hp
	Game.add_upgrade("max_hp")
	player.refresh_max_hp()
	check(player.health.max_hp == Config.PLAYER_MAX_HP + Config.UPGRADE_MAX_HP,
		"a max-HP upgrade raises the cap during the floor")
	check(player.health.hp == hp_before_upgrade + Config.UPGRADE_MAX_HP,
		"the max-HP upgrade also adds that much current HP")
	check(Game.modifier("kick_damage") == 1.0 + Config.UPGRADE_KICK_DAMAGE, "kick damage upgrade multiplies kicks")

	# Pause menu: opening pauses, choosing Resume resumes.
	main._open_pause()
	check(get_tree().paused and main.menu.is_open(), "pause opens and pauses the game")
	main._on_menu_chosen("resume")
	main.menu._close()
	check(not get_tree().paused, "resume unpauses the game")

	# Combat room E has a shaft up to F and a shaft down to J. Go up, then come back down.
	await _go(main, "right", "f1_E")
	check(main.room.enemies.size() == 2, "E has its two goblins")
	await _go(main, "up", "f1_F")
	var spawn_x: float = RoomData.layout("f1_F")["spawn"]["down"].x
	check(absf(player.global_position.x - spawn_x) < 2.0, "coming up into F places the player at its floor, beside the hole")
	await _go(main, "down", "f1_E")
	var up_x: float = RoomData.layout("f1_E")["vertical"]["up"]
	check(absf(player.global_position.x - up_x) < 2.0, "dropping back into E lands under its ceiling shaft")
	get_tree().paused = false
	main.queue_free()
	await _frames(4)


func _test_death_and_lives() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(2)
	_start_game_in_main(main)
	await _frames(4)
	var player: Player = main.player
	var lives_before := Game.lives
	var room_before: String = main.room.room_id
	player.receive_hit(HitInfo.make(Config.PLAYER_MAX_HP, Vector2.ZERO, null, "test"))
	check(not player.alive, "lethal damage kills the player")
	await get_tree().create_timer(Config.PLAYER_HIT_INVULN + 1.8, true, false, true).timeout
	await _frames(20)
	check(Game.lives == lives_before - 1, "death removes exactly one life")
	check(player.alive and player.health.hp == Config.PLAYER_MAX_HP, "respawn restores full health")
	check(main.room.room_id == room_before, "death restarts the current room")
	check(Game.potions.count == Config.POTION_START, "potions are kept through a death")
	get_tree().paused = false
	main.queue_free()
	await _frames(4)


func _test_all_rooms_build() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(2)
	_start_game_in_main(main)
	await _frames(2)
	for floor_number in [1, 2]:
		for letter in FloorMaps.rooms(floor_number).keys():
			var room_id := FloorMaps.room_id(floor_number, letter)
			main._load_room(room_id, "start")
			await _frames(2)
			var layout := RoomData.layout(room_id)
			check(main.room.enemies.size() == layout["enemies"].size(), "%s spawns every enemy in its layout" % room_id)
			check(main.room.spawn_point("start").y == RoomData.STAND_Y, "%s starts on the floor" % room_id)
	main._load_room("f2_AD", "start")
	await _frames(2)
	check(main.room.boss is MutatingSlime, "floor 2 ends with the Mutating Slime boss")
	main._load_room("f1_N", "start")
	await _frames(2)
	check(main.room.boss is GoblinBrute, "floor 1 ends with the Goblin Brute boss")
	get_tree().paused = false
	main.queue_free()
	await _frames(4)


func _phys(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _settle_on_floor(player: Player, max_frames: int) -> void:
	var waited := 0
	while not player.is_on_floor() and waited < max_frames:
		await get_tree().physics_frame
		waited += 1


func _wait_for_transition(main: Node, leaving: String) -> void:
	var waited := 0
	while (main._busy or main.room.room_id == leaving) and waited < 300:
		await get_tree().process_frame
		waited += 1
	await _frames(3)


## Real physics, real jumps: the player climbs a shaft's stairs and drops through a floor hole.
func _test_shafts_in_play() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(2)
	_start_game_in_main(main)
	await _frames(4)
	var player: Player = main.player

	# Climb: safe room I has an up shaft at x = 400 that leads to H.
	main._load_room("f1_I", "start")
	await _frames(4)
	player.global_position = Vector2(400.0, RoomData.STAND_Y)
	player.velocity = Vector2.ZERO
	await _frames(6)
	for attempt in range(20):
		if main._busy or main.room.room_id != "f1_I":
			break
		await _settle_on_floor(player, 120)
		# Hold the jump to its peak: releasing early cuts the jump short (variable jump height).
		# Timed in physics frames, because jumps are physics-driven.
		Input.action_press(Controls.JUMP)
		await _phys(36)
		Input.action_release(Controls.JUMP)
		await _phys(12)
	await _wait_for_transition(main, "f1_I")
	check(main.room.room_id == "f1_H", "climbing I's up stairs reaches H")

	# Fall: stepping into I's floor hole (x = 880) drops the player into L, arriving under L's ceiling.
	main._load_room("f1_I", "start")
	await _frames(4)
	player.global_position = Vector2(880.0, 560.0)
	player.velocity = Vector2.ZERO
	await _wait_for_transition(main, "f1_I")
	check(main.room.room_id == "f1_L", "falling through I's floor hole drops into L")
	check(absf(player.global_position.x - 880.0) < 2.0, "the fall arrives under L's ceiling shaft")
	get_tree().paused = false
	main.queue_free()
	await _frames(4)


func _test_floor_advance() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(2)
	_start_game_in_main(main)
	await _frames(2)
	Game.potions = PotionInventory.new(4)
	Game.lives = 1
	main._advance_floor()
	await _frames(60)
	check(Game.floor_number == 2 and main.room.room_id == "f2_P", "advancing moves to floor 2's entrance")
	check(Game.lives == Config.LIVES, "advancing to a new floor restores three lives")
	check(Game.potions.count == 4, "advancing keeps unused potions")
	get_tree().paused = false
	main.queue_free()
	await _frames(4)
