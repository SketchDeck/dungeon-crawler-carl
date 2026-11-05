class_name EnemyBase
extends CharacterBody2D
## Shared enemy logic: health, hit reactions, knockback stun, engagement with combat state,
## potion drops, death, and enemy-to-enemy collision damage. Subclasses override _think()
## for their behaviour and _draw_body() for their look.

signal died(enemy: EnemyBase)

var max_hp: int = 30
var hp_state: HealthState
var facing: int = -1
var engaged: bool = false
var dead: bool = false
var stun_time: float = 0.0
var hit_flash: float = 0.0
var base_color: Color = Color("#7bd36b")
var drop_chance: float = Config.POTION_DROP_CHANCE

var _t: float = 0.0
var _lost_timer: float = 0.0
var _player: Player = null
var _collision_cd: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Config.LAYER_ENEMY
	collision_mask = Config.LAYER_WORLD
	_rng.randomize()


func display_name() -> String:
	return "Enemy"


func setup_health(hp: int) -> void:
	max_hp = hp
	hp_state = HealthState.new(hp)
	hp_state.max_hp = hp
	hp_state.hp = hp


## Called by any attack. Returns true when the hit landed.
func receive_hit(hit: HitInfo) -> bool:
	if dead or hp_state == null:
		return false
	var dealt := hp_state.take_damage(hit.amount, 0.0)
	if dealt <= 0:
		return false
	hit_flash = 0.12
	stun_time = clampf(0.14 + hit.knockback.length() / 1800.0, 0.14, 0.45)
	if hit.knockback != Vector2.ZERO:
		velocity.x = hit.knockback.x
		velocity.y = minf(velocity.y, hit.knockback.y)
		facing = -1 if hit.knockback.x > 0.0 else 1
	Sfx.play("kick_heavy" if hit.charged else "hit")
	var color := _hit_color(hit)
	Fx.burst(global_position + Vector2(0.0, -6.0), color, 10 if not hit.charged else 18, 220.0, 0.4)
	Fx.text(global_position + Vector2(0.0, -34.0), str(dealt), color, 16 if not hit.charged else 22)
	if hit.charged:
		Fx.shake(4.0)
		Fx.hitstop(0.04, 0.12)
	elif hit.from_player:
		Fx.hitstop(0.025, 0.25)
	if hit.from_player:
		engaged = true
		CombatState.engage(self)
	_on_hurt(hit)
	if not hp_state.is_alive():
		_die(hit)
	return true


func _hit_color(hit: HitInfo) -> Color:
	if hit.environmental:
		return Color("#c8d0dc")
	if hit.kind.begins_with("explo") or hit.kind == "explosion":
		return Color("#ff9a3c")
	if hit.kind in ["magic", "blast", "burst"]:
		return Color("#c79bff")
	if hit.charged:
		return Color("#ffb347")
	return Color("#ffe27a")


## Override for reactions such as telegraph cancellation.
func _on_hurt(_hit: HitInfo) -> void:
	pass


## Default loot: a configurable chance of one health potion.
func _drop_loot() -> void:
	if PotionInventory.roll_drop(_rng, drop_chance):
		PotionPickup.spawn(get_parent(), global_position + Vector2(0.0, -10.0))


func _die(hit: HitInfo) -> void:
	if dead:
		return
	dead = true
	engaged = false
	CombatState.disengage(self)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	if hit.environmental:
		DungeonAI.on_environment_kill()
	Sfx.play("enemy_die")
	var burst_color := base_color.lightened(0.2)
	Fx.burst(global_position + Vector2(0.0, -8.0), burst_color, 30, 360.0, 0.65)
	Fx.ring(global_position, burst_color, 40.0, 0.35, 4.0)
	Fx.shake(6.0)
	Fx.hitstop(0.06, 0.05)
	_drop_loot()
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(self, "scale", Vector2(1.3, 0.2), 0.45)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	stun_time = maxf(0.0, stun_time - delta)
	for key in _collision_cd.keys():
		_collision_cd[key] -= delta
		if _collision_cd[key] <= 0.0:
			_collision_cd.erase(key)

	if not dead and global_position.y > 900.0:
		_fall_out()
		return
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		velocity.y = minf(velocity.y + _gravity * delta, Config.MAX_FALL_SPEED)
		move_and_slide()
		return

	_update_engagement(delta)
	_check_enemy_collisions()
	if stun_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, Config.ENEMY_KNOCKBACK_FRICTION * delta)
	else:
		_think(delta)
	velocity.y = minf(velocity.y + _gravity * delta, Config.MAX_FALL_SPEED)
	move_and_slide()


## Subclasses implement their behaviour here. Only runs when not stunned.
func _think(_delta: float) -> void:
	velocity.x = 0.0


## An enemy that fell out of its room (through a shaft, for instance) is removed quietly. It still
## counts as defeated so the room can clear, but it drops nothing.
func _fall_out() -> void:
	dead = true
	engaged = false
	CombatState.disengage(self)
	remove_from_group("enemies")
	died.emit(self)
	queue_free()


func _find_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


## Engages when the player is close and roughly on the same level; disengages after the player
## has been out of reach for ENEMY_DISENGAGE_TIME seconds.
func _update_engagement(delta: float) -> void:
	var p := _find_player()
	if p == null or not p.alive:
		_set_engaged(false)
		return
	var offset := p.global_position - global_position
	var detected := absf(offset.x) < Config.GOBLIN_DETECT_RANGE and absf(offset.y) < 90.0
	if detected:
		_lost_timer = 0.0
		_set_engaged(true)
	elif engaged:
		_lost_timer += delta
		if _lost_timer >= Config.ENEMY_DISENGAGE_TIME:
			_set_engaged(false)


func _set_engaged(value: bool) -> void:
	if value == engaged:
		return
	engaged = value
	if engaged:
		CombatState.engage(self)
	else:
		CombatState.disengage(self)


## Enemies kicked into each other damage on impact (spec 8). Each pair cools down so one
## continuous collision does not repeat.
func _check_enemy_collisions() -> void:
	if velocity.length() < Config.ENEMY_COLLISION_MIN_SPEED or stun_time <= 0.0:
		return
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is EnemyBase) or other.dead:
			continue
		var key := other.get_instance_id()
		if _collision_cd.has(key):
			continue
		if global_position.distance_to(other.global_position) > 30.0:
			continue
		_collision_cd[key] = 0.6
		var info := HitInfo.make(Config.ENEMY_COLLISION_DAMAGE, Vector2(velocity.x * 0.6, -180.0), self, "collision")
		info.from_player = true
		other.receive_hit(info)
		DungeonAI.on_enemy_collision(self, other)
		Fx.burst((global_position + other.global_position) * 0.5, Color("#ffd27a"), 14, 260.0, 0.4)
		Fx.shake(5.0)


func _draw() -> void:
	if dead:
		_draw_body()
		return
	_draw_body()
	if hp_state != null and hp_state.hp < max_hp:
		var w := 30.0
		var ratio := float(hp_state.hp) / float(max_hp)
		var top := Vector2(-w * 0.5, -40.0)
		draw_rect(Rect2(top + Vector2(-1, -1), Vector2(w + 2, 6)), Color(0.02, 0.02, 0.04, 0.9))
		draw_rect(Rect2(top, Vector2(w * ratio, 4)), Color("#ff5f6d"))


## Subclasses draw their body in local coordinates (origin at the body center).
func _draw_body() -> void:
	pass
