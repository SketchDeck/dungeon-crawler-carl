extends Node
## Headless test runner scene: godot --headless --path . tests/TestRunner.tscn
## Exits with code 1 if any check fails.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const GOBLIN_SCENE := preload("res://scenes/enemies/Goblin.tscn")

var _passed := 0
var _failed := 0
var _current := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Fx.hitstop_enabled = false
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
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Harness ----------------------------------------------------------------

func _test(name: String, fn: Callable) -> void:
	_current = name
	var before := _failed
	await fn.call()
	print("%s  %s" % ["PASS" if _failed == before else "FAIL", name])
	for child in get_children():
		if child.name.begins_with("TestWorld"):
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
