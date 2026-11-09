class_name EnemyBase
extends CharacterBody2D
## Shared enemy health, damage, knockback, engagement and death.
## Subclasses implement _ai(delta) and drawing.

signal damaged(enemy: EnemyBase, amount: float)
signal died(enemy: EnemyBase)
signal engaged_changed(enemy: EnemyBase, is_engaged: bool)
## This enemy was knocked into `other` hard enough to hurt both.
signal collided(enemy: EnemyBase, other: EnemyBase)
## A hit did nothing because of this enemy's defence (shield, shell...).
signal resisted(enemy: EnemyBase, hit: Hit)

## Weakness icons shown over enemies that want a particular combat mode.
enum Weakness { NONE, KICKS, MAGIC }

## Magic hits on a launched (power-kicked, airborne) enemy deal this much more.
const JUGGLE_MULTIPLIER := 2.0
## Kicks with at least this much upward knockback launch an enemy for juggling.
const LAUNCH_MIN_LIFT := 150.0

## Name used in Dungeon AI announcements.
@export var display_name := "Goblin"
@export var max_health := 50.0
@export var body_size := Vector2(26, 40)
@export var gravity := 1500.0
@export var max_fall_speed := 900.0
## Flying enemies ignore gravity (until they die) and recover from knockback in the air.
@export var flying := false
@export_group("Knockback")
@export var knockback_multiplier := 1.0
## Minimum time an enemy stays in knockback (it also waits to land).
@export var knockback_min_time := 0.18
@export var knockback_friction := 1600.0
## While armored (e.g. mid-attack), hits below this damage don't interrupt.
@export var stagger_threshold := 15.0
@export_group("Enemy collisions")
## Knocked-back enemies moving at least this fast damage enemies they hit.
@export var collision_min_speed := 350.0
## Damage to the enemy that gets hit, and to the one that was thrown.
@export var collision_damage := 15.0
@export var collision_self_damage := 8.0
@export_group("Drops")
@export_range(0.0, 1.0) var potion_drop_chance := 0.2
@export_group("")
## Tests disable AI to keep enemies stationary.
@export var ai_enabled := true

var health := 0.0
var is_dead := false
var is_engaged := false
## The most recent hit taken (e.g. to credit a kill to spikes or a barrel).
var last_hit: Hit
var in_knockback := false
var facing := -1

var _knockback_t := 0.0
var _flash_t := 0.0
var _death_t := 0.0
var _player: Player
## Enemies already hit during the current knockback (no repeat damage).
var _collided := {}
var rng := RandomNumberGenerator.new()
## Knocked into the air by a heavy kick: magic hits juggle it for bonus damage.
var launched := false
var _launch_t := 0.0
## Briefly enlarges the weakness icon after a resisted hit.
var _weak_flash := 0.0

const DEATH_DURATION := 0.7
const POTION_SCENE := preload("res://scenes/pickups/PotionPickup.tscn")


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	rng.randomize()


func get_player() -> Player:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func _physics_process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	_weak_flash = maxf(_weak_flash - delta, 0.0)
	if launched:
		_launch_t += delta
		if _launch_t > 0.1 and (is_on_floor() or (flying and not in_knockback)):
			launched = false
	if not is_on_floor() and (not flying or is_dead):
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	if is_dead:
		_death_t += delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
		move_and_slide()
		queue_redraw()
		if _death_t >= DEATH_DURATION:
			queue_free()
		return

	if in_knockback:
		if absf(velocity.x) >= collision_min_speed:
			_check_enemy_collisions()
		_knockback_t -= delta
		if flying:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		if is_on_floor() or flying:
			velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
			if _knockback_t <= 0.0:
				in_knockback = false
				_on_knockback_end()
	elif ai_enabled:
		_ai(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)

	move_and_slide()
	queue_redraw()


func take_hit(hit: Hit) -> void:
	if is_dead:
		return
	var amount := maxf(hit.damage, 0.0)
	var mult := hit_multiplier(hit)
	if mult <= 0.0:
		_resist(hit)
		return
	amount *= mult
	if hit.has_tag("magic") and is_juggled():
		amount *= juggle_multiplier(hit)
		if not hit.has_tag("juggle"):
			var tags := hit.tags
			tags.append("juggle")
			hit.tags = tags
		Fx.text(global_position + Vector2(0, -body_size.y * 0.5 - 30), "JUGGLE!", Color("#ff8af0"), 17)
		GameManager.enemy_juggled.emit(self)
	last_hit = hit
	health = maxf(health - amount, 0.0)
	_flash_t = 0.1
	Audio.play("hit", -3.0)
	damaged.emit(self, amount)
	GameManager.enemy_damaged.emit(self, amount, hit)
	Fx.text(global_position + Vector2(0, -body_size.y * 0.5 - 12), str(roundi(amount)),
		Color("#ffd34d") if hit.has_tag("heavy") else Color.WHITE, 18 if hit.has_tag("heavy") else 15)
	Fx.burst(global_position, Color("#ffe6a0"), 18.0, 0.18)
	set_engaged(true)
	if health <= 0.0:
		die(hit)
		return
	if is_armored() and amount < stagger_threshold:
		return
	apply_knockback(hit.knockback)
	if hit.has_tag("kick") and hit.has_tag("heavy") and hit.knockback.y <= -LAUNCH_MIN_LIFT:
		launched = true
		_launch_t = 0.0


## Damage multiplier for a hit (0 = fully resisted). Subclasses add shields,
## shells and soft spots.
func hit_multiplier(_hit: Hit) -> float:
	return 1.0


## The combat mode this enemy is weak to right now (drives the icon over it).
func weakness() -> Weakness:
	return Weakness.NONE


## Text shown when a hit is resisted (e.g. "BLOCKED!").
func resist_text(_hit: Hit) -> String:
	return "BLOCKED!"


func is_juggled() -> bool:
	return launched and not is_dead and not is_on_floor()


func juggle_multiplier(hit: Hit) -> float:
	var p := hit.source as Player
	if p and p.combat:
		return p.combat.juggle_multiplier
	return JUGGLE_MULTIPLIER


func _resist(hit: Hit) -> void:
	_weak_flash = 0.8
	set_engaged(true)
	Audio.play("block", -2.0)
	Fx.text(global_position + Vector2(0, -body_size.y * 0.5 - 14), resist_text(hit), Color("#c8d4e6"), 15)
	Fx.burst(global_position + Vector2(signf(hit.knockback.x) * -body_size.x * 0.4, 0), Color("#c8d4e6"), 14.0, 0.15)
	# A little shove so the blow still feels like it connected.
	if hit.knockback != Vector2.ZERO and not is_armored():
		apply_knockback(Vector2(hit.knockback.x * 0.3, minf(hit.knockback.y * 0.2, 0.0)))
	resisted.emit(self, hit)
	GameManager.enemy_resisted.emit(self, hit)


func apply_knockback(knockback: Vector2) -> void:
	if knockback == Vector2.ZERO:
		return
	velocity = knockback * knockback_multiplier
	in_knockback = true
	_collided.clear()
	_knockback_t = knockback_min_time
	_on_interrupted()


func die(hit: Hit = null) -> void:
	if is_dead:
		return
	is_dead = true
	in_knockback = false
	# Stop being targetable/hittable; keep colliding with the world while the body falls.
	collision_layer = 0
	if hit:
		velocity = hit.knockback * knockback_multiplier
	set_engaged(false)
	Audio.play("enemy_death", -2.0)
	_on_died()
	Fx.burst(global_position, body_color(), 34.0, 0.35)
	if should_drop_potion(rng.randf()):
		drop_potion()
	died.emit(self)
	GameManager.enemy_died.emit(self)


func should_drop_potion(roll: float) -> bool:
	return roll < potion_drop_chance


func drop_potion() -> PotionPickup:
	var potion := POTION_SCENE.instantiate() as PotionPickup
	potion.position = position + Vector2(0, -10)
	potion.launch(Vector2(rng.randf_range(-60, 60), -260))
	# Deferred: deaths happen during physics callbacks.
	get_parent().add_child.call_deferred(potion)
	return potion


func set_engaged(value: bool) -> void:
	if value == is_engaged or (value and is_dead):
		return
	is_engaged = value
	engaged_changed.emit(self, value)
	var player := get_player()
	if player:
		player.combat_state.set_enemy_engaged(self, value)


func _check_enemy_collisions() -> void:
	var dir := signf(velocity.x)
	for body in HitQuery.box(self, global_position + Vector2(dir * 4.0, 0), body_size + Vector2(8, 0), HitQuery.LAYER_ENEMIES):
		var other := body as EnemyBase
		if other == null or other == self or other.is_dead or _collided.has(other.get_instance_id()):
			continue
		_collided[other.get_instance_id()] = true
		var speed := absf(velocity.x)
		var tags := PackedStringArray(["collision"])
		other.take_hit(Hit.new(collision_damage, Vector2(dir * speed * 0.6, -220), self, tags))
		# The thrown enemy can't bounce straight back into the one it hit.
		other._collided[get_instance_id()] = true
		velocity.x *= 0.5
		Fx.text((global_position + other.global_position) * 0.5 + Vector2(0, -36), "BONK!", Color("#ffb347"), 18)
		Fx.shake(0.3)
		collided.emit(self, other)
		GameManager.enemy_collided.emit(self, other)
		take_hit(Hit.new(collision_self_damage, Vector2.ZERO, self, tags))
		if is_dead:
			return


# --- Helpers for subclasses -------------------------------------------------

func is_ledge_ahead(dir: int) -> bool:
	if not is_on_floor():
		return false
	var from := global_position + Vector2(dir * (body_size.x * 0.5 + 6.0), 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, body_size.y * 0.5 + 20.0), HitQuery.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func is_wall_ahead(dir: int) -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -dir


func hit_flash() -> float:
	return _flash_t


## Draws the weakness badge (a boot for kicks, a star for magic) centred at
## `at` in local space. Call from a subclass's _draw().
func draw_weakness(at: Vector2) -> void:
	var w := weakness()
	if w == Weakness.NONE or is_dead:
		return
	var s := 1.0 + 0.5 * _weak_flash + 0.06 * sin(Time.get_ticks_msec() * 0.008)
	var col := PlayerCombat.CARL_COLOR if w == Weakness.KICKS else PlayerCombat.DONUT_COLOR
	draw_circle(at, 8.0 * s, Color(0, 0, 0, 0.65))
	draw_circle(at, 6.5 * s, col)
	if w == Weakness.KICKS:
		# A little boot.
		draw_colored_polygon(PackedVector2Array([at + Vector2(-2.5, -4) * s, at + Vector2(1, -4) * s,
			at + Vector2(1, 0.5) * s, at + Vector2(4, 1) * s, at + Vector2(4, 3.5) * s, at + Vector2(-2.5, 3.5) * s]), Color.WHITE)
	else:
		# A four-point sparkle.
		var pts := PackedVector2Array()
		for i in 8:
			var a := i * PI / 4.0 - PI / 2.0
			var r := 4.5 if i % 2 == 0 else 1.6
			pts.append(at + Vector2(cos(a), sin(a)) * r * s)
		draw_colored_polygon(pts, Color.WHITE)


func death_progress() -> float:
	return _death_t / DEATH_DURATION


# --- Overridables -----------------------------------------------------------

func _ai(_delta: float) -> void:
	pass


## Hasty Horde: speed up movement and attacks by `factor`.
func apply_haste(_factor: float) -> void:
	pass


## True while the enemy shrugs off light hits (no knockback/interrupt).
func is_armored() -> bool:
	return false


func _on_interrupted() -> void:
	pass


func _on_knockback_end() -> void:
	pass


func _on_died() -> void:
	pass


func body_color() -> Color:
	return Color.WHITE
