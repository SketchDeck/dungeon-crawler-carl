class_name Player
extends CharacterBody2D
## Combined Carl + Princess Donut entity: one body, one movement controller.
## Movement only; attacks live in PlayerCombat and health in PlayerHealth.

signal respawned
## A dodge started, toward `dir` (-1 or 1).
signal dodged(dir: int)

@export_group("Run")
@export var move_speed := 260.0
@export var ground_accel := 2200.0
@export var ground_decel := 2600.0
@export var air_accel := 1500.0
@export var air_decel := 900.0

@export_group("Jump")
## -600 with gravity 1500 gives ~120px (3.75 tiles) of jump height.
@export var jump_velocity := -600.0
@export var gravity := 1500.0
@export var fall_gravity_multiplier := 1.4
## Upward velocity is multiplied by this when jump is released early.
@export var jump_cut_multiplier := 0.45
@export var max_fall_speed := 900.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1

@export_group("Dodge")
@export var dodge_speed := 620.0
@export var dodge_duration := 0.2
@export var dodge_cooldown := 0.8
@export var dodge_invuln_time := 0.15

@export_group("Hurt")
## Seconds of reduced control after being knocked back.
@export var hurt_stun_time := 0.18

## Disabled by tests to drive the player without real input.
var read_input := true
## Movement speed multiplier (temporary upgrades in Milestone 6).
var move_speed_multiplier := 1.0
var facing := 1

var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_invuln := 0.0
var _dodge_dir := 1
var _hurt_t := 0.0

@onready var health: PlayerHealth = $Health
@onready var potions: PotionInventory = $Potions
@onready var combat_state: CombatStateManager = $CombatState
@onready var regen: HealthRegen = $Regen
@onready var combat: PlayerCombat = $Combat
@onready var upgrades: PlayerUpgrades = $Upgrades
@onready var visual: PlayerVisual = $Visual
@onready var camera: GameCamera = $Camera


func _physics_process(delta: float) -> void:
	if health.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_dodge_invuln = maxf(_dodge_invuln - delta, 0.0)
	_hurt_t = maxf(_hurt_t - delta, 0.0)

	var dir := Input.get_axis("move_left", "move_right") if read_input else 0.0

	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote -= delta
	if read_input and Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta

	if read_input and Input.is_action_just_pressed("dodge"):
		try_dodge(dir)

	if is_dodging():
		_dodge_t -= delta
		velocity = Vector2(_dodge_dir * dodge_speed, 0.0)
		move_and_slide()
		return

	# Horizontal movement.
	if _hurt_t <= 0.0:
		var target := dir * move_speed * move_speed_multiplier * combat.move_speed_factor()
		var accel: float
		if is_on_floor():
			accel = ground_accel if absf(dir) > 0.01 else ground_decel
		else:
			accel = air_accel if absf(dir) > 0.01 else air_decel
		velocity.x = move_toward(velocity.x, target, accel * delta)
		if absf(dir) > 0.01 and combat.can_turn():
			facing = 1 if dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_decel * delta)

	_apply_gravity(delta)

	# Jumping with coyote time, buffering and variable height.
	if _jump_buffer > 0.0 and _coyote > 0.0 and _hurt_t <= 0.0:
		velocity.y = jump_velocity
		Audio.play("jump", -6.0)
		_jump_buffer = 0.0
		_coyote = 0.0
	if read_input and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		return
	var g := gravity * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func try_dodge(dir := 0.0) -> bool:
	if _dodge_cd > 0.0 or is_dodging() or health.is_dead:
		return false
	_dodge_dir = facing if absf(dir) < 0.01 else (1 if dir > 0.0 else -1)
	facing = _dodge_dir
	_dodge_t = dodge_duration
	_dodge_cd = dodge_cooldown
	_dodge_invuln = dodge_invuln_time
	_hurt_t = 0.0
	combat.interrupt()
	Audio.play("dodge", -4.0)
	dodged.emit(_dodge_dir)
	return true


func is_dodging() -> bool:
	return _dodge_t > 0.0


func dodge_cooldown_ratio() -> float:
	return _dodge_cd / dodge_cooldown if dodge_cooldown > 0.0 else 0.0


func is_invulnerable() -> bool:
	return _dodge_invuln > 0.0 or health.is_invulnerable()


## Receive an attack. Returns true if it landed.
func take_hit(hit: Hit) -> bool:
	if _dodge_invuln > 0.0:
		return false
	if not health.take_damage(hit.damage):
		return false
	velocity = hit.knockback
	_hurt_t = hurt_stun_time
	Audio.play("player_hurt")
	Fx.shake(0.45)
	Fx.burst(global_position, Color("#ff5050"), 26.0)
	return true


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	facing = 1
	_dodge_t = 0.0
	_dodge_cd = 0.0
	_dodge_invuln = 0.0
	_hurt_t = 0.0
	combat.interrupt()
	# Potions are kept; healing timers and combat state start fresh.
	combat_state.reset()
	health.reset()
	regen.cancel()
	camera.reset_smoothing()
	respawned.emit()
