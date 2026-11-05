class_name PlayerController
extends Node
## Movement only: run, jump (coyote time, jump buffering, variable height), air control, dash,
## and knockback stun. Knows nothing about combat.

signal jumped
signal dashed
signal landed

var body: CharacterBody2D
var facing: int = 1
var move_mult: float = 1.0

var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
var _coyote: float = 0.0
var _buffer: float = 0.0
var _dash_time: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: float = 1.0
var _stun: float = 0.0
var _jump_cut_done: bool = false
var _was_on_floor: bool = false


func physics_step(delta: float, axis: float, jump_pressed: bool, jump_held: bool, dash_pressed: bool) -> void:
	var on_floor := body.is_on_floor()
	_coyote = Config.COYOTE_TIME if on_floor else maxf(0.0, _coyote - delta)
	_buffer = Config.JUMP_BUFFER_TIME if jump_pressed else maxf(0.0, _buffer - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_stun = maxf(0.0, _stun - delta)
	if on_floor and not _was_on_floor:
		landed.emit()
	_was_on_floor = on_floor

	if absf(axis) > 0.1 and _stun <= 0.0:
		facing = 1 if axis > 0.0 else -1

	if dash_pressed and _dash_cooldown <= 0.0 and _dash_time <= 0.0 and _stun <= 0.0:
		_dash_time = Config.DASH_DURATION
		_dash_cooldown = Config.DASH_COOLDOWN
		_dash_dir = float(facing)
		body.velocity.y = 0.0
		dashed.emit()

	if _dash_time > 0.0:
		_dash_time -= delta
		body.velocity = Vector2(_dash_dir * Config.DASH_SPEED, 0.0)
		return

	var target := 0.0
	if _stun <= 0.0:
		target = axis * Config.MOVE_SPEED * move_mult
	var accel: float
	if on_floor:
		accel = Config.ACCEL_GROUND if absf(target) > 0.0 else Config.FRICTION_GROUND
	else:
		accel = Config.ACCEL_AIR if absf(target) > 0.0 else Config.ACCEL_AIR * 0.35
	body.velocity.x = move_toward(body.velocity.x, target, accel * delta)

	if on_floor:
		_jump_cut_done = false
		if body.velocity.y > 0.0:
			body.velocity.y = 0.0
	else:
		body.velocity.y = minf(body.velocity.y + _gravity * delta, Config.MAX_FALL_SPEED)

	if _buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0:
		body.velocity.y = Config.JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_jump_cut_done = false
		jumped.emit()

	if not jump_held and body.velocity.y < 0.0 and not _jump_cut_done:
		body.velocity.y *= Config.JUMP_CUT_MULTIPLIER
		_jump_cut_done = true


func is_dashing() -> bool:
	return _dash_time > 0.0


## The first part of the dash is invulnerable (spec: about 0.15 s).
func is_dash_invulnerable() -> bool:
	return _dash_time > 0.0 and _dash_time > Config.DASH_DURATION - Config.DASH_INVULN


func is_stunned() -> bool:
	return _stun > 0.0


func cancel_dash() -> void:
	_dash_time = 0.0


func apply_knockback(velocity: Vector2, stun_time: float) -> void:
	body.velocity = velocity
	_stun = maxf(_stun, stun_time)
	_dash_time = 0.0


func reset() -> void:
	_coyote = 0.0
	_buffer = 0.0
	_dash_time = 0.0
	_dash_cooldown = 0.0
	_stun = 0.0
	_jump_cut_done = false
	_was_on_floor = false
