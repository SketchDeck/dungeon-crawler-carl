extends Node
## Headless test runner scene: godot --headless --path . tests/TestRunner.tscn
## Exits with code 1 if any check fails.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")
const SLIME_BOSS_SCENE := preload("res://scenes/bosses/SlimeBoss.tscn")
const GOBLIN_SCENE := preload("res://scenes/enemies/Goblin.tscn")
const BOSS_SCENE := preload("res://scenes/bosses/GoblinBoss.tscn")
const SHIELD_GOBLIN_SCENE := preload("res://scenes/enemies/ShieldGoblin.tscn")
const ARMORED_SLIME_SCENE := preload("res://scenes/enemies/ArmoredSlime.tscn")
const BAT_SCENE := preload("res://scenes/enemies/Bat.tscn")

var _passed := 0
var _failed := 0
var _current := ""


func _ready() -> void:
	# Keep running while the Game Over screen pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	Fx.hitstop_enabled = false
	# Never touch the real save file.
	SaveManager.save_path = "user://test_save.json"
	SaveManager.delete_save()
	GameManager.reset_progress()
	GameManager.reset_profile()
	# Default settings and key bindings, whatever the real save says.
	Settings.load_settings()
	await _test("health clamps, invulnerability and death", test_health)
	await _test("hurt invulnerability lasts 0.75s", test_hurt_invuln_duration)
	await _test("kick combo deals 10/10/20", test_kick_combo_damage)
	await _test("kick combo resets after the window", test_combo_window_expires)
	await _test("finisher knocks the goblin back", test_finisher_knockback)
	await _test("charged kick damage scales 15..35", test_charged_kick_scaling)
	await _test("full charged kick deals 35", test_charged_kick_full)
	await _test("goblin attack damages player", test_goblin_hits_player)
	await _test("dead goblin cannot attack", test_dead_goblin_cannot_attack)
	await _test("dead enemies ignore hits", test_dead_enemy_ignores_hits)
	await _test("armored windup ignores light hits", test_armored_windup)
	await _test("dodge grants i-frames and moves", test_dodge)
	await _test("player death and respawn", test_player_respawn)
	# Milestone 2: potions, combat state, regeneration.
	await _test("potion heals 30 or the missing amount", test_potion_heal_amounts)
	await _test("potion use guards (empty/full/dead/cooldown)", test_potion_guards)
	await _test("potion capacity is 10", test_potion_capacity)
	await _test("drop chance is respected", test_drop_chance)
	await _test("dying enemy spawns a potion when it rolls a drop", test_enemy_drops_potion)
	await _test("pickup collected on touch", test_pickup_collect)
	await _test("pickup stays on ground when inventory full", test_pickup_full)
	await _test("engaged enemies drive combat state", test_combat_state_enemies)
	await _test("regen waits 3s then heals to full over 10s", test_regen_timing)
	await _test("regen does not consume potions", test_regen_no_potions)
	await _test("combat interrupts regen; resumes after new delay", test_regen_interrupt)
	await _test("potion during regen keeps regenerating", test_regen_with_potion)
	await _test("no regen while dead", test_regen_dead)
	await _test("no regen during boss encounter", test_regen_boss)
	await _test("respawn keeps potions and resets healing", test_respawn_keeps_potions)
	# Milestone 3: rooms and lives.
	await _test("floor 1 rooms match the layout document", test_floor1_graph)
	await _test("room transitions lead to the correct destinations", test_room_transition)
	await _test("combat room locks until enemies are cleared", test_combat_room_locking)
	await _test("cleared rooms remain cleared", test_cleared_room_stays_cleared)
	await _test("death removes one life and resets the room", test_death_resets_room)
	await _test("death keeps progress in other rooms", test_death_keeps_floor_progress)
	await _test("game over restarts the floor", test_game_over_restart)
	await _test("falling into a pit hurts and returns to entrance", test_pit_fall)
	await _test("switch trial opens the vault and chest", test_switch_trial)
	await _test("defeat trial unlocks the chest", test_defeat_trial)
	await _test("reach trial chest is open from the start", test_reach_trial)
	await _test("fountain heals to full once", test_fountain)
	await _test("full jump clears a 3-tile ledge (room design rule)", test_jump_clears_three_tiles)
	await _test("every room objective is reachable from the entrance", test_rooms_reachable)
	await _test("running jump crosses a 4-tile pit (room design rule)", test_jump_crosses_pit)
	# Milestone 4: Donut combat and mode switching.
	await _test("mode switch is instant and keeps position/health", test_mode_switch_instant)
	await _test("movement is identical in both modes", test_switch_keeps_movement)
	await _test("switch during a windup is queued until the attack fires", test_switch_queued_during_windup)
	await _test("magic missile deals 12 and knocks back", test_magic_missile)
	await _test("magic missile has limited range", test_missile_range)
	await _test("magic missile fires in the facing direction", test_missile_facing_left)
	await _test("charged blast scales 18..35 and grows", test_charged_blast_scaling)
	await _test("full charged blast deals 35, then cools down", test_charged_blast_full)
	await _test("cooldowns survive switching", test_cooldowns_survive_switch)
	await _test("projectiles keep flying after a switch", test_projectile_after_switch)
	await _test("switching cancels a charge without firing", test_switch_cancels_charge)
	await _test("walls stop bolts; one-way platforms don't", test_projectile_walls)
	await _test("bolts trigger switches", test_projectile_hits_switch)
	await _test("dead player cannot switch", test_dead_cannot_switch)
	await _test("bolts are cleared when the room unloads", test_projectiles_cleared_on_room_change)
	# Milestone 5: Goblin Brute.
	await _test("boss is immune until the fight starts", test_boss_dormant_and_immune)
	await _test("swing is telegraphed, then hits for 22", test_boss_swing)
	await _test("swing can be dodged through", test_boss_swing_dodged)
	await _test("slam shockwave hits grounded players", test_boss_slam_hits)
	await _test("jumping or standing on a platform avoids the shockwave", test_boss_slam_avoided)
	await _test("shockwaves reach further in phase 2", test_boss_wave_range)
	await _test("charge hits the player and dazes the boss at the wall", test_boss_charge)
	await _test("attacks are followed by a recovery window", test_boss_recovery)
	await _test("phase 2 starts at 50% with an immune roar", test_boss_phase_two)
	await _test("phase 2 chains at most two attacks", test_boss_chain)
	await _test("never the same attack three times in a row", test_boss_no_triple)
	await _test("dead boss cannot attack", test_boss_dead_no_attack)
	await _test("boss drops two potions", test_boss_drops_potions)
	await _test("boss room: fight, boss bar, victory, floor unlock", test_boss_room_flow)
	await _test("dying in the boss fight resets the boss", test_boss_death_resets)
	await _test("stairs open the Floor Complete screen; replay restarts", test_floor_complete)
	# Milestone 6: specials, unlocks, upgrades, environment.
	await _test("specials are locked until unlocked", test_specials_locked)
	await _test("explosive kick explodes on impact", test_explosive_kick)
	await _test("explosive kick sets off barrels", test_explosive_kick_barrel)
	await _test("area magic burst hits all around", test_area_burst)
	await _test("beating floors unlocks the specials", test_floor_unlocks)
	await _test("unlocks persist in the save file", test_unlocks_persist)
	await _test("missing or broken save files don't crash", test_bad_save_file)
	await _test("debug option unlocks both specials", test_debug_unlock)
	await _test("upgrades apply their effects and clear exactly", test_upgrade_effects)
	await _test("upgrade rolls offer distinct choices", test_upgrade_roll)
	await _test("treasure chest pauses for an upgrade choice", test_treasure_selection)
	await _test("upgrades survive death but reset with the floor", test_upgrades_reset)
	await _test("spikes hurt the player and kill enemies", test_spikes)
	await _test("barrels explode, hurt both sides and chain", test_barrels)
	await _test("crates and cracked walls need strong hits", test_breakables)
	await _test("kicked enemies damage enemies they hit, once", test_enemy_collision)
	await _test("weak knockback causes no collision damage", test_weak_knockback_no_collision)
	# Milestone 7: Dungeon AI.
	await _test("real enemy collisions and deaths reach the Dungeon AI", test_ai_events)
	await _test("collision achievement: announced once, knockback boost", test_ai_collision)
	await _test("boosts last this room and the next three", test_ai_boost_duration)
	await _test("environmental kill achievement: damage boost", test_ai_environment_kill)
	await _test("untouchable room clear heals; getting hit spoils it", test_ai_untouchable)
	await _test("announcements queue and never pause the game", test_ai_announcements)
	await _test("boosts survive death; floor restart clears them", test_ai_boost_reset)
	# Milestone 8 part 1: Floor 2, slimes, Mutating Slime.
	await _test("floor 2 rooms match the layout document", test_floor2_graph)
	await _test("slime squashes (telegraph) then hops at the player", test_slime_hop)
	await _test("slime only hurts while airborne", test_slime_contact)
	await _test("slime won't hop into a spike pit", test_slime_avoids_pit)
	await _test("dead slime can't hurt", test_slime_dead)
	await _test("volley globs land where the telegraph shows", test_slime_boss_volley)
	await _test("standing in a gap avoids the volley", test_slime_boss_volley_gap)
	await _test("jump slam lands on the marker and leaves acid", test_slime_boss_jump)
	await _test("phase 2: more globs, acid globs, minis", test_slime_boss_phase_two)
	await _test("slime boss death clears minis and acid, drops potions", test_slime_boss_death)
	await _test("slime boss sinks through one-way platforms", test_slime_boss_platforms)
	await _test("Floor 1 Complete continues to Floor 2", test_continue_to_floor2)
	await _test("beating Floor 2 unlocks Magic Burst and ends the run", test_floor2_complete)
	# Milestone 8 part 2: menus, settings, saves.
	await _test("progress and settings share the save without clobbering", test_save_merge)
	await _test("volume settings drive the audio buses and persist", test_settings_volume)
	await _test("fullscreen setting persists", test_settings_fullscreen)
	await _test("keys can be remapped, persist and reset", test_rebind)
	await _test("main menu: fresh start has no Continue", test_menu_fresh)
	await _test("main menu: Continue and floor select after progress", test_menu_continue)
	await _test("main menu: New Game asks before erasing progress", test_menu_new_game_confirm)
	await _test("starting a floor from the menu is a fresh run", test_menu_floor_start)
	await _test("pause menu pauses, resumes and leaves", test_pause_menu)
	await _test("pause key toggles the pause menu", test_pause_key)
	await _test("game over and floor complete offer Main Menu", test_menu_buttons)
	# Milestone 8 part 3: audio, controller, full run.
	await _test("every sound the code plays exists", test_sound_files)
	await _test("gameplay triggers sound effects", test_sound_hooks)
	await _test("music follows menus, floors and bosses", test_music)
	await _test("every action works on a controller", test_controller_bindings)
	await _test("prompts switch between keyboard and controller", test_controller_prompts)
	await _test("full run: both floors, start to finish", test_full_run)
	# Milestone 9: switching matters.
	await _test("shield goblin blocks kicks from the front only", test_shield_goblin)
	await _test("armored slime: magic splashes off until a heavy kick cracks it", test_armored_slime)
	await _test("bat flies, telegraphs and dives at the player", test_bat_dive)
	await _test("bolts curve up to hit bats", test_bolts_seek_bats)
	await _test("power-kicked enemies take double magic damage (juggle)", test_juggle)
	await _test("new enemies spawn from room letters", test_new_enemy_letters)
	await _test("sign text shows the current keys", test_sign_prompts)
	# Milestone 10: behaviour upgrades.
	await _test("rolls are weighted by rarity and skip owned behaviour upgrades", test_upgrade_rarity_roll)
	await _test("piercing bolts hit every enemy in a line", test_upgrade_piercing)
	await _test("double tap fires a second, weaker bolt", test_upgrade_twin_bolts)
	await _test("seismic stomp: the finisher sends a shockwave", test_upgrade_kick_wave)
	await _test("hot feet: dodging leaves fire that burns enemies", test_upgrade_fire_dodge)
	await _test("explosive digestion: potions blast enemies", test_upgrade_potion_burst)
	await _test("tag-in fury: switching boosts damage briefly", test_upgrade_frenzy)
	await _test("tag team: switching readies the new mode", test_upgrade_tag_team)
	await _test("lifesteal and volatile corpses trigger on kills", test_upgrade_kill_effects)
	await _test("juggle master raises the juggle multiplier", test_upgrade_juggle_master)
	await _test("upgrade cards show rarity", test_upgrade_cards_rarity)
	# Milestone 11: Dungeon AI loop.
	await _test("every achievement is defined and pays a box and viewers", test_achievement_rewards)
	await _test("per-floor achievements trigger once per floor", test_achievement_per_floor)
	await _test("kill achievements: first blood, triple, chain, overkill, spicy", test_kill_achievements)
	await _test("enemy achievements: shield, bat, shell, dynamic duo", test_enemy_achievements)
	await _test("room achievements: close call, hoarder, pit diver, walls", test_room_achievements)
	await _test("boss achievements: boss rush, sober, deathless", test_boss_achievements)
	await _test("viewers: kills, style kills and cleared rooms", test_viewers)
	await _test("grades follow viewers and deaths", test_grades)
	await _test("fountain opens loot boxes; rewards by tier", test_loot_boxes)
	await _test("loot boxes carry over to the next floor", test_loot_carry_over)
	await _test("floor complete shows the run summary and saves the best", test_run_summary)
	await _test("profile survives reloads and New Game", test_profile_persists)
	await _test("extras menu shows the trophy case and hats", test_extras_menu)
	# Milestone 12: replayability.
	await _test("each floor run picks a variant per room", test_room_variants)
	await _test("? markers spawn from the floor's pool, the same on a restart", test_random_spawns)
	await _test("replays add a sponsor event; first runs don't", test_sponsor_events)
	await _test("modifiers change enemies, damage and viewers", test_modifier_effects)
	await _test("explosive personality: enemies explode on death", test_modifier_explosive)
	await _test("hard mode unlocks after Floor 2 and persists", test_hard_mode)
	await _test("daily run uses the day's seed and two events", test_daily_run)
	GameManager.floor_number = 1
	SaveManager.delete_save()
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Harness ----------------------------------------------------------------

func _test(name: String, fn: Callable) -> void:
	_current = name
	var before := _failed
	await fn.call()
	print("%s  %s" % ["PASS" if _failed == before else "FAIL", name])
	get_tree().paused = false
	# Free everything a test created (Godot renames duplicate "TestWorld"
	# nodes, so don't rely on names).
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame


func check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("    ✗ [%s] %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	var ok: bool = is_equal_approx(actual, expected) if actual is float or expected is float else actual == expected
	check(ok, "%s (expected %s, got %s)" % [message, expected, actual])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func world() -> Node2D:
	var w := Node2D.new()
	w.name = "TestWorld"
	add_child(w)
	var ground := SolidBlock.new()
	ground.size = Vector2(4000, 40)
	ground.position = Vector2(-2000, 0)
	w.add_child(ground)
	return w


func spawn_player(w: Node2D, x := 0.0) -> Player:
	var p := PLAYER_SCENE.instantiate() as Player
	p.position = Vector2(x, -28)
	w.add_child(p)
	p.read_input = false
	p.combat.read_input = false
	return p


func spawn_goblin(w: Node2D, x: float, ai := false) -> Goblin:
	var g := GOBLIN_SCENE.instantiate() as Goblin
	g.position = Vector2(x, -20)
	g.ai_enabled = ai
	w.add_child(g)
	return g


# --- Tests ------------------------------------------------------------------

func test_health() -> void:
	var w := world()
	var h := PlayerHealth.new()
	w.add_child(h)
	check_eq(h.current, 100.0, "starts at max")
	check(h.take_damage(30.0), "damage applies")
	check_eq(h.current, 70.0, "30 damage")
	check(not h.take_damage(10.0), "invulnerable right after a hit")
	check_eq(h.heal(50.0), 30.0, "heal returns only restored amount")
	check_eq(h.current, 100.0, "heal capped at max")
	check_eq(h.heal(10.0), 0.0, "no heal at full health")
	var died := [0]
	h.died.connect(func() -> void: died[0] += 1)
	h._invuln = 0.0
	h.take_damage(500.0)
	check_eq(h.current, 0.0, "health never below zero")
	check(h.is_dead, "dead at zero")
	check_eq(died[0], 1, "died emitted once")
	check_eq(h.heal(10.0), 0.0, "cannot heal while dead")
	check(not h.take_damage(5.0), "no damage while dead")


func test_hurt_invuln_duration() -> void:
	var w := world()
	var h := PlayerHealth.new()
	w.add_child(h)
	h.take_damage(10.0)
	await frames(40)  # ~0.67s
	check(h.is_invulnerable(), "still invulnerable at ~0.67s")
	await frames(8)  # ~0.8s
	check(not h.is_invulnerable(), "vulnerable again after 0.75s")


func test_kick_combo_damage() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	var kick := p.combat.kick_combo
	kick.press()
	await frames(20)
	check_eq(g.health, 40.0, "first kick 10")
	kick.press()
	await frames(20)
	check_eq(g.health, 30.0, "second kick 10")
	kick.press()
	await frames(10)
	check_eq(g.health, 10.0, "third kick 20")


func test_combo_window_expires() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	var kick := p.combat.kick_combo
	kick.press()
	await frames(50)  # recovery + 0.35s window has passed
	kick.press()
	check_eq(kick.current, 0, "combo restarted at first kick")
	await frames(10)
	check_eq(g.health, 30.0, "both hits were first-kick damage")


func test_finisher_knockback() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	var kick := p.combat.kick_combo
	for i in 3:
		kick.press()
		await frames(20)
	check(g.global_position.x > 70.0, "goblin pushed right (x=%.1f)" % g.global_position.x)
	var p2 := spawn_player(w, 600.0)
	p2.facing = -1
	var g2 := spawn_goblin(w, 560.0)
	await frames(5)
	for i in 3:
		p2.combat.kick_combo.press()
		await frames(20)
	check(g2.global_position.x < 530.0, "facing left knocks left (x=%.1f)" % g2.global_position.x)


func test_charged_kick_scaling() -> void:
	var w := world()
	var p := spawn_player(w)
	var ck := p.combat.charged_kick
	check_eq(ck.damage_for_ratio(0.0), 15.0, "min damage")
	check_eq(ck.damage_for_ratio(1.0), 35.0, "max damage")
	check_eq(ck.damage_for_ratio(5.0), 35.0, "clamped above")
	check(ck.knockback_for_ratio(1.0).x > ck.knockback_for_ratio(0.0).x, "knockback grows with charge")


func test_charged_kick_full() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	var ck := p.combat.charged_kick
	ck.press()
	await frames(70)
	check_eq(ck.charge_ratio(), 1.0, "fully charged after 1s")
	ck.release()
	await frames(10)
	check_eq(g.health, 15.0, "35 damage")
	check(g.velocity.x > 0.0 or g.global_position.x > 60.0, "goblin launched")
	await frames(30)
	check(not ck.is_active(), "kick finished")
	check(ck.cooldown_remaining > 0.0, "cooldown started")
	ck.press()
	check(not ck.is_charging(), "cannot charge during cooldown")


func test_goblin_hits_player() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0, true)
	var saw_windup := false
	for i in 120:
		await get_tree().physics_frame
		saw_windup = saw_windup or g.is_telegraphing()
		if p.health.current < 100.0:
			break
	check(saw_windup, "attack was telegraphed")
	check(g.is_engaged, "goblin engaged")
	check_eq(p.health.current, 88.0, "goblin deals 12")


func test_dead_goblin_cannot_attack() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0, true)
	for i in 120:
		await get_tree().physics_frame
		if g.is_telegraphing():
			break
	check(g.is_telegraphing(), "goblin winding up")
	g.take_hit(Hit.new(999.0))
	check(g.is_dead, "goblin dead")
	check_eq(g.collision_layer, 0, "dead goblin not hittable")
	await frames(60)
	check_eq(p.health.current, 100.0, "no damage after death")
	check(not is_instance_valid(g), "corpse removed")


func test_dead_enemy_ignores_hits() -> void:
	var w := world()
	var g := spawn_goblin(w, 40.0)
	var deaths := [0]
	g.died.connect(func(_e: EnemyBase) -> void: deaths[0] += 1)
	g.take_hit(Hit.new(999.0))
	g.take_hit(Hit.new(10.0))
	check_eq(g.health, 0.0, "health stays at zero")
	check_eq(deaths[0], 1, "died once")


func test_armored_windup() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0, true)
	for i in 120:
		await get_tree().physics_frame
		if g.is_telegraphing():
			break
	g.take_hit(Hit.new(10.0, Vector2(100, -50)))
	check(g.is_telegraphing(), "light hit does not interrupt")
	g.take_hit(Hit.new(20.0, Vector2(300, -100)))
	check(not g.is_telegraphing(), "heavy hit interrupts")
	check(g.in_knockback, "heavy hit knocks back")
	check(p.health.current == 100.0, "player untouched")


func test_dodge() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(5)
	var start_x := p.global_position.x
	check(p.try_dodge(1.0), "dodge starts")
	check(not p.take_hit(Hit.new(10.0)), "invulnerable at dodge start")
	check(not p.try_dodge(1.0), "cannot dodge again immediately")
	await frames(14)
	check(p.global_position.x - start_x > 100.0, "dodge travels (%.1f px)" % (p.global_position.x - start_x))
	check(p.take_hit(Hit.new(10.0)), "vulnerable after i-frames")
	await frames(40)
	check(p.try_dodge(1.0), "dodge available after 0.8s cooldown")


func test_player_respawn() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(3)
	p.take_hit(Hit.new(150.0))
	check(p.health.is_dead, "player dead")
	check_eq(p.health.current, 0.0, "health clamped to zero")
	p.respawn(Vector2(100, -28))
	check(not p.health.is_dead, "alive after respawn")
	check_eq(p.health.current, 100.0, "full health after respawn")
	check_eq(p.global_position, Vector2(100, -28), "moved to spawn")


# --- Milestone 2: potions, combat state, regeneration -----------------------

const POTION_SCENE := preload("res://scenes/pickups/PotionPickup.tscn")


## Seconds -> physics frames at 60 Hz.
func secs(s: float) -> int:
	return roundi(s * 60.0)


func set_health(p: Player, value: float) -> void:
	p.health.current = value
	p.health.health_changed.emit(value, p.health.max_health)


func test_potion_heal_amounts() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	set_health(p, 50.0)
	check(p.potions.use(), "potion used at 50 HP")
	check_eq(p.health.current, 80.0, "healed 30")
	check_eq(p.potions.count, 2, "count decreased by exactly one")
	await frames(secs(0.55))
	set_health(p, 90.0)
	check(p.potions.use(), "potion used at 90 HP")
	check_eq(p.health.current, 100.0, "capped at max (healed 10)")
	check_eq(p.potions.count, 1, "count decreased by exactly one again")


func test_potion_guards() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	check(not p.potions.use(), "no use at full health")
	check_eq(p.potions.count, 3, "potion not wasted at full health")
	set_health(p, 20.0)
	check(p.potions.use(), "first use ok")
	check(not p.potions.use(), "second use blocked by 0.5s cooldown")
	check_eq(p.potions.count, 2, "cooldown kept the potion")
	await frames(secs(0.55))
	check(p.potions.use(), "usable after cooldown")
	await frames(secs(0.55))
	p.potions.reset(0)
	check(not p.potions.use(), "no use with empty inventory")
	check_eq(p.potions.count, 0, "still zero")
	p.potions.reset(3)
	p.health.take_damage(500.0)
	check(not p.potions.use(), "dead players cannot use potions")
	check_eq(p.potions.count, 3, "dead: potions untouched")


func test_potion_capacity() -> void:
	var w := world()
	var p := spawn_player(w)
	check_eq(p.potions.count, 3, "new game starts with 3")
	for i in 7:
		check(p.potions.add(), "add up to 10")
	check_eq(p.potions.count, 10, "at capacity")
	check(not p.potions.add(), "11th rejected")
	check_eq(p.potions.count, 10, "never exceeds 10")


func test_drop_chance() -> void:
	var w := world()
	var g := spawn_goblin(w, 300.0)
	check_eq(g.potion_drop_chance, 0.2, "default drop chance 20%")
	g.rng.seed = 12345
	var drops := 0
	for i in 5000:
		if g.should_drop_potion(g.rng.randf()):
			drops += 1
	var rate := drops / 5000.0
	check(rate > 0.18 and rate < 0.22, "~20%% drop rate over 5000 rolls (got %.3f)" % rate)
	g.potion_drop_chance = 0.0
	check(not g.should_drop_potion(0.0), "0% never drops")
	g.potion_drop_chance = 1.0
	check(g.should_drop_potion(0.999), "100% always drops")


func _count_potions(w: Node) -> int:
	var n := 0
	for child in w.get_children():
		if child is PotionPickup:
			n += 1
	return n


func test_enemy_drops_potion() -> void:
	var w := world()
	var g1 := spawn_goblin(w, 300.0)
	g1.potion_drop_chance = 1.0
	g1.take_hit(Hit.new(999.0))
	var g2 := spawn_goblin(w, 600.0)
	g2.potion_drop_chance = 0.0
	g2.take_hit(Hit.new(999.0))
	await frames(2)
	check_eq(_count_potions(w), 1, "exactly one potion from the 100% goblin")


func test_pickup_collect() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(2)
	var potion := POTION_SCENE.instantiate() as PotionPickup
	potion.position = Vector2(0, -12)
	w.add_child(potion)
	await frames(secs(0.6))
	check(not is_instance_valid(potion), "pickup removed")
	check_eq(p.potions.count, 4, "potion added")


func test_pickup_full() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	p.potions.reset(10)
	await frames(2)
	var potion := POTION_SCENE.instantiate() as PotionPickup
	potion.position = Vector2(0, -12)
	w.add_child(potion)
	await frames(secs(0.8))
	check(is_instance_valid(potion), "pickup remains on the ground")
	check_eq(p.potions.count, 10, "still 10")
	set_health(p, 50.0)
	p.potions.use()
	await frames(5)
	check(not is_instance_valid(potion), "collected once there is room")
	check_eq(p.potions.count, 10, "back to 10")


func test_combat_state_enemies() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var cs := p.combat_state
	check(not cs.in_combat, "starts out of combat")
	var g := spawn_goblin(w, 150.0, true)
	await frames(10)
	check(cs.in_combat, "goblin detection starts combat")
	g.take_hit(Hit.new(999.0))
	check(not cs.in_combat, "killing the only engaged enemy ends combat")
	var g2 := spawn_goblin(w, 1500.0)
	check(not cs.in_combat, "distant idle goblin: no combat")
	g2.take_hit(Hit.new(5.0))
	check(cs.in_combat, "damaging an enemy starts combat")
	g2.queue_free()
	await frames(2)
	check(not cs.in_combat, "freed enemy no longer counts")


func test_regen_timing() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	set_health(p, 10.0)
	await frames(secs(2.9))
	check_eq(p.health.current, 10.0, "no healing before 3s")
	check(p.regen.state == HealthRegen.State.PENDING, "pending during delay")
	await frames(secs(0.2))
	check(p.regen.is_active(), "active after 3s")
	check(is_equal_approx(p.regen.rate, 9.0), "rate = 90 missing / 10s = 9 HP/s (got %.3f)" % p.regen.rate)
	await frames(secs(4.9))
	check(absf(p.health.current - 55.0) < 2.0, "about halfway after 5s of regen (got %.2f)" % p.health.current)
	check(p.health.current < 100.0, "not full early")
	await frames(secs(5.3))
	check_eq(p.health.current, 100.0, "full after 10s of regen")
	check(p.regen.state == HealthRegen.State.IDLE, "idle when full")


func test_regen_no_potions() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	set_health(p, 25.0)
	await frames(secs(13.5))
	check_eq(p.health.current, 100.0, "fully healed")
	check_eq(p.potions.count, 3, "no potions consumed")


func test_regen_interrupt() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	set_health(p, 50.0)
	await frames(secs(5.0))  # 2s of regen at 5 HP/s
	var before := p.health.current
	check(before > 55.0 and before < 65.0, "regenerating (got %.2f)" % before)
	p.combat_state.begin_encounter(&"test")
	await frames(1)
	var at_interrupt := p.health.current
	check(not p.regen.is_active(), "regen stops immediately on combat")
	await frames(secs(2.0))
	check_eq(p.health.current, at_interrupt, "no healing during combat; earlier healing kept")
	p.combat_state.end_encounter(&"test")
	await frames(secs(2.9))
	check_eq(p.health.current, at_interrupt, "waits another 3s after combat")
	await frames(secs(0.2))
	check(p.regen.is_active(), "resumes after new delay")
	var expected_rate := (100.0 - at_interrupt) / 10.0
	check(absf(p.regen.rate - expected_rate) < 0.01, "new rate from current health (%.3f vs %.3f)" % [p.regen.rate, expected_rate])
	await frames(secs(10.1))
	check_eq(p.health.current, 100.0, "full 10s after resuming")


func test_regen_with_potion() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	set_health(p, 20.0)
	await frames(secs(4.0))
	check(p.regen.is_active(), "regenerating")
	var rate := p.regen.rate
	check(p.potions.use(), "potion usable during regen")
	check(p.regen.is_active(), "regen continues after potion")
	check_eq(p.regen.rate, rate, "rate unchanged")
	await frames(secs(10.0))
	check_eq(p.health.current, 100.0, "reaches full, never above")


func test_regen_dead() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	p.health.take_damage(500.0)
	await frames(secs(14.0))
	check_eq(p.health.current, 0.0, "no healing while dead")
	check(p.regen.state == HealthRegen.State.IDLE, "regen idle while dead")


func test_regen_boss() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	set_health(p, 40.0)
	p.combat_state.begin_encounter(&"boss", true)
	check(p.combat_state.is_boss_active(), "boss active")
	await frames(secs(15.0))
	check_eq(p.health.current, 40.0, "no regen during boss fight")
	check(p.potions.use(), "potions still usable in boss fight")
	p.combat_state.end_encounter(&"boss")
	await frames(secs(2.9))
	check(not p.regen.is_active(), "still waiting just under 3s after boss")
	await frames(secs(0.2))
	check(p.regen.is_active(), "regen allowed 3s after boss defeat")


func test_respawn_keeps_potions() -> void:
	var w := world()
	var p := spawn_player(w)
	await frames(2)
	p.potions.reset(7)
	p.combat_state.begin_encounter(&"room")
	p.health.take_damage(500.0)
	p.respawn(Vector2(0, -28))
	check_eq(p.potions.count, 7, "unused potions retained")
	check_eq(p.health.current, 100.0, "full health")
	check(not p.combat_state.in_combat, "combat state reset")
	check(p.regen.state == HealthRegen.State.IDLE, "regen reset")


# --- Milestone 3: rooms and lives -------------------------------------------

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

## Source of truth: docs/floor-layouts.md
const FLOOR1_EXITS := {
	"F1-01": ["F1-02"], "F1-02": ["F1-03"], "F1-03": ["F1-04"], "F1-04": ["F1-05"],
	"F1-05": ["F1-U1", "F1-D1"],
	"F1-U1": ["F1-U2"], "F1-U2": ["F1-U3"], "F1-U3": ["F1-06"],
	"F1-D1": ["F1-D2"], "F1-D2": ["F1-D3"], "F1-D3": ["F1-06"],
	"F1-06": ["F1-07"], "F1-07": ["F1-08"], "F1-08": [],
}
const FLOOR2_EXITS := {
	"F2-01": ["F2-02"], "F2-02": ["F2-U1", "F2-M1", "F2-D1"],
	"F2-U1": ["F2-U2"], "F2-M1": ["F2-M2"], "F2-D1": ["F2-D2"],
	"F2-U2": ["F2-U3"], "F2-M2": ["F2-U2"], "F2-D2": ["F2-M2", "F2-D3"],
	"F2-U3": ["F2-U4"], "F2-U4": ["F2-06"], "F2-D3": ["F2-D4"], "F2-D4": ["F2-06"],
	"F2-06": ["F2-07"], "F2-07": ["F2-08"], "F2-08": [],
}
const FLOOR2_TYPES := {
	"F2-01": RoomBase.RoomType.ENTRANCE, "F2-02": RoomBase.RoomType.CHALLENGE,
	"F2-U1": RoomBase.RoomType.COMBAT, "F2-M1": RoomBase.RoomType.SAFE, "F2-D1": RoomBase.RoomType.COMBAT,
	"F2-U2": RoomBase.RoomType.SAFE, "F2-M2": RoomBase.RoomType.COMBAT, "F2-D2": RoomBase.RoomType.CHALLENGE,
	"F2-U3": RoomBase.RoomType.COMBAT, "F2-U4": RoomBase.RoomType.CHALLENGE, "F2-D3": RoomBase.RoomType.COMBAT,
	"F2-D4": RoomBase.RoomType.CHALLENGE, "F2-06": RoomBase.RoomType.SAFE, "F2-07": RoomBase.RoomType.COMBAT,
	"F2-08": RoomBase.RoomType.BOSS,
}
const FLOOR1_TYPES := {
	"F1-01": RoomBase.RoomType.ENTRANCE, "F1-02": RoomBase.RoomType.COMBAT,
	"F1-03": RoomBase.RoomType.SAFE, "F1-04": RoomBase.RoomType.CHALLENGE,
	"F1-05": RoomBase.RoomType.COMBAT, "F1-U1": RoomBase.RoomType.CHALLENGE,
	"F1-U2": RoomBase.RoomType.COMBAT, "F1-U3": RoomBase.RoomType.CHALLENGE,
	"F1-D1": RoomBase.RoomType.SAFE, "F1-D2": RoomBase.RoomType.COMBAT,
	"F1-D3": RoomBase.RoomType.CHALLENGE, "F1-06": RoomBase.RoomType.SAFE,
	"F1-07": RoomBase.RoomType.COMBAT, "F1-08": RoomBase.RoomType.BOSS,
}


func spawn_main() -> Node:
	GameManager.reset_lives()
	GameManager.floor_number = 1
	var m := MAIN_SCENE.instantiate()
	m.name = "TestWorldMain"
	m.set("debug_keys", false)
	m.set("navigate", false)
	add_child(m)
	var p: Player = m.get("player")
	p.read_input = false
	p.combat.read_input = false
	use_default_variants(m)
	# No sponsor events unless a test asks for them.
	var none: Array[StringName] = []
	m.set_modifiers(none, false)
	return m


## Tests expect each room's original layout unless they pick a variant.
func use_default_variants(m: Node) -> void:
	var rm := rooms_of(m)
	for id: String in rm.room_variants:
		rm.room_variants[id] = FloorData.room_scene_path(rm.floor_number, id)


func rooms_of(m: Node) -> RoomManager:
	return m.get("room_manager")


func player_of(m: Node) -> Player:
	return m.get("player")


func kill_required(room: RoomBase) -> void:
	for enemy in room.required_enemies.duplicate():
		enemy.take_hit(Hit.new(999.0))


func test_floor1_graph() -> void:
	await _check_floor_graph(1, "F1-01", FLOOR1_EXITS, FLOOR1_TYPES)


func _check_floor_graph(floor_number: int, start: String, exits: Dictionary, types: Dictionary) -> void:
	var ids := FloorData.room_ids(floor_number)
	check_eq(ids.size(), exits.size(), "room count")
	check_eq(FloorData.start_room(floor_number), start, "floor starts at the entrance")
	var w := world()
	for id: String in exits:
		check(FloorData.has_room(floor_number, id), "%s registered" % id)
		for path: String in FloorData.room_scene_paths(floor_number, id):
			_check_room_scene(w, floor_number, id, path, exits, types)
	# Every room is reachable from the entrance by following exits.
	_check_graph_connected(start, exits)


func _check_room_scene(w: Node2D, floor_number: int, id: String, path: String, exits: Dictionary, types: Dictionary) -> void:
	var room := (load(path) as PackedScene).instantiate() as RoomBase
	w.add_child(room)
	check_eq(room.room_id, id, "scene room_id")
	check_eq(room.room_type, types[id], "%s type" % id)
	check_eq(Array(room.exits), exits[id], "%s exits" % id)
	check_eq(room.doors.size(), room.exits.size(), "%s has one door per exit" % id)
	check(room.get_spawn_point() != room.global_position, "%s has an entrance" % id)
	for target in room.exits:
		check(FloorData.has_room(floor_number, target), "%s -> %s exists" % [id, target])
	room.queue_free()


func _check_graph_connected(start: String, exits: Dictionary) -> void:
	var seen := {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		for target: String in exits[queue.pop_front()]:
			if not seen.has(target):
				seen[target] = true
				queue.append(target)
	check_eq(seen.size(), exits.size(), "every room reachable through doors")


func test_room_transition() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	check_eq(rm.current_room_id, "F1-01", "starts at entrance")
	check(not rm.request_exit(3), "invalid exit index rejected")
	check(rm.request_exit(0), "valid exit accepted")
	check(not rm.request_exit(0), "no second transition while one is running")
	while rm.transitioning:
		await get_tree().process_frame
	check_eq(rm.current_room_id, "F1-02", "arrived in F1-02")
	check(p.global_position.distance_to(rm.current_room.get_spawn_point()) < 2.0, "placed at the entrance")
	rm.load_room("F1-05")
	rm.request_exit(1)
	while rm.transitioning:
		await get_tree().process_frame
	check_eq(rm.current_room_id, "F1-D1", "F1-05 exit 2 leads to the low road")


func test_combat_room_locking() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	var room := rm.load_room("F1-02")
	check(room.encounter_active, "encounter active on entry")
	check(room.doors.all(func(d: Door) -> bool: return d.locked), "exits locked")
	check(p.combat_state.in_combat, "combat state active")
	kill_required(room)
	check(not room.encounter_active, "encounter over")
	check(room.doors.all(func(d: Door) -> bool: return not d.locked), "exits unlocked")
	check(not p.combat_state.in_combat, "combat ended")
	check(room.is_cleared(), "room marked cleared")
	check(rm.room_states["F1-02"].get("cleared", false), "manager stored cleared state")


func test_cleared_room_stays_cleared() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	kill_required(rm.load_room("F1-02"))
	rm.load_room("F1-03")
	var again := rm.load_room("F1-02")
	await frames(2)
	check(again.is_cleared(), "still cleared")
	check_eq(again.required_enemies.size(), 0, "no enemies respawned")
	check(again.doors.all(func(d: Door) -> bool: return not d.locked), "exits open")
	check(not p.combat_state.in_combat, "no combat on revisit")


func test_death_resets_room() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	var room := rm.load_room("F1-02")
	room.required_enemies[0].take_hit(Hit.new(999.0))
	p.potions.reset(5)
	p.health.take_damage(500.0)
	check_eq(GameManager.lives, 2, "exactly one life lost")
	await frames(secs(1.7))
	var fresh := rm.current_room
	check_eq(rm.current_room_id, "F1-02", "restarted the same room")
	check(fresh != room, "room was reloaded")
	check_eq(fresh.required_enemies.size(), 2, "encounter reset: both goblins back")
	check(fresh.doors.all(func(d: Door) -> bool: return d.locked), "exits locked again")
	check(not p.health.is_dead, "alive")
	check_eq(p.health.current, 100.0, "full health")
	check_eq(p.potions.count, 5, "potions kept")
	check(p.combat_state.in_combat, "encounter re-activated")
	check(p.global_position.distance_to(fresh.get_spawn_point()) < 2.0, "at the room entrance")


func test_death_keeps_floor_progress() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	kill_required(rm.load_room("F1-02"))
	rm.load_room("F1-03")
	p.health.take_damage(500.0)
	await frames(secs(1.7))
	check_eq(GameManager.lives, 2, "one life lost")
	check(rm.room_states["F1-02"].get("cleared", false), "F1-02 still cleared")


func test_game_over_restart() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	kill_required(rm.load_room("F1-02"))
	rm.load_room("F1-05")
	GameManager.lives = 1
	p.potions.reset(7)
	p.health.take_damage(500.0)
	await frames(secs(1.7))
	var screen: GameOverScreen = m.get("game_over")
	check(screen.visible, "game over shown")
	check(get_tree().paused, "game paused")
	screen._on_restart()
	await frames(2)
	check(not get_tree().paused, "unpaused")
	check(not screen.visible, "screen hidden")
	check_eq(GameManager.lives, 3, "lives restored")
	check_eq(p.potions.count, 3, "potions reset to 3")
	check_eq(p.health.current, 100.0, "full health")
	check_eq(rm.current_room_id, "F1-01", "back at floor entrance")
	check(not rm.room_states.has("F1-02"), "room progress reset")


func test_pit_fall() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	var room := rm.load_room("F1-U3")
	p.global_position = Vector2(11.5 * 32, 15 * 32)
	await frames(secs(1.0))
	check_eq(p.health.current, 80.0, "20 fall damage")
	check(p.global_position.distance_to(room.get_spawn_point()) < 40.0, "back at the entrance")


func test_switch_trial() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var room := rm.load_room("F1-U1")
	check_eq(room.switches.size(), 3, "three switches")
	check(room.chest.locked, "chest locked")
	check(not room.chest.interact(), "locked chest does nothing")
	check(not room.doors[0].locked, "exit is not locked in challenge rooms")
	room.switches[0].take_hit(Hit.new(10.0))
	room.switches[1].take_hit(Hit.new(10.0))
	check(not room.is_trial_done(), "two of three is not enough")
	room.switches[2].take_hit(Hit.new(10.0))
	check(room.is_trial_done(), "trial complete")
	check(not room.chest.locked, "chest unlocked")
	check(room.chest.interact(), "chest opens")
	check(room.state.get("reward_claimed", false), "reward claimed")
	await frames(2)
	rm.load_room("F1-U2")
	var again := rm.load_room("F1-U1")
	check(again.chest.is_open, "chest stays open")
	check(again.switches.all(func(s: FloorSwitch) -> bool: return s.is_on), "switches stay on")
	check_eq(again._gates.size(), 0, "gate stays open")


func test_defeat_trial() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var room := rm.load_room("F1-D3")
	check_eq(room.required_enemies.size(), 3, "three guards")
	check(room.chest.locked, "chest locked")
	kill_required(room)
	check(room.is_trial_done(), "trial complete")
	check(not room.chest.locked, "chest unlocked")


func test_reach_trial() -> void:
	var m := spawn_main()
	var room := rooms_of(m).load_room("F1-04")
	check(room.chest != null and not room.chest.locked, "chest unlocked")
	check(room.chest.interact(), "chest opens")


func test_fountain() -> void:
	var m := spawn_main()
	var rm := rooms_of(m)
	var p := player_of(m)
	var room := rm.load_room("F1-03")
	check(not room.fountain.interact(), "no use at full health")
	set_health(p, 40.0)
	check(room.fountain.interact(), "fountain used")
	check_eq(p.health.current, 100.0, "healed to full")
	set_health(p, 50.0)
	check(not room.fountain.interact(), "only once")
	rm.load_room("F1-04")
	check(rm.load_room("F1-03").fountain.dry, "stays dry on revisit")
	check_eq(p.potions.count, 3, "fountain does not use potions")


func test_jump_clears_three_tiles() -> void:
	var w := world()
	var ledge := SolidBlock.new()
	ledge.position = Vector2(48, -96)
	ledge.size = Vector2(200, 96)
	w.add_child(ledge)
	var p := spawn_player(w, 0.0)
	p.read_input = true
	await frames(3)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(secs(0.8))
	Input.action_release("jump")
	Input.action_release("move_right")
	await frames(secs(0.3))
	check(p.is_on_floor() and p.global_position.y < -96.0, "landed on top of the ledge (y=%.1f)" % p.global_position.y)


# Reachability check over each room's text map, using the movement rules the
# rooms are designed around: the player is 2 tiles tall, a jump rises at most
# MAX_RISE tiles, one-way platforms can be jumped through from below, and
# falling out of the map is not allowed. Horizontal reach comes from the
# movement values (260 px/s run, ~0.74s airtime for a flat jump): about 5
# tiles for low jumps, 4 when landing at full height.
const MAX_RISE := 3


func _max_span(rise: int) -> int:
	return 5 if rise <= 2 else 4


func _cell(rows: PackedStringArray, r: int, c: int) -> String:
	if r < 0 or r >= rows.size() or c < 0 or c >= rows[r].length():
		return "#"
	return rows[r][c]


func _blocks(ch: String, gates_open: bool) -> bool:
	return ch == "#" or ch == "W" or (ch == "G" and not gates_open)


func _supports(ch: String, gates_open: bool) -> bool:
	return _blocks(ch, gates_open) or ch == "="


## Standing at (r, c): body occupies rows r and r-1, feet rest on row r+1.
func _can_stand(rows: PackedStringArray, r: int, c: int, gates_open: bool) -> bool:
	return not _blocks(_cell(rows, r, c), gates_open) and not _blocks(_cell(rows, r - 1, c), gates_open) \
		and _supports(_cell(rows, r + 1, c), gates_open) and _cell(rows, r, c) != "^"


## From a non-supported cell, fall straight down. Returns -1 if it falls out.
func _land(rows: PackedStringArray, r: int, c: int, gates_open: bool) -> int:
	while r < rows.size():
		if _blocks(_cell(rows, r, c), gates_open):
			return -1
		if _supports(_cell(rows, r + 1, c), gates_open) and r + 1 < rows.size():
			return r
		r += 1
	return -1


func _reachable(rows: PackedStringArray, start: Vector2i, gates_open: bool) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		var r := at.x
		var c := at.y
		var next: Array[Vector2i] = []
		# Walk (and possibly fall) one tile sideways.
		for dc in [-1, 1]:
			var nc: int = c + dc
			if _blocks(_cell(rows, r, nc), gates_open) or _blocks(_cell(rows, r - 1, nc), gates_open):
				continue
			var lr := _land(rows, r, nc, gates_open)
			if lr >= 0:
				next.append(Vector2i(lr, nc))
		# Jump: rise up to MAX_RISE rows (headroom clear above the start), then
		# drift up to MAX_SPAN columns at that height and land.
		for rise in range(1, MAX_RISE + 1):
			var top := r - rise
			if _blocks(_cell(rows, top - 1, c), gates_open):
				break
			var span := _max_span(rise)
			for dc in range(-span, span + 1):
				var nc := c + dc
				var clear := true
				var step := 1 if dc >= 0 else -1
				for x in range(c, nc + step, step):
					if _blocks(_cell(rows, top, x), gates_open) or _blocks(_cell(rows, top - 1, x), gates_open):
						clear = false
						break
				if not clear:
					continue
				var lr := _land(rows, top, nc, gates_open)
				if lr >= 0:
					next.append(Vector2i(lr, nc))
		for n in next:
			if not seen.has(n) and _can_stand(rows, n.x, n.y, gates_open):
				seen[n] = true
				queue.append(n)
	return seen


func test_rooms_reachable() -> void:
	for floor_number in [1, 2]:
		_check_floor_reachable(floor_number)


func _check_floor_reachable(floor_number: int) -> void:
	for id: String in FloorData.room_ids(floor_number):
		for path: String in FloorData.room_scene_paths(floor_number, id):
			_check_room_reachable(path, id)


func _check_room_reachable(path: String, id: String) -> void:
	var room := (load(path) as PackedScene).instantiate() as RoomBase
	var rows: PackedStringArray = []
	for line in room.layout.strip_edges().split("\n"):
		rows.append(line.strip_edges())
	room.free()
	var start := Vector2i(-1, -1)
	for r in rows.size():
		var c := rows[r].find("E")
		if c >= 0:
			start = Vector2i(r, c)
	var before_gates := _reachable(rows, start, false)
	var after_gates := _reachable(rows, start, true)
	for r in rows.size():
		for c in rows[r].length():
			var ch := rows[r][c]
			# Every one-way platform must be standable-on from the entrance
			# (checked on the cell above it), even with nothing on it.
			if ch == "=" and _can_stand(rows, r - 1, c, true):
				check(after_gates.has(Vector2i(r - 1, c)), "%s: platform at row %d col %d is out of reach" % [id, r, c])
				continue
			# Ground enemies must be reachable; bats (v) fly to you.
			var target := ch in ["C", "S", "F", "g", "s", "h", "a", "?", "B", "X"] or (ch >= "1" and ch <= "9")
			if not target:
				continue
			# Chests may sit behind a trial gate; everything else must be
			# reachable with gates closed.
			var reach := after_gates if ch == "C" else before_gates
			check(reach.has(Vector2i(r, c)), "%s: '%s' at row %d col %d is unreachable" % [id, ch, r, c])


func test_jump_crosses_pit() -> void:
	var w := Node2D.new()
	w.name = "TestWorld"
	add_child(w)
	var left := SolidBlock.new()
	left.position = Vector2(-400, 0)
	left.size = Vector2(400, 40)
	w.add_child(left)
	var right := SolidBlock.new()
	right.position = Vector2(128, 0)  # 4-tile (128px) gap
	right.size = Vector2(400, 40)
	w.add_child(right)
	var p := spawn_player(w, -200.0)
	p.read_input = true
	await frames(3)
	Input.action_press("move_right")
	# Jump from the last tile before the gap.
	while p.global_position.x < -20.0:
		await get_tree().physics_frame
	Input.action_press("jump")
	await frames(secs(0.9))
	Input.action_release("jump")
	Input.action_release("move_right")
	await frames(secs(0.3))
	check(p.is_on_floor() and p.global_position.x > 128.0 and p.global_position.y < 0.0,
		"landed across the pit (x=%.1f, y=%.1f)" % [p.global_position.x, p.global_position.y])


# --- Milestone 4: Donut combat -----------------------------------------------

func bolts() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group(MagicProjectile.GROUP):
		if not b.is_queued_for_deletion():
			n += 1
	return n


func test_mode_switch_instant() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(10)
	var pos := p.global_position
	var hp := p.health.current
	var changes := [0]
	p.combat.mode_changed.connect(func(_m: PlayerCombat.Mode) -> void: changes[0] += 1)
	check_eq(p.combat.mode, PlayerCombat.Mode.CARL, "starts in Carl mode")
	check(p.combat.request_switch(), "switch is immediate")
	check_eq(p.combat.mode, PlayerCombat.Mode.DONUT, "now Donut mode")
	check_eq(p.global_position, pos, "position unchanged")
	check_eq(p.health.current, hp, "health unchanged")
	check_eq(p.potions.count, 3, "no resources consumed")
	check_eq(changes[0], 1, "mode_changed emitted once")
	check(p.combat.request_switch(), "switch back")
	check_eq(p.combat.mode, PlayerCombat.Mode.CARL, "back to Carl")


func test_switch_keeps_movement() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(10)
	p.read_input = true
	var dist: Array[float] = []
	for i in 2:
		p.global_position = Vector2(0, -28)
		p.velocity = Vector2.ZERO
		await frames(2)
		var x0 := p.global_position.x
		Input.action_press("move_right")
		await frames(30)
		Input.action_release("move_right")
		dist.append(p.global_position.x - x0)
		p.combat.request_switch()
	p.read_input = false
	check(dist[0] > 100.0, "player ran (%.1f px)" % dist[0])
	check(absf(dist[0] - dist[1]) < 0.5, "same distance in Carl and Donut mode (%.1f vs %.1f)" % [dist[0], dist[1]])


func test_switch_queued_during_windup() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	p.combat.kick_combo.press()
	await frames(1)
	check(p.combat.is_busy(), "kick is in its windup")
	check(not p.combat.request_switch(), "switch is queued, not immediate")
	check_eq(p.combat.mode, PlayerCombat.Mode.CARL, "still Carl during the windup")
	await frames(8)
	check_eq(g.health, 40.0, "the kick still landed")
	check_eq(p.combat.mode, PlayerCombat.Mode.DONUT, "switched once the kick fired")
	check(not p.combat.switch_queued, "queue cleared")


func test_magic_missile() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 200.0)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(5)
	check_eq(bolts(), 1, "one bolt in flight")
	check_eq(g.health, 50.0, "not hit yet (it travels)")
	await frames(30)
	check_eq(g.health, 38.0, "missile deals 12")
	check(g.global_position.x > 200.0, "knocked away from the player (x=%.1f)" % g.global_position.x)
	check(g.is_engaged, "hitting an enemy engages it")
	check(p.combat_state.in_combat, "damaging an enemy starts combat")
	check_eq(bolts(), 0, "bolt is gone after hitting")
	check(p.combat.magic_missile.cooldown_remaining <= 0.0, "short cooldown is over")


func test_missile_range() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 460.0)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(70)
	check_eq(g.health, 50.0, "goblin beyond max range untouched")
	check_eq(bolts(), 0, "bolt fizzled out")


func test_missile_facing_left() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var right := spawn_goblin(w, 150.0)
	var left := spawn_goblin(w, -150.0)
	await frames(5)
	p.facing = -1
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(30)
	check_eq(left.health, 38.0, "goblin on the left hit")
	check_eq(right.health, 50.0, "goblin behind untouched")
	check(left.global_position.x < -150.0, "knocked left")


func test_charged_blast_scaling() -> void:
	var w := world()
	var p := spawn_player(w)
	var cb := p.combat.charged_blast
	check_eq(cb.damage_for_ratio(0.0), 18.0, "min damage")
	check_eq(cb.damage_for_ratio(1.0), 35.0, "max damage")
	check_eq(cb.damage_for_ratio(3.0), 35.0, "clamped above")
	check(cb.radius_for_ratio(1.0) > cb.radius_for_ratio(0.0), "bolt grows with charge")
	check(cb.radius_for_ratio(0.0) > p.combat.magic_missile.radius, "bigger than the basic missile")
	check(cb.knockback_for_ratio(1.0).x > cb.knockback_for_ratio(0.0).x, "knockback grows with charge")


func test_charged_blast_full() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 200.0)
	var g2 := spawn_goblin(w, -200.0)
	await frames(5)
	p.combat.request_switch()
	var cb := p.combat.charged_blast
	cb.press()
	await frames(70)
	check_eq(cb.charge_ratio(), 1.0, "fully charged after 1s")
	cb.release()
	await frames(35)
	check_eq(g.health, 15.0, "full blast deals 35")
	check(cb.cooldown_remaining > 0.0, "cooldown running")
	cb.press()
	check(not cb.is_charging(), "cannot charge during cooldown")
	await frames(50)
	p.facing = -1
	cb.press()
	check(cb.is_charging(), "charging again after the cooldown")
	cb.release()
	await frames(35)
	check_eq(g2.health, 32.0, "uncharged blast deals 18")


func test_cooldowns_survive_switch() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(5)
	var ck := p.combat.charged_kick
	var mm := p.combat.magic_missile
	ck.press()
	await frames(5)
	ck.release()
	await frames(10)  # kick has landed and is recovering
	var before := ck.cooldown_remaining
	check(before > 0.0, "power kick cooldown started when it landed")
	check(p.combat.request_switch(), "switch during recovery is immediate")
	check_eq(ck.cooldown_remaining, before, "switching keeps Carl's cooldown")
	mm.press()
	await frames(6)
	check(mm.cooldown_remaining > 0.0, "missile fired and is cooling down")
	var missile_cd := mm.cooldown_remaining
	p.combat.request_switch()
	check_eq(mm.cooldown_remaining, missile_cd, "switching keeps Donut's cooldown")
	check(ck.cooldown_remaining > 0.0 and ck.cooldown_remaining < before, "Carl's cooldown kept ticking in Donut mode")
	ck.press()
	check(not ck.is_charging(), "power kick still on cooldown after switching back")


func test_projectile_after_switch() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 250.0)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(5)
	check_eq(bolts(), 1, "bolt in flight")
	p.combat.request_switch()
	check_eq(p.combat.mode, PlayerCombat.Mode.CARL, "back in Carl mode")
	check_eq(bolts(), 1, "bolt still flying")
	await frames(30)
	check_eq(g.health, 38.0, "bolt still hit after the switch")


func test_switch_cancels_charge() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(5)
	p.combat.request_switch()
	var cb := p.combat.charged_blast
	cb.press()
	await frames(20)
	check(cb.is_charging(), "charging")
	check(p.combat.request_switch(), "switching mid-charge is immediate")
	check(not cb.is_charging(), "charge dropped")
	await frames(5)
	check_eq(bolts(), 0, "nothing fired")
	check_eq(cb.cooldown_remaining, 0.0, "no cooldown for a cancelled charge")


func test_projectile_walls() -> void:
	var w := world()
	var wall := SolidBlock.new()
	wall.size = Vector2(32, 200)
	wall.position = Vector2(100, -200)
	w.add_child(wall)
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 200.0)
	var plat := SolidBlock.new()
	plat.size = Vector2(32, 200)
	plat.one_way = true
	plat.position = Vector2(1100, -200)
	w.add_child(plat)
	var p2 := spawn_player(w, 1000.0)
	var g2 := spawn_goblin(w, 1200.0)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	p2.combat.request_switch()
	p2.combat.magic_missile.press()
	await frames(40)
	check_eq(g.health, 50.0, "solid wall blocked the bolt")
	check_eq(g2.health, 38.0, "bolt passed through the one-way platform")
	check_eq(bolts(), 0, "both bolts gone")


func test_projectile_hits_switch() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var sw := FloorSwitch.new()
	sw.position = Vector2(150, 0)
	w.add_child(sw)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(25)
	check(sw.is_on, "switch activated by a bolt")


func test_dead_cannot_switch() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(2)
	p.health.take_damage(1000.0)
	check(not p.combat.request_switch(), "switch refused while dead")
	check_eq(p.combat.mode, PlayerCombat.Mode.CARL, "mode unchanged")


func test_projectiles_cleared_on_room_change() -> void:
	var m := spawn_main()
	var p := player_of(m)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(5)
	check_eq(bolts(), 1, "bolt in flight")
	rooms_of(m).load_room("F1-02")
	check_eq(bolts(), 0, "bolt removed with the old room")
	check_eq(p.combat.mode, PlayerCombat.Mode.DONUT, "mode kept across rooms")


# --- Milestone 5: Goblin Brute -------------------------------------------------

func spawn_boss(w: Node2D, x: float, attack := -1) -> GoblinBoss:
	var b := BOSS_SCENE.instantiate() as GoblinBoss
	b.position = Vector2(x, -36)
	b.forced_attack = attack
	b.rng.seed = 7
	w.add_child(b)
	return b


## Waits until cond() is true (or max_frames pass). Returns whether it became true.
func until(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


## Starts the fight and waits for the intro roar to finish.
func wake(b: GoblinBoss) -> void:
	b.start_fight()
	await until(func() -> bool: return b.state != GoblinBoss.State.INTRO)


func test_boss_dormant_and_immune() -> void:
	var w := world()
	spawn_player(w, 0.0)
	var b := spawn_boss(w, 400.0)
	await frames(30)
	check_eq(b.state, GoblinBoss.State.DORMANT, "waits while dormant")
	b.take_hit(Hit.new(50.0))
	check_eq(b.health, 360.0, "immune while dormant")
	b.start_fight()
	check_eq(b.state, GoblinBoss.State.INTRO, "roars first")
	b.take_hit(Hit.new(50.0))
	check_eq(b.health, 360.0, "immune during the intro")
	check(b.is_engaged, "engaged once the fight starts")
	await wake(b)
	b.take_hit(Hit.new(10.0))
	check_eq(b.health, 350.0, "takes damage once the fight is on")
	await frames(10)
	check(b.global_position.x < 395.0, "walks toward the player (x=%.0f)" % b.global_position.x)


func test_boss_swing() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 80.0, GoblinBoss.Attack.SWING)
	await wake(b)
	check(await until(func() -> bool: return b.is_telegraphing()), "swing telegraph shown")
	check_eq(b.attack, GoblinBoss.Attack.SWING, "telegraphing the swing")
	check_eq(p.health.current, 100.0, "no damage during the telegraph")
	await until(func() -> bool: return b.state == GoblinBoss.State.ACTIVE)
	check_eq(p.health.current, 78.0, "swing deals 22")
	check(p.velocity.x < 0.0, "knocked away from the boss")


func test_boss_swing_dodged() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 80.0, GoblinBoss.Attack.SWING)
	await wake(b)
	await until(func() -> bool: return b.is_telegraphing() and b._t <= 0.05)
	check(p.try_dodge(1.0), "dodge through the boss")
	await until(func() -> bool: return b.state != GoblinBoss.State.TELEGRAPH)
	await frames(2)
	check_eq(p.health.current, 100.0, "dodge i-frames avoid the swing")


func test_boss_slam_hits() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 250.0, GoblinBoss.Attack.SLAM)
	b.swing_range = 0.0  # don't walk in
	b.approach_speed = 0.0
	await wake(b)
	check(await until(func() -> bool: return b.is_telegraphing()), "slam telegraph shown")
	await until(func() -> bool: return b.state == GoblinBoss.State.ACTIVE)
	check_eq(p.health.current, 100.0, "shockwave still travelling")
	await frames(40)
	check_eq(p.health.current, 85.0, "shockwave deals 15")


func test_boss_slam_avoided() -> void:
	var w := world()
	var plat := SolidBlock.new()
	plat.one_way = true
	plat.size = Vector2(120, 12)
	plat.position = Vector2(-60, -96)
	w.add_child(plat)
	var high := spawn_player(w, 0.0)
	high.position = Vector2(0, -96 - 29)
	var jumper := spawn_player(w, 600.0)
	var b := spawn_boss(w, 300.0, GoblinBoss.Attack.SLAM)
	b.swing_range = 0.0
	b.approach_speed = 0.0
	await frames(5)
	check(high.is_on_floor() and high.global_position.y < -100.0, "player standing on the platform")
	await wake(b)
	await until(func() -> bool: return b.state == GoblinBoss.State.ACTIVE)
	var jumped := [false]
	for i in 90:
		var waves := w.find_children("*", "Shockwave", true, false)
		for wave: Shockwave in waves:
			if wave.direction == 1 and not jumped[0] and jumper.global_position.x - wave.global_position.x < 70.0:
				jumper.velocity.y = jumper.jump_velocity
				jumped[0] = true
		await get_tree().physics_frame
	check(jumped[0], "jumped as the wave arrived")
	check_eq(high.health.current, 100.0, "platform is above the shockwave")
	check_eq(jumper.health.current, 100.0, "jumping clears the shockwave")


func test_boss_wave_range() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 420.0, GoblinBoss.Attack.SLAM)
	b.swing_range = 0.0
	b.approach_speed = 0.0
	await wake(b)
	await until(func() -> bool: return b.state == GoblinBoss.State.RECOVER)
	await frames(90)
	check_eq(p.health.current, 100.0, "phase 1 wave stops short at 420px")
	b.health = 200.0
	b.take_hit(Hit.new(30.0))
	check_eq(b.phase, 2, "phase 2")
	await until(func() -> bool: return b.state == GoblinBoss.State.ACTIVE)
	await frames(90)
	check_eq(p.health.current, 85.0, "phase 2 wave reaches 420px")


func test_boss_charge() -> void:
	var w := world()
	var wall := SolidBlock.new()
	wall.size = Vector2(32, 300)
	wall.position = Vector2(-32, -300)
	w.add_child(wall)
	var p := spawn_player(w, 200.0)
	var b := spawn_boss(w, 560.0, GoblinBoss.Attack.CHARGE)
	b.swing_range = 0.0
	b.approach_speed = 0.0
	await wake(b)
	check(await until(func() -> bool: return b.is_telegraphing()), "charge telegraph shown")
	check_eq(b.facing, -1, "aimed at the player")
	check_eq(p.health.current, 100.0, "no damage while telegraphing")
	await until(func() -> bool: return b.state == GoblinBoss.State.CHARGING)
	check(await until(func() -> bool: return b.state == GoblinBoss.State.STUNNED, 120), "dazed after hitting the wall")
	check_eq(p.health.current, 80.0, "charge deals 20 once")
	check(b.global_position.x < 100.0, "rushed across the room (x=%.0f)" % b.global_position.x)


func test_boss_recovery() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 80.0, GoblinBoss.Attack.SWING)
	check_eq(b.recovery_time(), 1.1, "phase 1 recovery")
	await wake(b)
	await until(func() -> bool: return b.state == GoblinBoss.State.RECOVER)
	var hp := p.health.current
	p.health._invuln = 0.0
	await frames(secs(0.9))
	check_eq(b.state, GoblinBoss.State.RECOVER, "still recovering 0.9s later")
	check_eq(p.health.current, hp, "no attacks during recovery")
	b.phase = 2
	check(b.recovery_time() < 0.7, "phase 2 recovers faster")


func test_boss_phase_two() -> void:
	var w := world()
	spawn_player(w, 0.0)
	var b := spawn_boss(w, 300.0)
	var phases: Array[int] = []
	b.phase_changed.connect(func(ph: int) -> void: phases.append(ph))
	var t1 := b.telegraph_time(GoblinBoss.Attack.SLAM)
	var r1 := b.current_wave_range()
	await wake(b)
	b.take_hit(Hit.new(170.0))
	check_eq(b.phase, 1, "still phase 1 above 50%")
	b.take_hit(Hit.new(10.0))
	check_eq(b.phase, 2, "phase 2 at 50%")
	check_eq(phases, [2] as Array[int], "phase_changed emitted once")
	check_eq(b.state, GoblinBoss.State.TRANSITION, "roars into phase 2")
	b.take_hit(Hit.new(20.0))
	check_eq(b.health, 180.0, "immune during the phase change")
	check(b.telegraph_time(GoblinBoss.Attack.SLAM) < t1, "faster telegraphs")
	check(b.current_wave_range() > r1, "longer shockwaves")
	await until(func() -> bool: return b.state != GoblinBoss.State.TRANSITION)
	b.take_hit(Hit.new(20.0))
	check_eq(b.health, 160.0, "vulnerable again after the roar")


func test_boss_chain() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 80.0, GoblinBoss.Attack.SWING)
	b.phase2_chain_chance = 1.0
	await wake(b)
	b.phase = 2
	await until(func() -> bool: return b.state == GoblinBoss.State.ACTIVE)
	await until(func() -> bool: return b.state != GoblinBoss.State.ACTIVE)
	check_eq(b.state, GoblinBoss.State.TELEGRAPH, "chained straight into another telegraph")
	await until(func() -> bool: return b.state == GoblinBoss.State.ACTIVE)
	await until(func() -> bool: return b.state != GoblinBoss.State.ACTIVE)
	check_eq(b.state, GoblinBoss.State.RECOVER, "recovers after the chain")
	check(p.health.current < 100.0, "chain still telegraphed and hit")


func test_boss_no_triple() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 80.0)
	await frames(2)
	var ok := true
	for i in 300:
		b._begin_attack(b._pick_attack(p))
		var h := b._history
		if h.size() >= 3 and h[-1] == h[-2] and h[-2] == h[-3]:
			ok = false
	check(ok, "no attack repeated three times in a row")


func test_boss_dead_no_attack() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_boss(w, 80.0, GoblinBoss.Attack.SLAM)
	await wake(b)
	await until(func() -> bool: return b.is_telegraphing())
	b.take_hit(Hit.new(999.0))
	check(b.is_dead, "boss died mid-telegraph")
	await frames(60)
	check_eq(p.health.current, 100.0, "no attack after death")
	check_eq(w.find_children("*", "Shockwave", true, false).size(), 0, "no shockwave spawned")


func test_boss_drops_potions() -> void:
	var w := world()
	spawn_player(w, -300.0)
	var b := spawn_boss(w, 200.0)
	await wake(b)
	b.take_hit(Hit.new(999.0))
	await frames(3)
	check_eq(_count_potions(w), 2, "two guaranteed potions")


func _boss_room(m: Node) -> RoomBase:
	return rooms_of(m).load_room("F1-08")


func test_boss_room_flow() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var hud: HUD = m.get("hud")
	var room := _boss_room(m)
	check(room.boss != null, "boss spawned")
	await frames(10)
	check_eq(room.boss.state, GoblinBoss.State.DORMANT, "dormant while the player is at the entrance")
	check(not p.combat_state.is_boss_active(), "no boss encounter yet")
	check(not hud.is_boss_bar_visible(), "no boss bar yet")
	check(not room.floor_exit.open, "stairs closed")
	p.global_position.x = room.boss.global_position.x - 300.0
	await frames(3)
	check(room.encounter_active, "fight starts when the player walks in")
	check(p.combat_state.is_boss_active(), "boss encounter active")
	check(hud.is_boss_bar_visible(), "boss bar shown")
	var boss := room.boss
	await wake(boss)
	p.health.take_damage(30.0)
	boss.take_hit(Hit.new(999.0))
	check(boss.is_dead, "boss defeated")
	check(not p.combat_state.is_boss_active(), "boss encounter over")
	check(not p.combat_state.in_combat, "combat ends with the boss")
	check(room.is_cleared(), "room cleared")
	check(room.floor_exit.open, "stairs open")
	check(GameManager.is_floor_completed(1), "floor 1 completed")
	check(GameManager.highest_unlocked_floor >= 2, "floor 2 unlocked")
	await frames(secs(3.2))
	check(p.regen.is_active(), "auto-heal resumes 3s after the boss dies")
	await frames(secs(0.5))
	check(not hud.is_boss_bar_visible(), "boss bar hidden after victory")


func test_boss_death_resets() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var room := _boss_room(m)
	p.global_position.x = room.boss.global_position.x - 300.0
	await frames(3)
	await wake(room.boss)
	room.boss.take_hit(Hit.new(100.0))
	p.health.take_damage(999.0, true)
	await frames(secs(1.7))
	var fresh := rooms_of(m).current_room
	check(fresh != room, "boss room reloaded")
	check_eq(GameManager.lives, 2, "one life lost")
	check_eq(fresh.boss.health, 360.0, "boss back to full health")
	check_eq(fresh.boss.state, GoblinBoss.State.DORMANT, "boss waits again")
	check(not p.combat_state.is_boss_active(), "encounter reset")


func test_floor_complete() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var screen: FloorCompleteScreen = m.get("floor_complete")
	var room := _boss_room(m)
	p.global_position.x = room.boss.global_position.x - 300.0
	await frames(3)
	await wake(room.boss)
	room.boss.take_hit(Hit.new(999.0))
	p.potions.count = 5
	p.global_position = room.floor_exit.global_position + Vector2(0, -30)
	await frames(3)
	check(screen.visible, "Floor Complete screen shown")
	check(get_tree().paused, "game paused")
	check((screen.get_node("%ContinueButton") as Button).visible, "Continue to Floor 2 offered")
	(screen.get_node("%ReplayButton") as Button).pressed.emit()
	await frames(2)
	check(not screen.visible, "screen closed")
	check(not get_tree().paused, "unpaused")
	check_eq(rooms_of(m).current_room_id, "F1-01", "back at the entrance")
	check_eq(GameManager.lives, 3, "3 lives")
	check_eq(p.potions.count, 3, "potions reset to 3")
	check(not rooms_of(m).room_states.has("F1-08"), "room progress reset")


# --- Milestone 6: progression and environmental combat --------------------------

const UP_KICK := preload("res://resources/upgrades/KickDamage.tres")
const UP_MAGIC := preload("res://resources/upgrades/MagicDamage.tres")
const UP_KNOCKBACK := preload("res://resources/upgrades/Knockback.tres")
const UP_COOLDOWN := preload("res://resources/upgrades/Cooldown.tres")
const UP_HEALTH := preload("res://resources/upgrades/MaxHealth.tres")
const UP_SPEED := preload("res://resources/upgrades/MoveSpeed.tres")


func test_specials_locked() -> void:
	GameManager.reset_progress()
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(2)
	check(not p.combat.press_special(), "explosive kick locked")
	check(not p.combat.explosive_kick.is_active(), "nothing happened")
	p.combat.request_switch()
	check(not p.combat.press_special(), "magic burst locked")
	check(not p.combat.area_burst.is_active(), "nothing happened")


func test_explosive_kick() -> void:
	GameManager.reset_progress()
	GameManager.unlock_ability(GameManager.EXPLOSIVE_KICK)
	var w := world()
	var p := spawn_player(w, 0.0)
	var direct := spawn_goblin(w, 40.0)
	var near := spawn_goblin(w, 100.0)
	var behind := spawn_goblin(w, -100.0)
	await frames(5)
	check(p.combat.press_special(), "explosive kick available")
	p.combat.explosive_kick.release()
	await frames(10)
	check_eq(direct.health, 15.0, "kick (15) + explosion (20)")
	check_eq(near.health, 30.0, "explosion hits nearby enemies (20)")
	check_eq(behind.health, 50.0, "enemy behind Carl untouched")
	check(near.velocity.x > 0.0 or near.global_position.x > 100.0, "pushed away from the blast")
	check(p.combat.explosive_kick.cooldown_remaining > 3.0, "long cooldown started")
	check(p.combat.charged_kick.is_ready(), "separate from the power kick's cooldown")


func test_explosive_kick_barrel() -> void:
	GameManager.unlock_ability(GameManager.EXPLOSIVE_KICK)
	var w := world()
	var p := spawn_player(w, 0.0)
	var barrel := ExplosiveBarrel.new()
	barrel.position = Vector2(130, 0)
	w.add_child(barrel)
	var g := spawn_goblin(w, 210.0)
	await frames(5)
	p.combat.press_special()
	p.combat.explosive_kick.release()
	await frames(8)
	check(not is_instance_valid(barrel) or barrel.lit, "blast lit the barrel")
	await frames(15)
	check(not is_instance_valid(barrel), "barrel exploded")
	check_eq(g.health, 20.0, "barrel blast deals 30 to enemies")


func test_area_burst() -> void:
	GameManager.unlock_ability(GameManager.AREA_BURST)
	var w := world()
	var p := spawn_player(w, 0.0)
	var right := spawn_goblin(w, 100.0)
	var left := spawn_goblin(w, -100.0)
	var far := spawn_goblin(w, 300.0)
	await frames(5)
	p.combat.request_switch()
	check(p.combat.press_special(), "magic burst available")
	await frames(15)
	check_eq(right.health, 28.0, "burst deals 22 (right)")
	check_eq(left.health, 28.0, "burst deals 22 (left)")
	check_eq(far.health, 50.0, "outside the radius untouched")
	check(right.velocity.x > 0.0 and left.velocity.x < 0.0, "pushed outward both ways")
	check(p.combat.area_burst.cooldown_remaining > 5.0, "6s cooldown")
	p.combat.request_switch()
	check(not p.combat.press_special() or p.combat.explosive_kick.is_unlocked(), "Carl's special uses its own unlock")


func test_floor_unlocks() -> void:
	GameManager.reset_progress()
	var got: Array[StringName] = []
	var on_unlock := func(id: StringName) -> void: got.append(id)
	GameManager.ability_unlocked.connect(on_unlock)
	GameManager.complete_floor(1)
	check(GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK), "Floor 1 unlocks Explosive Kick")
	check(not GameManager.is_unlocked(GameManager.AREA_BURST), "Magic Burst still locked")
	GameManager.complete_floor(2)
	check(GameManager.is_unlocked(GameManager.AREA_BURST), "Floor 2 unlocks Magic Burst")
	GameManager.complete_floor(1)
	check_eq(got.size(), 2, "each unlock announced once")
	GameManager.ability_unlocked.disconnect(on_unlock)


func test_unlocks_persist() -> void:
	GameManager.reset_progress()
	SaveManager.delete_save()
	GameManager.complete_floor(1)
	check(SaveManager.has_save(), "save file written")
	# A new session: forget everything, then load from disk.
	GameManager.reset_progress()
	check(not GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK), "forgotten in memory")
	SaveManager.reload()
	GameManager.load_progress()
	check(GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK), "unlock loaded from the save")
	check(GameManager.is_floor_completed(1), "floor completion loaded")
	check_eq(GameManager.highest_unlocked_floor, 2, "floor 2 unlocked after loading")


func test_bad_save_file() -> void:
	SaveManager.delete_save()
	GameManager.load_progress()
	check(GameManager.unlocked_abilities.is_empty(), "no save: defaults")
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	SaveManager.reload()
	GameManager.load_progress()
	check_eq(GameManager.highest_unlocked_floor, 1, "broken save: defaults")
	f = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string('{"completed_floors": "nope", "highest_unlocked_floor": "x", "unlocked_abilities": [1, "explosive_kick", "fly"]}')
	f.close()
	SaveManager.reload()
	GameManager.load_progress()
	check_eq(GameManager.completed_floors.size(), 0, "wrong types ignored")
	check_eq(GameManager.unlocked_abilities, [GameManager.EXPLOSIVE_KICK] as Array[StringName], "only known abilities kept")
	SaveManager.delete_save()
	GameManager.reset_progress()


func test_debug_unlock() -> void:
	GameManager.reset_progress()
	GameManager.debug_unlock_all()
	check(GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK) and GameManager.is_unlocked(GameManager.AREA_BURST), "both unlocked")


func test_upgrade_effects() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	var up := p.upgrades
	up.apply(UP_KICK)
	check_eq(p.combat.kick_damage_multiplier, 1.25, "kick damage +25%")
	p.combat.kick_combo.press()
	await frames(10)
	check_eq(g.health, 37.5, "first kick deals 12.5")
	up.apply(UP_MAGIC)
	check_eq(p.combat.magic_missile.damage_value(), 15.0, "missile deals 15")
	up.apply(UP_KNOCKBACK)
	check_eq(p.combat.knockback_multiplier, 1.3, "knockback +30%")
	up.apply(UP_COOLDOWN)
	check_eq(p.combat.cooldown_multiplier, 0.8, "cooldowns -20%")
	up.apply(UP_SPEED)
	check_eq(p.move_speed_multiplier, 1.12, "speed +12%")
	set_health(p, 90.0)
	up.apply(UP_HEALTH)
	check_eq(p.health.max_health, 120.0, "max health 120")
	check_eq(p.health.current, 110.0, "healed by 20")
	up.apply(UP_HEALTH)
	check_eq(p.health.max_health, 140.0, "upgrades stack")
	up.clear()
	check_eq(p.health.max_health, 100.0, "max health back to 100")
	check_eq(p.health.current, 100.0, "health capped at the new max")
	check_eq(p.combat.kick_damage_multiplier, 1.0, "kick damage reset")
	check_eq(p.combat.cooldown_multiplier, 1.0, "cooldowns reset")
	check_eq(p.move_speed_multiplier, 1.0, "speed reset")
	for i in 5:
		up.apply(UP_COOLDOWN)
	check_eq(p.combat.cooldown_multiplier, PlayerUpgrades.MIN_COOLDOWN_MULTIPLIER, "cooldowns never below 40%")


func test_upgrade_roll() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(2)
	for i in 20:
		var choice := p.upgrades.roll(3)
		check_eq(choice.size(), 3, "three choices")
		check(choice[0] != choice[1] and choice[1] != choice[2] and choice[0] != choice[2], "all different")
	check_eq(p.upgrades.roll(100).size(), PlayerUpgrades.POOL.size(), "never more than the whole pool")
	for u in PlayerUpgrades.POOL:
		check(u.title != "" and u.description() != "", "%s has a name and description" % u.title)


func test_treasure_selection() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var screen: UpgradeSelectionScreen = m.get("upgrade_selection")
	var room := rooms_of(m).load_room("F1-04")
	await frames(2)
	check(room.chest.interact(), "chest opens")
	check(screen.visible, "upgrade choice shown")
	check(get_tree().paused, "gameplay paused")
	var cards := screen.cards()
	check_eq(cards.size(), 3, "three upgrades offered")
	var picked := screen.choices[1]
	cards[1].pressed.emit()
	check(not screen.visible, "screen closed")
	check(not get_tree().paused, "gameplay resumed")
	check_eq(p.upgrades.active, [picked] as Array[Upgrade], "picked upgrade applied")
	check(not room.chest.interact(), "chest only gives one reward")


func test_upgrades_reset() -> void:
	var m := spawn_main()
	var p := player_of(m)
	p.upgrades.apply(UP_KICK)
	p.health.take_damage(999.0, true)
	await frames(secs(1.7))
	check_eq(GameManager.lives, 2, "lost a life")
	check_eq(p.upgrades.active.size(), 1, "upgrade kept after death")
	m.call("restart_floor")
	check_eq(p.upgrades.active.size(), 0, "floor restart clears upgrades")
	check_eq(p.combat.kick_damage_multiplier, 1.0, "effect removed")


func test_spikes() -> void:
	var w := world()
	var spikes := SpikeTrap.new()
	spikes.position = Vector2(100, -32)
	spikes.size = Vector2(64, 32)
	w.add_child(spikes)
	var p := spawn_player(w, 132.0)
	await frames(3)
	check_eq(p.health.current, 85.0, "spikes deal 15")
	check(p.velocity.y < 0.0 or p.global_position.y < -30.0, "bounced up")
	var g := spawn_goblin(w, -300.0)
	var g2 := spawn_goblin(w, 132.0)
	var killer: Array[Hit] = []
	g2.died.connect(func(e: EnemyBase) -> void: killer.append(e.last_hit))
	await frames(2)
	check(g2.health < 50.0, "enemies take spike damage")
	await frames(secs(1.5))
	check_eq(killer.size(), 1, "spikes kill enemies")
	check(not killer.is_empty() and killer[0].has_tag("hazard"), "kill credited to the hazard")
	check_eq(g.health, 50.0, "enemies off the spikes are fine")


func test_barrels() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b1 := ExplosiveBarrel.new()
	b1.position = Vector2(150, 0)
	w.add_child(b1)
	var b2 := ExplosiveBarrel.new()
	b2.position = Vector2(230, 0)
	w.add_child(b2)
	var g := spawn_goblin(w, 330.0)
	var bystander := spawn_player(w, 90.0)
	await frames(3)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(40)
	check(not is_instance_valid(b1), "barrel hit by a bolt exploded")
	check(not is_instance_valid(b2), "second barrel chained")
	check_eq(g.health, 20.0, "enemy caught by the chained blast (30)")
	check_eq(bystander.health.current, 80.0, "player in the blast takes 20")
	check_eq(p.health.current, 100.0, "player outside the blast unhurt")


func test_breakables() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var crate := Breakable.new()
	crate.position = Vector2(30, -28)
	w.add_child(crate)
	await frames(3)
	p.combat.kick_combo.press()
	await frames(20)
	check(not crate.is_broken, "a light kick doesn't break it")
	p.combat.kick_combo.press()
	await frames(20)
	p.combat.kick_combo.press()
	await frames(10)
	check(not is_instance_valid(crate) or crate.is_broken, "combo finisher breaks it")
	await frames(3)
	check_eq(_count_potions(w), 1, "crate dropped a potion")

	var w2 := world()
	w2.position = Vector2(0, 2000)
	var wall := Breakable.new()
	wall.kind = Breakable.Kind.WALL
	wall.size = Vector2(32, 96)
	wall.position = Vector2(100, -96)
	w2.add_child(wall)
	var p2 := spawn_player(w2, 0.0)
	await frames(3)
	check(wall.collision_layer & HitQuery.LAYER_WORLD, "cracked wall is solid")
	p2.combat.request_switch()
	p2.combat.magic_missile.press()
	await frames(20)
	check(not wall.is_broken, "missile can't break it")
	var cb := p2.combat.charged_blast
	await frames(10)
	cb.press()
	await frames(70)
	cb.release()
	await frames(20)
	check(not is_instance_valid(wall) or wall.is_broken, "full charged blast breaks it")


func test_enemy_collision() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var a := spawn_goblin(w, 40.0)
	var b := spawn_goblin(w, 140.0)
	var hits := [0]
	a.collided.connect(func(_x: EnemyBase, _y: EnemyBase) -> void: hits[0] += 1)
	await frames(5)
	var ck := p.combat.charged_kick
	ck.press()
	await frames(70)
	ck.release()
	await frames(60)
	check_eq(hits[0], 1, "one collision")
	check_eq(b.health, 35.0, "hit enemy takes 15 once")
	check_eq(a.health, 7.0, "thrown enemy takes 35 + 8")
	check(b.last_hit.has_tag("collision"), "tagged as a collision")


func test_weak_knockback_no_collision() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var a := spawn_goblin(w, 100.0)
	var b := spawn_goblin(w, 130.0)
	await frames(5)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(40)
	check_eq(a.health, 38.0, "missile hit")
	check_eq(b.health, 50.0, "no collision damage from a light hit")


# --- Milestone 7: Dungeon AI -------------------------------------------------

func ai_of(m: Node) -> DungeonAIManager:
	return m.get("dungeon_ai")


func test_ai_events() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var a := spawn_goblin(w, 40.0)
	spawn_goblin(w, 140.0)
	var collisions := [0]
	var deaths: Array[EnemyBase] = []
	var on_collide := func(_x: EnemyBase, _y: EnemyBase) -> void: collisions[0] += 1
	var on_death := func(e: EnemyBase) -> void: deaths.append(e)
	GameManager.enemy_collided.connect(on_collide)
	GameManager.enemy_died.connect(on_death)
	await frames(5)
	var ck := p.combat.charged_kick
	ck.press()
	await frames(70)
	ck.release()
	await frames(60)
	check_eq(collisions[0], 1, "collision reported once")
	a.take_hit(Hit.new(999.0))
	check_eq(deaths, [a] as Array[EnemyBase], "death reported")
	GameManager.enemy_collided.disconnect(on_collide)
	GameManager.enemy_died.disconnect(on_death)


func test_ai_collision() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var hud: HUD = m.get("hud")
	var room := rooms_of(m).load_room("F1-02")
	await frames(2)
	var g := room.required_enemies
	GameManager.enemy_collided.emit(g[0], g[1])
	check_eq(ai.history, [DungeonAIManager.COLLISION] as Array[StringName], "achievement awarded")
	check(hud.achievement_panel.is_showing(), "announcement on screen")
	var entry := hud.achievement_panel.current
	check_eq(entry.get("title"), "YOU KICKED A GOBLIN INTO ANOTHER GOBLIN!", "title")
	check(String(entry.get("description", "")).length() > 20, "has a description")
	check(String(entry.get("reward", "")).contains("knockback"), "names the reward")
	check_eq(p.combat.knockback_multiplier, 1.5, "+50% knockback")
	check(not get_tree().paused, "game not paused")
	GameManager.enemy_collided.emit(g[1], g[0])
	check_eq(ai.history.size(), 1, "not repeated in the same encounter")
	check(hud.achievement_panel.queue.is_empty(), "no duplicate announcement queued")


func test_ai_boost_duration() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var rm := rooms_of(m)
	var room := rm.load_room("F1-02")
	await frames(2)
	GameManager.enemy_collided.emit(room.required_enemies[0], room.required_enemies[1])
	var kb := PlayerUpgrades.BOOST_KNOCKBACK
	check_eq(p.upgrades.boost_rooms_left(kb), 3, "three more rooms")
	rm.load_room("F1-03")
	check_eq(p.upgrades.boost_rooms_left(kb), 2, "two left")
	rm.load_room("F1-04")
	rm.load_room("F1-05")
	check_eq(p.upgrades.boost_rooms_left(kb), 0, "last room")
	check_eq(p.combat.knockback_multiplier, 1.5, "still active in the third room")
	rm.load_room("F1-U1")
	check_eq(p.upgrades.boost_rooms_left(kb), -1, "expired")
	check_eq(p.combat.knockback_multiplier, 1.0, "knockback back to normal")


func test_ai_environment_kill() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var hud: HUD = m.get("hud")
	var room := rooms_of(m).load_room("F1-05")
	await frames(2)
	var goblins := room.required_enemies.duplicate()
	goblins[0].take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check(not ai.history.has(DungeonAIManager.ENVIRONMENT_KILL), "a normal kill doesn't count")
	# Drop a goblin into the real spike pit.
	var g: EnemyBase = goblins[1]
	g.ai_enabled = false
	g.global_position = Vector2(21.5 * 32.0, 19.0 * 32.0 - 22.0)
	g.velocity = Vector2.ZERO
	await until(func() -> bool: return ai.history.has(DungeonAIManager.ENVIRONMENT_KILL), secs(3.0))
	check(ai.history.has(DungeonAIManager.ENVIRONMENT_KILL), "spike kill awarded")
	var shown: Array[Dictionary] = [hud.achievement_panel.current]
	shown.append_array(hud.achievement_panel.queue)
	check(shown.any(func(e: Dictionary) -> bool: return String(e.get("description", "")).contains("spikes")), "mentions the spikes")
	check_eq(p.combat.kick_damage_multiplier, 1.25, "+25% kick damage")
	check_eq(p.combat.magic_damage_multiplier, 1.25, "+25% magic damage")


func test_ai_untouchable() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var rm := rooms_of(m)
	p.health.take_damage(10.0)  # before the room: doesn't count
	var room := rm.load_room("F1-02")
	set_health(p, 50.0)
	kill_required(room)
	check(ai.history.has(DungeonAIManager.UNTOUCHABLE), "untouchable clear awarded")
	check_eq(p.health.current, 75.0, "healed 25 HP")
	var room2 := rm.load_room("F1-05")
	p.health._invuln = 0.0
	p.health.take_damage(5.0)
	kill_required(room2)
	check_eq(ai.history.count(DungeonAIManager.UNTOUCHABLE), 1, "taking a hit spoils it")
	var safe := rm.load_room("F1-03")
	check(safe != null and ai.history.count(DungeonAIManager.UNTOUCHABLE) == 1, "safe rooms don't award it")


func test_ai_announcements() -> void:
	var m := spawn_main()
	var ai := ai_of(m)
	var hud: HUD = m.get("hud")
	var panel := hud.achievement_panel
	await frames(2)
	ai.award(&"test_a", {"title": "A", "description": "first", "reward": "none"})
	ai.award(&"test_b", {"title": "B", "description": "second", "reward": "none"})
	check_eq(panel.current.get("title"), "A", "first shown")
	check_eq(panel.queue.size(), 1, "second waits its turn")
	check(not get_tree().paused, "game keeps running")
	await frames(secs(5.4))
	check_eq(panel.current.get("title"), "B", "second shown after the first")
	await frames(secs(5.4))
	check(not panel.is_showing(), "panel hides when the queue is empty")


func test_ai_boost_reset() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var room := rooms_of(m).load_room("F1-02")
	await frames(2)
	GameManager.enemy_collided.emit(room.required_enemies[0], room.required_enemies[1])
	p.health.take_damage(999.0, true)
	await frames(secs(1.7))
	check_eq(rooms_of(m).current_room_id, "F1-02", "room restarted")
	check_eq(p.upgrades.boost_rooms_left(PlayerUpgrades.BOOST_KNOCKBACK), 3, "boost kept, restart doesn't count as a room")
	var fresh := rooms_of(m).current_room
	GameManager.enemy_collided.emit(fresh.required_enemies[0], fresh.required_enemies[1])
	check_eq(ai.history.size(), 2, "a restarted room is a new encounter")
	m.call("restart_floor")
	check(p.upgrades.boosts.is_empty(), "floor restart clears boosts")
	check_eq(p.combat.knockback_multiplier, 1.0, "knockback back to normal")


# --- Milestone 8 part 1: Floor 2 ------------------------------------------------

func test_floor2_graph() -> void:
	await _check_floor_graph(2, "F2-01", FLOOR2_EXITS, FLOOR2_TYPES)


func spawn_slime(w: Node2D, x: float, ai := true) -> Slime:
	var s := SLIME_SCENE.instantiate() as Slime
	s.position = Vector2(x, -12)
	s.ai_enabled = ai
	s.rng.seed = 3
	w.add_child(s)
	return s


func test_slime_hop() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var s := spawn_slime(w, 200.0)
	check(await until(func() -> bool: return s.is_telegraphing(), secs(4.0)), "squash telegraph")
	check(s.is_engaged, "noticed the player")
	check_eq(s.facing, -1, "facing the player")
	await until(func() -> bool: return s.state == Slime.State.HOP)
	check(s.velocity.x < 0.0 and s.velocity.y < 0.0, "hops toward the player")
	await frames(secs(2.0))
	check(s.global_position.x < 150.0, "closed in (x=%.0f)" % s.global_position.x)
	check(p.health.current <= 100.0, "still alive")


func test_slime_contact() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var s := spawn_slime(w, 0.0)
	s.hop_interval = 99.0
	s.set_engaged(true)
	s._t = 99.0
	await frames(30)
	check_eq(p.health.current, 100.0, "resting slime is harmless to touch")
	s._t = 0.0
	await until(func() -> bool: return s.state == Slime.State.HOP)
	await frames(3)
	check_eq(p.health.current, 90.0, "hop into the player deals 10")


func test_slime_avoids_pit() -> void:
	var w := Node2D.new()
	w.name = "TestWorld"
	add_child(w)
	var left := SolidBlock.new()
	left.position = Vector2(-400, 0)
	left.size = Vector2(560, 40)
	w.add_child(left)
	var pit := SolidBlock.new()
	pit.position = Vector2(160, 32)
	pit.size = Vector2(96, 40)
	w.add_child(pit)
	var spikes := SpikeTrap.new()
	spikes.position = Vector2(160, 0)
	spikes.size = Vector2(96, 32)
	w.add_child(spikes)
	var right := SolidBlock.new()
	right.position = Vector2(256, 0)
	right.size = Vector2(400, 40)
	w.add_child(right)
	spawn_player(w, 330.0)
	var s := spawn_slime(w, 120.0)
	await frames(secs(5.0))
	check(not s.is_dead and s.global_position.x < 160.0, "stayed on its side of the pit (x=%.0f)" % s.global_position.x)


func test_slime_dead() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var s := spawn_slime(w, 60.0)
	await until(func() -> bool: return s.state == Slime.State.HOP)
	s.take_hit(Hit.new(999.0))
	await frames(40)
	check_eq(p.health.current, 100.0, "no damage after death")


func spawn_slime_boss(w: Node2D, x: float, attack := -1) -> SlimeBoss:
	var b := SLIME_BOSS_SCENE.instantiate() as SlimeBoss
	b.position = Vector2(x, -32)
	b.forced_attack = attack
	b.rng.seed = 5
	w.add_child(b)
	return b


func wake_slime(b: SlimeBoss) -> void:
	b.start_fight()
	await until(func() -> bool: return b.state != SlimeBoss.State.INTRO)


func _globs(w: Node) -> Array[Node]:
	return w.find_children("*", "SlimeGlob", true, false)


func test_slime_boss_volley() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_slime_boss(w, 500.0, SlimeBoss.Attack.VOLLEY)
	await wake_slime(b)
	check(await until(func() -> bool: return b.is_telegraphing()), "volley telegraph")
	b.take_hit(Hit.new(0.0))
	var predicted: Array[float] = []
	for v in b.volley_velocities():
		predicted.append(b.glob_landing_x(v))
	check_eq(predicted.size(), 5, "five globs in phase 1")
	p.global_position.x = -600.0  # out of the way
	await until(func() -> bool: return b.state == SlimeBoss.State.ACTIVE)
	var globs := _globs(w)
	check_eq(globs.size(), 5, "five globs fired")
	var last: Array[float] = []
	last.resize(globs.size())
	for i in 120:
		for j in globs.size():
			if is_instance_valid(globs[j]):
				last[j] = (globs[j] as Node2D).global_position.x
		await get_tree().physics_frame
	var ok := true
	for j in globs.size():
		if absf(last[j] - predicted[j]) > 16.0:
			ok = false
	check(ok, "globs land where the arcs predicted (%s vs %s)" % [str(last), str(predicted)])
	check_eq(_globs(w).size(), 0, "globs gone after landing")


func test_slime_boss_volley_gap() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var hit_p := spawn_player(w, 40.0)
	var b := spawn_slime_boss(w, 600.0, SlimeBoss.Attack.VOLLEY)
	await wake_slime(b)
	await until(func() -> bool: return b.is_telegraphing())
	var xs: Array[float] = []
	for v in b.volley_velocities():
		xs.append(b.glob_landing_x(v))
	p.global_position.x = (xs[1] + xs[2]) * 0.5
	hit_p.global_position.x = xs[3]
	await until(func() -> bool: return b.state == SlimeBoss.State.ACTIVE)
	await until(func() -> bool: return _globs(w).is_empty(), secs(3.0))
	check_eq(p.health.current, 100.0, "safe in the gap between landing spots")
	check_eq(hit_p.health.current, 88.0, "a glob on your head deals 12")


func test_slime_boss_jump() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_slime_boss(w, 300.0, SlimeBoss.Attack.JUMP)
	await wake_slime(b)
	check(await until(func() -> bool: return b.is_telegraphing()), "jump telegraph")
	check_eq(b.target_x, p.global_position.x, "marker where the player stood")
	var target := b.target_x
	p.global_position.x = -350.0
	await until(func() -> bool: return b.state == SlimeBoss.State.AIRBORNE)
	await until(func() -> bool: return b.state == SlimeBoss.State.ACTIVE, secs(2.0))
	check(absf(b.global_position.x - target) < 30.0, "landed on the marker (x=%.0f)" % b.global_position.x)
	check_eq(p.health.current, 100.0, "moving away avoids it")
	var pools := w.find_children("*", "AcidPool", true, false)
	check_eq(pools.size(), 1, "acid pool left behind")
	p.global_position.x = target + 40.0
	await frames(10)
	check_eq(p.health.current, 92.0, "acid hurts (8)")


func test_slime_boss_phase_two() -> void:
	var w := world()
	spawn_player(w, -600.0)
	var b := spawn_slime_boss(w, 300.0, SlimeBoss.Attack.SPAWN)
	await wake_slime(b)
	var t1 := b.telegraph_time(SlimeBoss.Attack.VOLLEY)
	b.take_hit(Hit.new(210.0))
	check_eq(b.phase, 2, "phase 2 at 50%")
	check_eq(b.state, SlimeBoss.State.TRANSITION, "mutates first")
	b.take_hit(Hit.new(20.0))
	check_eq(b.health, 210.0, "immune while mutating")
	check(b.telegraph_time(SlimeBoss.Attack.VOLLEY) < t1, "faster telegraphs")
	check_eq(b.current_volley_speeds().size(), 7, "seven globs")
	await until(func() -> bool: return b.state == SlimeBoss.State.ACTIVE)
	check_eq(b.alive_minis(), 2, "split off two minis")
	for m in b.minis:
		check(m.is_engaged, "minis attack straight away")
	b.forced_attack = SlimeBoss.Attack.VOLLEY
	await until(func() -> bool: return b.state == SlimeBoss.State.ACTIVE and b.attack == SlimeBoss.Attack.VOLLEY)
	await frames(90)
	check(w.find_children("*", "AcidPool", true, false).size() >= 3, "globs leave acid pools")


func test_slime_boss_death() -> void:
	var w := world()
	spawn_player(w, -700.0)
	var b := spawn_slime_boss(w, 300.0, SlimeBoss.Attack.SPAWN)
	await wake_slime(b)
	b.take_hit(Hit.new(220.0))
	await until(func() -> bool: return b.alive_minis() == 2)
	var pool := AcidPool.new()
	w.add_child(pool)
	b.take_hit(Hit.new(999.0))
	check(b.is_dead, "boss dead")
	check_eq(b.alive_minis(), 0, "minis die with it")
	await frames(3)
	check(not is_instance_valid(pool), "acid cleared")
	check(_count_potions(w) >= 2, "at least the two guaranteed potions")


func test_continue_to_floor2() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var rm := rooms_of(m)
	var screen: FloorCompleteScreen = m.get("floor_complete")
	var room := rm.load_room("F1-08")
	p.global_position.x = room.boss.global_position.x - 300.0
	await frames(3)
	await until(func() -> bool: return not room.boss.is_immune())
	room.boss.take_hit(Hit.new(999.0))
	p.potions.count = 7
	p.upgrades.apply(UP_KICK)
	GameManager.lose_life()
	p.health.take_damage(40.0, true)
	p.global_position = room.floor_exit.global_position + Vector2(0, -30)
	await frames(3)
	check(screen.visible, "Floor Complete shown")
	(screen.get_node("%ContinueButton") as Button).pressed.emit()
	await frames(2)
	check_eq(GameManager.floor_number, 2, "on Floor 2")
	check_eq(rm.current_room_id, "F2-01", "at the Floor 2 entrance")
	check_eq(GameManager.lives, 3, "lives back to 3")
	check_eq(p.health.current, p.health.max_health, "full health")
	check_eq(p.potions.count, 7, "unused potions carried over")
	check(p.upgrades.active.is_empty(), "Floor 1 upgrades gone")
	check(not get_tree().paused, "playing again")
	GameManager.floor_number = 1


func test_floor2_complete() -> void:
	GameManager.reset_progress()
	var m := spawn_main()
	var p := player_of(m)
	var rm := rooms_of(m)
	var screen: FloorCompleteScreen = m.get("floor_complete")
	GameManager.floor_number = 2
	rm.start_floor(2)
	var room := rm.load_room("F2-08")
	check(room.boss is SlimeBoss, "Mutating Slime in the arena")
	p.global_position.x = room.boss.global_position.x - 300.0
	await frames(3)
	check(p.combat_state.is_boss_active(), "boss fight started")
	await until(func() -> bool: return not room.boss.is_immune())
	room.boss.take_hit(Hit.new(999.0))
	check(GameManager.is_floor_completed(2), "Floor 2 completed")
	check(GameManager.is_unlocked(GameManager.AREA_BURST), "Magic Burst unlocked")
	p.global_position = room.floor_exit.global_position + Vector2(0, -30)
	await frames(3)
	check(screen.visible, "Floor Complete shown")
	check(not (screen.get_node("%ContinueButton") as Button).visible, "no Floor 3")
	check((screen.get_node("%Body") as Label).text.contains("Mutating Slime"), "names the boss")
	(screen.get_node("%ReplayButton") as Button).pressed.emit()
	await frames(2)
	check_eq(rm.current_room_id, "F2-01", "replay restarts Floor 2")
	GameManager.floor_number = 1


func test_slime_boss_platforms() -> void:
	var w := world()
	var plat := SolidBlock.new()
	plat.one_way = true
	plat.size = Vector2(160, 12)
	plat.position = Vector2(-80, -96)
	w.add_child(plat)
	var p := spawn_player(w, 0.0)
	p.position = Vector2(0, -96 - 29)
	p.health._invuln = 99.0
	var b := spawn_slime_boss(w, 300.0, SlimeBoss.Attack.JUMP)
	await wake_slime(b)
	await until(func() -> bool: return b.state == SlimeBoss.State.AIRBORNE)
	await until(func() -> bool: return b.state != SlimeBoss.State.AIRBORNE, secs(2.0))
	check(b.feet_y() > -2.0, "landed on the floor, not the platform (feet y=%.0f)" % b.feet_y())
	check(b.global_position.x < 60.0, "still leapt at the player above")


# --- Milestone 8 part 2: menus, settings, saves --------------------------------

const MENU_SCENE := preload("res://scenes/ui/MainMenu.tscn")


func spawn_menu() -> MainMenu:
	var menu := MENU_SCENE.instantiate() as MainMenu
	menu.name = "TestMenu"
	menu.navigate = false
	add_child(menu)
	return menu


func test_save_merge() -> void:
	SaveManager.delete_save()
	GameManager.reset_progress()
	Settings.set_volume("Music", 0.3)
	GameManager.complete_floor(1)
	SaveManager.reload()
	var data := SaveManager.load_data()
	check(data.has("settings"), "settings kept after saving progress")
	check_eq(int(data.get("highest_unlocked_floor", 0)), 2, "progress saved")
	Settings.set_volume("Music", 0.6)
	SaveManager.reload()
	check(SaveManager.load_data().get("unlocked_abilities", []).has("explosive_kick"), "progress kept after saving settings")
	SaveManager.delete_save()
	GameManager.reset_progress()
	Settings.load_settings()


func test_settings_volume() -> void:
	var music := AudioServer.get_bus_index("Music")
	check(music >= 0 and AudioServer.get_bus_index("SFX") >= 0, "Music and SFX buses exist")
	Settings.set_volume("Music", 0.5)
	check_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), "bus volume set")
	check(not AudioServer.is_bus_mute(music), "audible")
	Settings.set_volume("SFX", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero mutes the bus")
	SaveManager.reload()
	Settings.load_settings()
	check_eq(Settings.volumes["Music"], 0.5, "music volume persisted")
	check_eq(Settings.volumes["SFX"], 0.0, "sfx volume persisted")
	SaveManager.delete_save()
	Settings.load_settings()
	check_eq(Settings.volumes["SFX"], 0.8, "defaults without a save")


func test_settings_fullscreen() -> void:
	Settings.set_fullscreen(true)
	SaveManager.reload()
	Settings.load_settings()
	check(Settings.fullscreen, "fullscreen persisted")
	Settings.set_fullscreen(false)
	SaveManager.delete_save()
	Settings.load_settings()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func test_rebind() -> void:
	Settings.rebind("jump", KEY_W)
	check(InputMap.event_is_action(_key(KEY_W), "jump"), "W now jumps")
	check(not InputMap.event_is_action(_key(KEY_SPACE), "jump"), "Space no longer jumps")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	check(InputMap.event_is_action(pad, "jump"), "controller button kept")
	check_eq(Settings.key_label("jump"), "W", "shown as W")
	Settings.rebind("move_left", KEY_Q)
	check(InputMap.event_is_action(_key(KEY_Q), "move_left"), "Q moves left")
	check(InputMap.event_is_action(_key(KEY_LEFT), "move_left"), "arrow key still works")
	check_eq(Settings.key_label("move_left"), "Q", "new key shown first")
	Settings.rebind("pause", KEY_P)
	check(not InputMap.event_is_action(_key(KEY_P), "pause"), "pause can't be remapped")
	# New session: bindings come back from the save.
	InputMap.load_from_project_settings()
	SaveManager.reload()
	Settings.load_settings()
	check(InputMap.event_is_action(_key(KEY_W), "jump"), "remap persisted")
	Settings.reset_keys()
	check(InputMap.event_is_action(_key(KEY_SPACE), "jump"), "reset restores Space")
	check(not InputMap.event_is_action(_key(KEY_W), "jump"), "reset removes W")
	SaveManager.delete_save()
	Settings.load_settings()


func test_menu_fresh() -> void:
	SaveManager.delete_save()
	GameManager.reset_progress()
	var menu := spawn_menu()
	await frames(2)
	check(not menu.continue_button.visible, "no Continue without a started game")
	check_eq(menu.floor_buttons.size(), 0, "no floor select")
	menu.new_game_button.pressed.emit()
	check(not menu.is_confirming(), "nothing to erase, no confirmation")
	check(GameManager.can_continue(), "game started and saved")
	check_eq(menu.requested_scene, MainMenu.GAME_SCENE, "starts the game")
	check_eq(GameManager.floor_number, 1, "on Floor 1")
	SaveManager.reload()
	GameManager.load_progress()
	check(GameManager.can_continue(), "Continue survives a restart")
	GameManager.floor_number = 1


func test_menu_continue() -> void:
	SaveManager.delete_save()
	GameManager.new_game()
	var menu := spawn_menu()
	await frames(2)
	check(menu.continue_button.visible, "Continue shown")
	check(menu.continue_button.text.contains("Floor 1"), "continues Floor 1")
	menu.free()
	GameManager.complete_floor(1)
	menu = spawn_menu()
	await frames(2)
	check(menu.continue_button.text.contains("Floor 2"), "continues from the latest unlocked floor")
	check_eq(menu.floor_buttons.size(), 2, "floor select: Floor 1 and Floor 2")
	menu.continue_button.pressed.emit()
	check_eq(GameManager.floor_number, 2, "Continue starts Floor 2")
	menu.floor_buttons[0].pressed.emit()
	check_eq(GameManager.floor_number, 1, "floor select can replay Floor 1")
	menu.free()
	GameManager.complete_floor(2)
	check_eq(GameManager.continue_floor(), 2, "after the last floor, Continue stays on Floor 2")
	GameManager.floor_number = 1
	SaveManager.delete_save()
	GameManager.reset_progress()


func test_menu_new_game_confirm() -> void:
	SaveManager.delete_save()
	GameManager.new_game()
	GameManager.complete_floor(1)
	Settings.set_volume("Music", 0.25)
	var menu := spawn_menu()
	await frames(2)
	menu.new_game_button.pressed.emit()
	check(menu.is_confirming(), "asks before erasing")
	check_eq(menu.requested_scene, "", "hasn't started yet")
	(menu.find_child("Cancel", true, false) as Button).pressed.emit()
	check(not menu.is_confirming(), "cancelled")
	check(GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK), "progress untouched")
	menu.new_game_button.pressed.emit()
	(menu.find_child("Confirm", true, false) as Button).pressed.emit()
	check(not GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK), "unlocks erased")
	check(not GameManager.is_floor_completed(1), "floors erased")
	check_eq(menu.requested_scene, MainMenu.GAME_SCENE, "new game started")
	SaveManager.reload()
	Settings.load_settings()
	check_eq(Settings.volumes["Music"], 0.25, "settings kept")
	SaveManager.delete_save()
	GameManager.reset_progress()
	Settings.load_settings()
	GameManager.floor_number = 1


func test_menu_floor_start() -> void:
	GameManager.lose_life()
	GameManager.floor_number = 2
	var m := MAIN_SCENE.instantiate()
	m.name = "TestWorldMain2"
	m.set("navigate", false)
	add_child(m)
	var p: Player = m.get("player")
	p.read_input = false
	p.combat.read_input = false
	await frames(2)
	check_eq(rooms_of(m).current_room_id, "F2-01", "starts at the Floor 2 entrance")
	check_eq(GameManager.lives, 3, "3 lives")
	check_eq(p.potions.count, 3, "3 potions")
	check(p.upgrades.active.is_empty(), "no upgrades")
	GameManager.floor_number = 1


func test_pause_menu() -> void:
	var m := spawn_main()
	var pm: PauseMenu = m.get("pause_menu")
	await frames(2)
	check(pm.open(), "opens")
	check(get_tree().paused, "game paused")
	check(pm.visible, "menu shown")
	pm.resume_button.pressed.emit()
	check(not get_tree().paused, "resumed")
	check(not pm.visible, "menu hidden")
	(m.get("game_over") as GameOverScreen).show_screen()
	check(not pm.open(), "won't open over Game Over")
	get_tree().paused = false
	(m.get("game_over") as GameOverScreen).hide()
	pm.open()
	pm.menu_button.pressed.emit()
	check(not get_tree().paused, "unpaused when leaving")
	check_eq(m.get("requested_scene"), "res://scenes/ui/MainMenu.tscn", "goes to the main menu")


func test_pause_key() -> void:
	var m := spawn_main()
	var pm: PauseMenu = m.get("pause_menu")
	await frames(2)
	var press := InputEventAction.new()
	press.action = "pause"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	check(pm.visible and get_tree().paused, "Esc/Start pauses")
	var release := InputEventAction.new()
	release.action = "pause"
	release.pressed = false
	Input.parse_input_event(release)
	await frames(1)
	Input.parse_input_event(press)
	await frames(2)
	check(not pm.visible and not get_tree().paused, "pressing it again resumes")
	Input.parse_input_event(release)


func test_menu_buttons() -> void:
	var m := spawn_main()
	var go: GameOverScreen = m.get("game_over")
	go.show_screen()
	(go.get_node("%MenuButton") as Button).pressed.emit()
	check(not get_tree().paused, "unpaused")
	check_eq(m.get("requested_scene"), "res://scenes/ui/MainMenu.tscn", "Game Over -> main menu")
	m.set("requested_scene", "")
	var fc: FloorCompleteScreen = m.get("floor_complete")
	fc.show_screen(1, 3, 3)
	(fc.get_node("%MenuButton") as Button).pressed.emit()
	check_eq(m.get("requested_scene"), "res://scenes/ui/MainMenu.tscn", "Floor Complete -> main menu")
	check(not get_tree().paused, "unpaused")


# --- Milestone 8 part 3: audio, controller, full run ----------------------------

func _gd_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "build" and d != "tests":
			_gd_files(dir.path_join(d), out)


func test_sound_files() -> void:
	var files: Array[String] = []
	_gd_files("res://", files)
	var re := RegEx.create_from_string("Audio\\.play\\(\"([a-z_]+)\"")
	var names := {}
	for path in files:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			names[m.get_string(1)] = path
	check(names.size() >= 20, "found the sound calls (%d)" % names.size())
	for sound: String in names:
		check(ResourceLoader.exists("res://assets/sounds/%s.wav" % sound), "%s.wav exists (used in %s)" % [sound, names[sound]])
	for track in ["menu", "floor1", "floor2", "boss"]:
		check(ResourceLoader.exists("res://assets/music/%s.ogg" % track), "music %s exists" % track)


func test_sound_hooks() -> void:
	Audio.history.clear()
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	p.combat.kick_combo.press()
	await frames(10)
	check(Audio.history.has("kick"), "kick")
	check(Audio.history.has("hit"), "hit on the goblin")
	p.combat.request_switch()
	check(Audio.history.has("switch_mode"), "mode switch")
	await frames(30)
	p.combat.magic_missile.press()
	await frames(5)
	check(Audio.history.has("magic_missile"), "missile")
	g.take_hit(Hit.new(999.0))
	check(Audio.history.has("enemy_death"), "enemy death")
	set_health(p, 50.0)
	p.potions.use()
	check(Audio.history.has("potion_drink"), "potion")
	check(p.try_dodge(1.0), "dodged")
	check(Audio.history.has("dodge"), "dodge")
	var barrel := ExplosiveBarrel.new()
	w.add_child(barrel)
	barrel.explode()
	check(Audio.history.has("explosion"), "explosion")


func test_music() -> void:
	var menu := spawn_menu()
	await frames(2)
	check_eq(Audio.current_music, "menu", "menu music")
	menu.free()
	var m := spawn_main()
	await frames(2)
	check_eq(Audio.current_music, "floor1", "Floor 1 music")
	var room := rooms_of(m).load_room("F1-08")
	var p := player_of(m)
	p.global_position.x = room.boss.global_position.x - 300.0
	await frames(3)
	check_eq(Audio.current_music, "boss", "boss music when the fight starts")
	await until(func() -> bool: return not room.boss.is_immune())
	room.boss.take_hit(Hit.new(999.0))
	check_eq(Audio.current_music, "floor1", "back to the floor music after the boss")
	check(Audio.history.has("floor_complete"), "victory jingle")
	for i in 3:
		p.health._invuln = 0.0
		p.health.take_damage(999.0, true)
		await frames(secs(1.7))
	check_eq(Audio.current_music, "", "music stops on Game Over")
	check(Audio.history.has("game_over"), "game over sound")


func test_controller_bindings() -> void:
	for action in ["move_left", "move_right", "jump", "dodge", "basic_attack", "charged_attack", "switch_mode",
			"special_attack", "use_potion", "interact", "pause"]:
		var has_pad := false
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				has_pad = true
		check(has_pad, "%s has a controller binding" % action)
	for ui in ["ui_accept", "ui_up", "ui_down", "ui_left", "ui_right", "ui_cancel"]:
		var pad := false
		for e in InputMap.action_get_events(ui):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				pad = true
		check(pad, "menus: %s works on a controller" % ui)
	var w := world()
	var p := spawn_player(w, 0.0)
	p.read_input = true
	await frames(3)
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	Input.parse_input_event(a)
	await frames(2)
	check(p.velocity.y < 0.0, "A button jumps")
	a.pressed = false
	Input.parse_input_event(a)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await frames(20)
	check(p.velocity.x > 100.0, "left stick moves")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	p.read_input = false
	await frames(2)


func test_controller_prompts() -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_X
	b.pressed = true
	Input.parse_input_event(b)
	await frames(1)
	check(Settings.using_controller, "controller detected")
	check_eq(Settings.prompt_label("jump"), "A", "jump shows A")
	check_eq(Settings.prompt_label("interact"), "LT", "interact shows LT")
	check_eq(Settings.prompt_label("switch_mode"), "LB", "switch shows LB")
	b.pressed = false
	Input.parse_input_event(b)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	k.pressed = true
	Input.parse_input_event(k)
	await frames(1)
	check(not Settings.using_controller, "back to keyboard")
	check_eq(Settings.prompt_label("jump"), "Space", "jump shows Space")
	k.pressed = false
	Input.parse_input_event(k)
	await frames(1)


## Plays through a room: clears its fight, completes its trial, takes the chest
## (picking the first upgrade), then leaves by exit `exit_index`.
func _clear_room(m: Node, exit_index: int) -> void:
	var rm := rooms_of(m)
	var room := rm.current_room
	var p := player_of(m)
	p.health._invuln = 99.0
	kill_required(room)
	if room.room_type == RoomBase.RoomType.CHALLENGE:
		room.complete_trial()
		if room.chest and room.chest.interact():
			var screen: UpgradeSelectionScreen = m.get("upgrade_selection")
			screen.cards()[0].pressed.emit()
	if room.room_type == RoomBase.RoomType.SAFE and room.fountain:
		room.fountain.interact()
		await _finish_loot(m)
	check(rm.request_exit(exit_index), "%s: exit %d" % [room.room_id, exit_index + 1])
	while rm.transitioning:
		await get_tree().process_frame


## Opens every loot box on the loot screen and takes the first upgrade offered.
func _finish_loot(m: Node) -> void:
	var loot: LootBoxScreen = m.get("loot_screen")
	var picks: UpgradeSelectionScreen = m.get("upgrade_selection")
	for i in 200:
		if loot.is_open():
			loot.advance()
		elif picks.visible:
			picks.cards()[0].pressed.emit()
		else:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	if picks.visible:
		picks.cards()[0].pressed.emit()


func _beat_boss(m: Node) -> void:
	var room := rooms_of(m).current_room
	var p := player_of(m)
	p.health._invuln = 99.0
	p.global_position.x = room.boss.global_position.x - 300.0
	await until(func() -> bool: return p.combat_state.is_boss_active())
	await until(func() -> bool: return not room.boss.is_immune())
	room.boss.take_hit(Hit.new(999.0))
	check(room.floor_exit.open, "%s: stairs open" % room.room_id)
	p.global_position = room.floor_exit.global_position + Vector2(0, -30)
	await frames(3)


func test_full_run() -> void:
	SaveManager.delete_save()
	GameManager.new_game()
	var m := spawn_main()
	var rm := rooms_of(m)
	var screen: FloorCompleteScreen = m.get("floor_complete")
	await frames(2)
	# Floor 1 by the high road.
	var route1 := [["F1-01", 0], ["F1-02", 0], ["F1-03", 0], ["F1-04", 0], ["F1-05", 0], ["F1-U1", 0],
		["F1-U2", 0], ["F1-U3", 0], ["F1-06", 0], ["F1-07", 0]]
	for step: Array in route1:
		check_eq(rm.current_room_id, step[0], "in %s" % step[0])
		await _clear_room(m, step[1])
	check_eq(rm.current_room_id, "F1-08", "reached the Goblin Brute")
	await _beat_boss(m)
	check(screen.visible, "Floor 1 complete")
	(screen.get_node("%ContinueButton") as Button).pressed.emit()
	await frames(2)
	# Floor 2 by the lower path, cutting across to the middle.
	var route2 := [["F2-01", 0], ["F2-02", 2], ["F2-D1", 0], ["F2-D2", 0], ["F2-M2", 0], ["F2-U2", 0],
		["F2-U3", 0], ["F2-U4", 0], ["F2-06", 0], ["F2-07", 0]]
	for step: Array in route2:
		check_eq(rm.current_room_id, step[0], "in %s" % step[0])
		await _clear_room(m, step[1])
	check_eq(rm.current_room_id, "F2-08", "reached the Mutating Slime")
	await _beat_boss(m)
	check(screen.visible, "Floor 2 complete")
	check(GameManager.is_floor_completed(1) and GameManager.is_floor_completed(2), "both floors completed")
	check(GameManager.is_unlocked(GameManager.EXPLOSIVE_KICK) and GameManager.is_unlocked(GameManager.AREA_BURST),
		"both specials unlocked")
	SaveManager.reload()
	GameManager.load_progress()
	check_eq(GameManager.continue_floor(), 2, "Continue offers Floor 2 after a reload")
	get_tree().paused = false
	GameManager.floor_number = 1
	SaveManager.delete_save()
	GameManager.reset_progress()


# --- Milestone 9: switching matters -------------------------------------------

func spawn_scene(w: Node2D, scene: PackedScene, pos: Vector2, ai := false) -> EnemyBase:
	var e := scene.instantiate() as EnemyBase
	e.position = pos
	e.ai_enabled = ai
	w.add_child(e)
	return e


func test_shield_goblin() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_scene(w, SHIELD_GOBLIN_SCENE, Vector2(40, -20)) as ShieldGoblin
	g.facing = -1  # shield toward the player
	await frames(5)
	check_eq(g.weakness(), EnemyBase.Weakness.MAGIC, "shows the magic weakness")
	var resisted := [0]
	g.resisted.connect(func(_e: EnemyBase, _h: Hit) -> void: resisted[0] += 1)
	p.combat.kick_combo.press()
	await frames(20)
	check_eq(g.health, g.max_health, "front kick blocked")
	check_eq(resisted[0], 1, "resisted signal")
	check(Audio.history.has("block"), "clank sound")
	g.take_hit(Hit.new(12.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check_eq(g.health, g.max_health - 12.0, "magic gets through")
	g.facing = 1  # turned away: kicks from behind land
	g.take_hit(Hit.new(10.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check_eq(g.health, g.max_health - 22.0, "kick from behind lands")
	g.facing = -1
	g.take_hit(Hit.new(20.0, Vector2.ZERO, p, PackedStringArray(["explosion", "kick", "heavy"])))
	check_eq(g.health, g.max_health - 42.0, "explosions ignore the shield")


func test_armored_slime() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var s := spawn_scene(w, ARMORED_SLIME_SCENE, Vector2(60, -13)) as ArmoredSlime
	await frames(5)
	check_eq(s.weakness(), EnemyBase.Weakness.KICKS, "shelled: weak to kicks")
	s.take_hit(Hit.new(12.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check_eq(s.health, s.max_health, "magic splashes off the shell")
	s.take_hit(Hit.new(10.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check_eq(s.health, s.max_health - 5.0, "light kicks are halved")
	check(s.shelled, "light kick doesn't crack it")
	var cracked := [0]
	GameManager.shell_cracked.connect(func(_e: EnemyBase) -> void: cracked[0] += 1, CONNECT_ONE_SHOT)
	s.take_hit(Hit.new(20.0, Vector2.ZERO, p, PackedStringArray(["kick", "heavy"])))
	check(not s.shelled, "heavy kick cracks the shell")
	check_eq(cracked[0], 1, "shell_cracked emitted")
	check_eq(s.health, s.max_health - 25.0, "heavy kick does full damage")
	check_eq(s.weakness(), EnemyBase.Weakness.MAGIC, "cracked: weak to magic")
	s.take_hit(Hit.new(10.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check_eq(s.health, s.max_health - 40.0, "magic deals 1.5x once cracked")


func test_bat_dive() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	p.health._invuln = 0.0
	var b := spawn_scene(w, BAT_SCENE, Vector2(150, -150), true) as Bat
	var start_y := b.global_position.y
	await frames(secs(0.5))
	check(b.is_engaged, "bat spotted the player")
	check(absf(b.global_position.y - start_y) < 80.0 and b.global_position.y < -80.0, "bat stays airborne (y=%.0f)" % b.global_position.y)
	var saw_windup := [false]
	var hurt := [false]
	p.health.damaged.connect(func(_a: float) -> void: hurt[0] = true)
	for i in secs(5.0):
		await get_tree().physics_frame
		if b.state == Bat.State.WINDUP:
			saw_windup[0] = true
		if hurt[0]:
			break
	check(saw_windup[0], "dive was telegraphed")
	check(hurt[0], "dive hit the player")
	b.take_hit(Hit.new(999.0))
	await frames(secs(0.4))
	check(b.global_position.y > start_y, "dead bat falls")


func test_bolts_seek_bats() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var b := spawn_scene(w, BAT_SCENE, Vector2(220, -110)) as Bat
	await frames(3)
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(secs(0.8))
	check(b.health < b.max_health, "the bolt curved up into the bat (hp %.0f)" % b.health)


func test_juggle() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(5)
	var juggles := [0]
	var cb := func(_e: EnemyBase) -> void: juggles[0] += 1
	GameManager.enemy_juggled.connect(cb)
	g.take_hit(Hit.new(10.0, Vector2(300, -300), p, PackedStringArray(["kick", "heavy", "charged"])))
	check(g.launched, "heavy kick launches")
	await frames(4)
	check(g.is_juggled(), "airborne and juggleable")
	var before := g.health
	g.take_hit(Hit.new(12.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check_eq(before - g.health, 24.0, "magic deals double")
	check_eq(juggles[0], 1, "juggle reported")
	await frames(secs(1.2))
	check(not g.is_juggled(), "landing ends the juggle")
	before = g.health
	g.take_hit(Hit.new(12.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check_eq(before - g.health, 12.0, "normal damage on the ground")
	GameManager.enemy_juggled.disconnect(cb)
	# Real flow: Main's Dungeon AI awards Juggler.
	var m := spawn_main()
	var mp := player_of(m)
	var ai: DungeonAIManager = m.get("dungeon_ai")
	await frames(2)
	var g2 := spawn_goblin(rooms_of(m).current_room, mp.position.x + 60.0)
	g2.global_position.y = mp.global_position.y
	await frames(3)
	g2.take_hit(Hit.new(5.0, Vector2(200, -300), mp, PackedStringArray(["kick", "heavy"])))
	await frames(4)
	g2.take_hit(Hit.new(5.0, Vector2.ZERO, mp, PackedStringArray(["magic"])))
	check(ai.history.has(DungeonAIManager.JUGGLER), "Juggler achievement")
	check(mp.upgrades.boost(PlayerUpgrades.BOOST_DAMAGE) > 0.0, "damage boost granted")


func test_new_enemy_letters() -> void:
	var w := world()
	var room := RoomBase.new()
	room.room_type = RoomBase.RoomType.COMBAT
	room.layout = "##########\n#........#\n#E.h.a.v.#\n##########"
	w.add_child(room)
	var kinds := {}
	for e in room.required_enemies:
		kinds[e.get_script().get_global_name()] = true
	check(kinds.has("ShieldGoblin") and kinds.has("ArmoredSlime") and kinds.has("Bat"), "h, a and v spawn (%s)" % [kinds.keys()])
	check_eq(room.required_enemies.size(), 3, "all three are required kills")


func test_sign_prompts() -> void:
	Settings.using_controller = false
	var keyboard := Settings.format_prompts("{jump} jumps, {switch_mode} switches")
	check_eq(keyboard, "%s jumps, %s switches" % [Settings.key_label("jump"), Settings.key_label("switch_mode")], "keyboard keys")
	Settings.using_controller = true
	var pad := Settings.format_prompts("{jump} jumps")
	check_eq(pad, "%s jumps" % Settings.prompt_label("jump"), "controller button")
	check(pad != keyboard.split(",")[0], "differs from the keyboard prompt")
	Settings.using_controller = false
	check_eq(Settings.format_prompts("{not_an_action} stays"), "{not_an_action} stays", "unknown tokens are left alone")


# --- Milestone 10: behaviour upgrades ------------------------------------------

func upgrade_of(kind: Upgrade.Kind) -> Upgrade:
	for u in PlayerUpgrades.POOL:
		if u.kind == kind:
			return u
	return null


func test_upgrade_rarity_roll() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(2)
	var counts := [0, 0, 0]
	for i in 400:
		for u in p.upgrades.roll(1):
			counts[u.rarity] += 1
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > 0, "commons > rares > epics > 0 (%s)" % [counts])
	for u in PlayerUpgrades.POOL:
		check(u.title != "" and u.description() != "", "%s has a name and description" % u.title)
		check_eq(u.is_stackable(), u.rarity == Upgrade.Rarity.COMMON, "%s: only commons stack" % u.title)
	var pierce := upgrade_of(Upgrade.Kind.PIERCING_BOLTS)
	p.upgrades.apply(pierce)
	for i in 50:
		check(not p.upgrades.roll(3).has(pierce), "owned behaviour upgrade isn't offered again")
	var kick := upgrade_of(Upgrade.Kind.KICK_DAMAGE)
	p.upgrades.apply(kick)
	check_eq(p.upgrades.roll(100).has(kick), true, "commons can be offered again")
	for u in p.upgrades.roll(3, Upgrade.Rarity.RARE):
		check(u.rarity >= Upgrade.Rarity.RARE, "min rarity roll")


func test_upgrade_piercing() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g1 := spawn_goblin(w, 80.0)
	var g2 := spawn_goblin(w, 160.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.PIERCING_BOLTS))
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(secs(0.6))
	check_eq(g1.health, 38.0, "first goblin hit")
	check_eq(g2.health, 38.0, "second goblin hit by the same bolt")


func test_upgrade_twin_bolts() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.TWIN_BOLTS))
	p.combat.request_switch()
	p.combat.magic_missile.press()
	await frames(6)
	check_eq(bolts(), 2, "two bolts in the air")


func test_upgrade_kick_wave() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var far := spawn_goblin(w, 200.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.KICK_WAVE))
	for i in 3:
		p.combat.kick_combo.press()
		await frames(20)
	await frames(secs(0.5))
	check_eq(far.health, 50.0 - 14.0, "shockwave reached the far goblin")


func test_upgrade_fire_dodge() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 60.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.FIRE_DODGE))
	p.try_dodge(1.0)
	await frames(secs(1.0))
	check(g.health < 50.0, "fire burned the goblin (hp %.0f)" % g.health)
	await frames(secs(1.5))
	var trails := 0
	for c in w.get_children():
		if c is FireTrail:
			trails += 1
	check_eq(trails, 0, "the fire dies down")


func test_upgrade_potion_burst() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 70.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.POTION_BURST))
	set_health(p, 50.0)
	check(p.potions.use(), "drank")
	await frames(2)
	check_eq(g.health, 30.0, "burst hit the goblin for 20")


func test_upgrade_frenzy() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.SWITCH_FRENZY))
	check_eq(p.combat.magic_damage_multiplier, 1.0, "no bonus before switching")
	p.combat.request_switch()
	check_eq(p.combat.magic_damage_multiplier, 1.5, "+50% after a switch")
	check_eq(p.combat.kick_damage_multiplier, 1.5, "kicks too")
	await frames(secs(1.6))
	check_eq(p.combat.magic_damage_multiplier, 1.0, "bonus wears off")


func test_upgrade_tag_team() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.TAG_TEAM))
	p.combat.charged_blast.cooldown_remaining = 2.0
	p.combat.magic_missile.cooldown_remaining = 2.0
	p.combat.request_switch()
	check_eq(p.combat.charged_blast.cooldown_remaining, 0.0, "blast ready")
	check_eq(p.combat.magic_missile.cooldown_remaining, 0.0, "missile ready")


func test_upgrade_kill_effects() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 60.0)
	var near := spawn_goblin(w, 100.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.LIFESTEAL))
	p.upgrades.apply(upgrade_of(Upgrade.Kind.VOLATILE))
	set_health(p, 50.0)
	g.take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	await frames(3)
	check_eq(p.health.current, 54.0, "lifesteal healed 4")
	check_eq(near.health, 35.0, "the corpse exploded for 15")
	var bystander := spawn_goblin(w, 400.0)
	near.take_hit(Hit.new(999.0))  # not the player's kill
	await frames(3)
	check_eq(p.health.current, 54.0, "no lifesteal for other kills")
	check_eq(bystander.health, 50.0, "no explosion for other kills")


func test_upgrade_juggle_master() -> void:
	var w := world()
	var p := spawn_player(w, 0.0)
	var g := spawn_goblin(w, 40.0)
	await frames(3)
	p.upgrades.apply(upgrade_of(Upgrade.Kind.JUGGLE_MASTER))
	g.take_hit(Hit.new(1.0, Vector2(200, -300), p, PackedStringArray(["kick", "heavy"])))
	await frames(4)
	var before := g.health
	g.take_hit(Hit.new(10.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check_eq(before - g.health, 30.0, "x3 juggle")
	p.upgrades.clear()
	check_eq(p.combat.juggle_multiplier, 2.0, "back to x2 after clearing")


func test_upgrade_cards_rarity() -> void:
	var m := spawn_main()
	await frames(2)
	var screen: UpgradeSelectionScreen = m.get("upgrade_selection")
	screen.show_choices([upgrade_of(Upgrade.Kind.KICK_DAMAGE), upgrade_of(Upgrade.Kind.PIERCING_BOLTS), upgrade_of(Upgrade.Kind.VOLATILE)])
	var texts: Array[String] = []
	for card in screen.cards():
		for label in card.find_children("", "Label", true, false):
			texts.append((label as Label).text)
	check(texts.has("COMMON") and texts.has("RARE") and texts.has("EPIC"), "rarity labels (%s)" % [texts])
	screen.choose(screen.choices[0])


# --- Milestone 11: Dungeon AI loop -----------------------------------------------

func stats_of(m: Node) -> RunStats:
	return m.get("run_stats")


func test_achievement_rewards() -> void:
	check(Achievements.ids().size() >= 20, "at least 20 achievements (%d)" % Achievements.ids().size())
	for id: StringName in Achievements.ids():
		check(Achievements.display_name(id) != "" and Achievements.hint(id) != "", "%s has a name and hint" % id)
	var m := spawn_main()
	var ai := ai_of(m)
	var stats := stats_of(m)
	await frames(2)
	var before := stats.viewers
	check(ai.award(&"overkill", {"title": "T", "description": "D"}), "awarded")
	check_eq(stats.boxes, [Achievements.Tier.BRONZE] as Array[int], "bronze box")
	check_eq(stats.viewers - before, Achievements.TIER_VIEWERS[Achievements.Tier.BRONZE], "viewers for the tier")
	check(GameManager.has_achievement(&"overkill"), "recorded in the profile")
	check(not ai.award(&"overkill", {"title": "T", "description": "D"}), "once per encounter")
	var hud: HUD = m.get("hud")
	check(String(hud.achievement_panel.current.get("reward", "")).contains("Bronze loot box"), "announcement names the box")
	check(hud.viewers_label.text.contains("LOOT BOXES 1"), "HUD shows waiting boxes (%s)" % hud.viewers_label.text)


func test_achievement_per_floor() -> void:
	var m := spawn_main()
	var ai := ai_of(m)
	var rm := rooms_of(m)
	await frames(2)
	check(ai.award(&"hoarder", {"title": "T", "description": "D"}), "first time")
	rm.load_room("F1-02")
	check(not ai.award(&"hoarder", {"title": "T", "description": "D"}), "not again in another room")
	ai.reset()
	check(ai.award(&"hoarder", {"title": "T", "description": "D"}), "again on a new floor run")


func test_kill_achievements() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var room := rooms_of(m).current_room
	await frames(2)
	var gs: Array[Goblin] = []
	for i in 6:
		var g := spawn_goblin(room, 300.0 + i * 40.0)
		gs.append(g)
	await frames(2)
	gs[0].take_hit(Hit.new(50.0, Vector2.ZERO, p, PackedStringArray(["kick", "heavy"])))
	check(ai.history.has(&"overkill"), "overkill for 50 damage")
	check(ai.history.has(&"first_blood"), "first blood")
	check(not ai.history.has(&"triple_kill"), "no triple yet")
	gs[1].take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	gs[2].take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check(ai.history.has(&"triple_kill"), "three kills in a moment")
	gs[3].take_hit(Hit.new(999.0, Vector2.ZERO, null, PackedStringArray(["explosion", "hazard"])))
	gs[4].take_hit(Hit.new(999.0, Vector2.ZERO, null, PackedStringArray(["explosion", "hazard"])))
	check(ai.history.has(&"chain_reaction"), "two explosion kills at once")
	gs[5].take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["fire"])))
	check(ai.history.has(&"spicy"), "fire kill")


func test_enemy_achievements() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var room := rooms_of(m).current_room
	await frames(2)
	var sg := spawn_scene(room, SHIELD_GOBLIN_SCENE, Vector2(400, p.global_position.y)) as ShieldGoblin
	sg.facing = 1 if p.global_position.x > sg.global_position.x else -1
	sg.facing = -sg.facing  # back to the player
	sg.take_hit(Hit.new(10.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check(ai.history.has(&"what_shield"), "kick from behind")
	var bat := spawn_scene(room, BAT_SCENE, Vector2(500, p.global_position.y - 100)) as Bat
	bat.take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check(ai.history.has(&"bat_swatter"), "kicked a bat to death")
	var sl := spawn_scene(room, ARMORED_SLIME_SCENE, Vector2(600, p.global_position.y)) as ArmoredSlime
	sl.crack()
	check(ai.history.has(&"shell_shocked"), "cracked a shell")
	var g := spawn_goblin(room, 650.0)
	g.take_hit(Hit.new(999.0, Vector2.ZERO, p, PackedStringArray(["magic"])))
	check(ai.history.has(&"dynamic_duo"), "kick and magic kills in one room")


func test_room_achievements() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var ai := ai_of(m)
	var rm := rooms_of(m)
	await frames(2)
	var room := rm.load_room("F1-02")
	set_health(p, 10.0)
	kill_required(room)
	await frames(2)
	check(ai.history.has(&"close_call"), "cleared at 10% health")
	p.potions.reset(9)
	p.potions.add()
	check(ai.history.has(&"hoarder"), "ten potions")
	set_health(p, 100.0)
	p.health._invuln = 99.0
	for i in 3:
		p.global_position.y = rm.current_room.bounds.end.y + 100.0
		await frames(2)
	check(ai.history.has(&"pit_diver"), "three falls")
	GameManager.wall_broken.emit()
	check(ai.history.has(&"wall_breaker"), "broke a wall")


func test_boss_achievements() -> void:
	var m := spawn_main()
	var ai := ai_of(m)
	var rm := rooms_of(m)
	await frames(2)
	rm.load_room("F1-08")
	await _beat_boss(m)
	check(ai.history.has(&"speed_boss"), "boss beaten quickly")
	check(ai.history.has(&"sober"), "no potions drunk")
	check(ai.history.has(&"deathless"), "no deaths")


func test_viewers() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var stats := stats_of(m)
	var rm := rooms_of(m)
	await frames(2)
	var room := rm.load_room("F1-05")
	await frames(1)
	ai_of(m).reset()
	ai_of(m).award(&"first_blood", {"title": "", "description": ""})  # keep it out of the count
	var start := stats.viewers
	var gs := room.required_enemies.duplicate()
	gs[0].take_hit(Hit.new(30.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	gs[0].take_hit(Hit.new(30.0, Vector2.ZERO, p, PackedStringArray(["kick"])))
	check_eq(stats.viewers - start, RunStats.KILL_VIEWERS, "plain kill")
	start = stats.viewers
	gs[1].take_hit(Hit.new(999.0, Vector2.ZERO, null, PackedStringArray(["hazard", "spikes"])))
	var style := RunStats.KILL_VIEWERS + RunStats.STYLE_VIEWERS
	check(stats.viewers - start >= style, "style kill pays more (%d)" % (stats.viewers - start))
	check_eq(stats.kills, 2, "kills counted")
	start = stats.viewers
	stats.viewer_multiplier = 2.0
	stats.add_viewers(10)
	check_eq(stats.viewers - start, 20, "modifiers multiply viewers")
	stats.viewer_multiplier = 1.0
	start = stats.viewers
	for e in room.required_enemies.duplicate():
		if not e.is_dead:
			e.take_hit(Hit.new(999.0))
	check(stats.viewers - start >= RunStats.ROOM_CLEAR_VIEWERS, "room clear pays out")


func test_grades() -> void:
	var stats := RunStats.new()
	add_child(stats)
	stats.reset(1)
	stats.viewers = 1700
	check_eq(stats.grade(), "S", "S for a big deathless run")
	stats.deaths = 1
	check_eq(stats.grade(), "A", "a death drops S")
	stats.deaths = 0
	stats.viewers = 900
	check_eq(stats.grade(), "B", "B around par")
	stats.viewers = 100
	check_eq(stats.grade(), "D", "D for a quiet run")
	check_eq(RunStats.format_time(125.0), "2:05", "time format")


func test_loot_boxes() -> void:
	GameManager.reset_profile()
	var m := spawn_main()
	var p := player_of(m)
	var stats := stats_of(m)
	var loot: LootBoxScreen = m.get("loot_screen")
	var picks: UpgradeSelectionScreen = m.get("upgrade_selection")
	var rm := rooms_of(m)
	await frames(2)
	var room := rm.load_room("F1-03")
	await frames(1)
	check_eq(room.fountain.prompt(), "Drink from fountain", "no boxes: the fountain heals")
	stats.add_box(Achievements.Tier.SILVER)
	stats.add_box(Achievements.Tier.GOLD)
	check_eq(room.fountain.prompt(), "Open 2 loot boxes", "boxes waiting")
	p.potions.reset(3)
	check(room.fountain.interact(), "fountain opens the boxes")
	check(loot.is_open() and get_tree().paused, "loot screen pauses")
	check(not room.fountain.dry, "the fountain's heal is still there")
	loot.advance()  # open silver
	check_eq(p.upgrades.active.size(), 1, "silver gave a stat upgrade")
	check_eq(p.potions.count, 4, "and a potion")
	loot.advance()  # next
	loot.advance()  # open gold
	check_eq(GameManager.owned_hats.size(), 1, "gold gave a hat")
	check(GameManager.equipped_hat != "", "and Carl wears it")
	loot.advance()  # done
	await frames(1)
	check(not loot.is_open(), "loot screen closed")
	check(picks.visible, "gold box offers an upgrade choice")
	for c in picks.choices:
		check(c.rarity >= Upgrade.Rarity.RARE, "rare or better (%s)" % c.title)
	picks.cards()[0].pressed.emit()
	await frames(1)
	check(not get_tree().paused, "game resumes")
	check_eq(stats.boxes.size(), 0, "boxes used up")
	check_eq(room.fountain.prompt(), "Drink from fountain", "back to healing")
	# Bronze: a potion or viewers.
	var main_script: Variant = m
	var text: String = main_script.open_loot_box(Achievements.Tier.BRONZE)
	check(text != "", "bronze reward described")


func test_loot_carry_over() -> void:
	var m := spawn_main()
	var stats := stats_of(m)
	await frames(2)
	stats.add_box(Achievements.Tier.BRONZE)
	stats.add_viewers(500)
	m.continue_to_next_floor()
	await frames(2)
	check_eq(stats.boxes.size(), 1, "box kept on the next floor")
	check_eq(stats.viewers, 0, "viewers start again")
	m.restart_floor()
	check_eq(stats.boxes.size(), 0, "restarting a floor drops boxes")
	GameManager.floor_number = 1


func test_run_summary() -> void:
	GameManager.reset_profile()
	var m := spawn_main()
	var stats := stats_of(m)
	var rm := rooms_of(m)
	var screen: FloorCompleteScreen = m.get("floor_complete")
	await frames(2)
	rm.load_room("F1-08")
	await _beat_boss(m)
	check(screen.visible, "floor complete")
	var body: String = (screen.get_node("%Body") as Label).text
	check(body.contains("GRADE") and body.contains("Viewers") and body.contains("NEW BEST"), "summary shown")
	check_eq(int(GameManager.best_run(1).get("viewers", -1)), stats.viewers, "best run saved")
	get_tree().paused = false


func test_profile_persists() -> void:
	GameManager.reset_profile()
	GameManager.record_achievement(&"juggler")
	var rng := RandomNumberGenerator.new()
	var hat := GameManager.unlock_random_hat(rng)
	GameManager.record_run({"floor": 2, "viewers": 1234, "time": 300.0, "grade": "A"})
	check(not GameManager.record_run({"floor": 2, "viewers": 10, "time": 30.0, "grade": "D"}), "worse run isn't saved")
	SaveManager.reload()
	GameManager.load_profile()
	check(GameManager.has_achievement(&"juggler"), "achievement reloaded")
	check(GameManager.owned_hats.has(hat) and GameManager.equipped_hat == hat, "hat reloaded")
	check_eq(int(GameManager.best_run(2)["viewers"]), 1234, "best run reloaded")
	GameManager.new_game()
	GameManager.load_profile()
	check(GameManager.has_achievement(&"juggler"), "New Game keeps achievements")
	GameManager.reset_progress()
	GameManager.reset_profile()


func test_extras_menu() -> void:
	GameManager.reset_profile()
	GameManager.record_achievement(&"juggler")
	GameManager.unlock_random_hat(RandomNumberGenerator.new())
	var menu := MENU_SCENE.instantiate() as MainMenu
	menu.navigate = false
	add_child(menu)
	await frames(1)
	menu.extras_button.pressed.emit()
	await frames(1)
	check(menu.is_extras_open(), "extras open")
	var texts: Array[String] = []
	for l in menu.find_children("", "Label", true, false):
		texts.append((l as Label).text)
	check(texts.has("Juggler"), "earned achievement named")
	check(texts.has("???"), "locked ones hidden")
	var hat_names := 0
	for b in menu.find_children("", "Button", true, false):
		if GameManager.HATS.values().has((b as Button).text):
			hat_names += 1
	check_eq(hat_names, 1, "one hat to wear")
	GameManager.reset_profile()


# --- Milestone 12: replayability ---------------------------------------------------

func test_room_variants() -> void:
	var with_variants := 0
	for f in [1, 2]:
		for id: String in FloorData.room_ids(f):
			if FloorData.room_scene_paths(f, id).size() > 1:
				with_variants += 1
	check(with_variants >= 8, "most combat rooms have a variant (%d)" % with_variants)
	var rm := RoomManager.new()
	add_child(rm)
	var seen := {}
	for i in 30:
		rm.room_variants.clear()
		rm.rng.randomize()
		# start_floor needs a player; just repeat its picking logic via a seeded run.
		rm.rng.seed = i
		for id: String in FloorData.room_ids(1):
			var paths := FloorData.room_scene_paths(1, id)
			rm.room_variants[id] = paths[rm.rng.randi_range(0, paths.size() - 1)]
		seen[rm.room_variants["F1-07"]] = true
	check_eq(seen.size(), 2, "both F1-07 layouts come up")
	rm.queue_free()
	# A real floor start with a fixed seed is repeatable.
	var m := spawn_main()
	var mrm := rooms_of(m)
	mrm.start_floor(1, 1234)
	var first := mrm.room_variants.duplicate()
	mrm.start_floor(1, 1234)
	check_eq(mrm.room_variants, first, "same seed, same rooms")
	var differs := false
	for s in 10:
		mrm.start_floor(1, 99 + s)
		if mrm.room_variants != first:
			differs = true
	check(differs, "other seeds pick other rooms")
	mrm.room_variants["F1-07"] = "res://scenes/rooms/floor1/F1_07_Combat_B.tscn"
	var room := mrm.load_room("F1-07")
	check_eq(room.display_name, "Last Stand Pits", "variant loaded")
	check_eq(Array(room.exits), ["F1-08"], "same exits")


func test_random_spawns() -> void:
	var w := world()
	var kinds := {}
	for seed_value in 40:
		var room := RoomBase.new()
		room.room_type = RoomBase.RoomType.COMBAT
		room.enemy_pool = ["s", "a", "v"]
		room.spawn_seed = seed_value
		room.layout = "##########\n#........#\n#E.?.?...#\n##########"
		w.add_child(room)
		for e in room.required_enemies:
			kinds[e.get_script().get_global_name()] = true
		check_eq(room.required_enemies.size(), 2, "two ? markers spawn two enemies")
		room.free()
	check(kinds.has("Slime") and kinds.has("ArmoredSlime") and kinds.has("Bat") and not kinds.has("Goblin"),
		"pool respected (%s)" % [kinds.keys()])
	var a := RoomBase.new()
	a.room_type = RoomBase.RoomType.COMBAT
	a.enemy_pool = ["g", "s", "a", "v", "h"]
	a.spawn_seed = 7
	a.layout = "##########\n#........#\n#E?????..#\n##########"
	var b := a.duplicate() as RoomBase
	b.enemy_pool = a.enemy_pool
	b.spawn_seed = 7
	w.add_child(a)
	w.add_child(b)
	var names_a := a.required_enemies.map(func(e: EnemyBase) -> String: return e.get_script().get_global_name())
	var names_b := b.required_enemies.map(func(e: EnemyBase) -> String: return e.get_script().get_global_name())
	check_eq(names_a, names_b, "same seed spawns the same enemies")


func test_sponsor_events() -> void:
	GameManager.reset_progress()
	var m := spawn_main()
	var rm := rooms_of(m)
	m.restart_floor()
	check(rm.modifiers.is_empty(), "first run of an unbeaten floor: no sponsor event")
	GameManager.completed_floors.append(1)
	m.restart_floor()
	check_eq(rm.modifiers.size(), 1, "replay of a beaten floor: one event")
	var stats := stats_of(m)
	check(stats.viewer_multiplier > 1.0, "events multiply viewers")
	var hud: HUD = m.get("hud")
	check(hud.modifiers_label.text.begins_with("SPONSORED"), "HUD names the event")
	GameManager.reset_progress()


func test_modifier_effects() -> void:
	var g := GOBLIN_SCENE.instantiate() as Goblin
	var speed := g.chase_speed
	var mods: Array[StringName] = [Modifiers.HASTY, Modifiers.BEEFY, Modifiers.DRY]
	Modifiers.apply_to_enemy(g, mods, false)
	check_eq(g.chase_speed, speed * Modifiers.HASTE, "hasty: faster")
	check_eq(g.max_health, 50.0 * Modifiers.BEEF, "beefy: more health")
	check_eq(g.potion_drop_chance, 0.0, "dry spell: no potions")
	g.free()
	var h := GOBLIN_SCENE.instantiate() as Goblin
	Modifiers.apply_to_enemy(h, [] as Array[StringName], true)
	check_eq(h.max_health, 50.0 * Modifiers.HARD_HEALTH, "hard mode: more health")
	h.free()
	var m := spawn_main()
	var p := player_of(m)
	await frames(2)
	var glass: Array[StringName] = [Modifiers.GLASS]
	m.set_modifiers(glass, false)
	check_eq(p.combat.kick_damage_multiplier, 1.5, "glass cannon: +50% damage dealt")
	p.health._invuln = 0.0
	p.health.take_damage(10.0)
	check_eq(p.health.current, 85.0, "glass cannon: +50% damage taken")
	check_eq(stats_of(m).viewer_multiplier, 1.4, "glass cannon viewers")
	var none: Array[StringName] = []
	m.set_modifiers(none, false)
	check_eq(p.combat.kick_damage_multiplier, 1.0, "cleared")


func test_modifier_explosive() -> void:
	var m := spawn_main()
	var p := player_of(m)
	var room := rooms_of(m).current_room
	await frames(2)
	var boom: Array[StringName] = [Modifiers.EXPLOSIVE]
	m.set_modifiers(boom, false)
	var a := spawn_goblin(room, p.global_position.x + 300.0)
	var b := spawn_goblin(room, p.global_position.x + 340.0)
	a.global_position.y = p.global_position.y
	b.global_position.y = p.global_position.y
	await frames(2)
	a.take_hit(Hit.new(999.0))
	await frames(3)
	check_eq(b.health, 50.0 - Modifiers.EXPLOSION_ENEMY_DAMAGE, "neighbour caught in the blast")


func test_hard_mode() -> void:
	GameManager.reset_progress()
	GameManager.set_hard_mode(true)
	check(not GameManager.hard_mode, "locked before beating Floor 2")
	GameManager.completed_floors.append(2)
	GameManager.set_hard_mode(true)
	check(GameManager.hard_mode, "on")
	SaveManager.reload()
	GameManager.load_progress()
	check(GameManager.hard_mode, "persists")
	var m := spawn_main()
	m.restart_floor()
	var rm := rooms_of(m)
	check(rm.hard_mode, "rooms get hard mode")
	check_eq(rm.modifiers.size(), 1, "plus a sponsor event")
	check_eq(player_of(m).health.incoming_multiplier, Modifiers.damage_taken_multiplier(rm.modifiers, true), "harder hits")
	check(player_of(m).health.incoming_multiplier >= Modifiers.HARD_DAMAGE_TAKEN, "at least the hard mode factor")
	var menu := MENU_SCENE.instantiate() as MainMenu
	menu.navigate = false
	add_child(menu)
	await frames(1)
	check(menu.hard_mode_toggle.visible and menu.hard_mode_toggle.button_pressed, "menu toggle shows it")
	GameManager.reset_progress()
	GameManager.save_progress()


func test_daily_run() -> void:
	GameManager.reset_progress()
	GameManager.completed_floors.append(1)
	var menu := MENU_SCENE.instantiate() as MainMenu
	menu.navigate = false
	add_child(menu)
	await frames(1)
	check(menu.daily_button.visible, "daily run offered after Floor 1")
	menu.daily_button.pressed.emit()
	check(GameManager.daily_run and GameManager.floor_number == 1, "daily run starts Floor 1")
	var m := MAIN_SCENE.instantiate()
	m.set("debug_keys", false)
	m.set("navigate", false)
	add_child(m)
	await frames(1)
	var rm := rooms_of(m)
	check_eq(rm.modifiers.size(), 2, "two sponsor events")
	var mods := rm.modifiers.duplicate()
	var variants := rm.room_variants.duplicate()
	m.restart_floor()
	check_eq(rm.modifiers, mods, "same events on a retry")
	check_eq(rm.room_variants, variants, "same rooms on a retry")
	check(GameManager.record_daily(GameManager.today(), 500), "daily best saved")
	check(not GameManager.record_daily(GameManager.today(), 100), "lower score isn't")
	GameManager.daily_run = false
	GameManager.reset_progress()
	GameManager.reset_profile()
