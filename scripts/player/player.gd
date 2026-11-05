class_name Player
extends CharacterBody2D
## Carl with Donut on his shoulder. One body, one health pool, one movement controller,
## one potion inventory (Game.potions), and one active combat mode. Switching modes never
## changes position, movement, or health.

signal died
signal mode_changed(mode: int)
signal damaged(amount: int)
signal healed(amount: int)

enum Mode { CARL, DONUT }

const BODY_SIZE := Vector2(24.0, 42.0)
const MODE_NAMES := {Mode.CARL: "CARL MODE", Mode.DONUT: "DONUT MODE"}

var health := HealthState.new(Config.PLAYER_MAX_HP)
var mode: int = Mode.CARL
var alive: bool = true
var input_locked: bool = false

var controller: PlayerController
var combat: PlayerCombat
var visual: PlayerVisual

var _potion_cooldown: float = 0.0
var _pending_switch: bool = false


func _ready() -> void:
	add_to_group("player")
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = BODY_SIZE.x * 0.5
	capsule.height = BODY_SIZE.y
	shape.shape = capsule
	add_child(shape)

	controller = PlayerController.new()
	controller.body = self
	add_child(controller)

	combat = PlayerCombat.new()
	combat.player = self
	add_child(combat)

	visual = PlayerVisual.new()
	visual.player = self
	visual.position = Vector2(0.0, -3.0)
	add_child(visual)

	health.died.connect(_on_died)
	CombatState.bind_player(health)


func _physics_process(delta: float) -> void:
	health.tick(delta)
	_potion_cooldown = maxf(0.0, _potion_cooldown - delta)
	controller.move_mult = Game.modifier("move_speed")

	if not alive:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		velocity.y = minf(velocity.y + 980.0 * delta, Config.MAX_FALL_SPEED)
		move_and_slide()
		return

	var axis := 0.0 if input_locked else Input.get_axis(Controls.MOVE_LEFT, Controls.MOVE_RIGHT)
	var jump_pressed := not input_locked and Input.is_action_just_pressed(Controls.JUMP)
	var jump_held := not input_locked and Input.is_action_pressed(Controls.JUMP)
	var dash_pressed := not input_locked and Input.is_action_just_pressed(Controls.DODGE)
	controller.physics_step(delta, axis, jump_pressed, jump_held, dash_pressed)
	if controller.is_dashing():
		combat.cancel_attacks()

	if not input_locked:
		if Input.is_action_just_pressed(Controls.SWITCH_MODE):
			request_switch()
		if Input.is_action_just_pressed(Controls.POTION):
			use_potion()

	combat.physics_step(delta, input_locked)
	move_and_slide()


## Entry point for everything that damages the player. Returns true if the hit landed.
func receive_hit(hit: HitInfo) -> bool:
	if not alive or controller.is_dash_invulnerable():
		return false
	var dealt := health.take_damage(hit.amount, Config.PLAYER_HIT_INVULN)
	if dealt <= 0:
		return false
	var away := signf(global_position.x - hit.source.global_position.x) if hit.source is Node2D else -float(controller.facing)
	if away == 0.0:
		away = -float(controller.facing)
	var push := Vector2(away * clampf(absf(hit.knockback.x) * 0.45 + 110.0, 110.0, 230.0), -210.0)
	if not hit.environmental:
		controller.apply_knockback(push, 0.22)
	combat.cancel_attacks()
	visual.on_hurt()
	Sfx.play("hurt")
	Fx.shake(9.0)
	Fx.hitstop(0.035, 0.15)
	Fx.burst(global_position, Color("#ff5f6d"), 16, 260.0)
	Fx.flash(global_position, Color("#ff3b4e"), 40.0, 0.18)
	Fx.text(global_position + Vector2(0.0, -34.0), "-%d" % dealt, Color("#ff7a85"), 20)
	damaged.emit(dealt)
	if hit.source is EnemyBase:
		CombatState.engage(hit.source)
	return true


func request_switch() -> void:
	if combat.is_committed():
		_pending_switch = true
		return
	_switch_mode()


## Called by PlayerCombat when a non-interruptible animation ends.
func on_commitment_finished() -> void:
	if _pending_switch:
		_switch_mode()


func _switch_mode() -> void:
	_pending_switch = false
	combat.cancel_charge()
	mode = Mode.DONUT if mode == Mode.CARL else Mode.CARL
	var color := Color("#b57bff") if mode == Mode.DONUT else Color("#ffb347")
	visual.on_mode_changed(mode)
	Sfx.play("switch")
	Fx.ring(global_position, color, 52.0, 0.32, 5.0)
	Fx.flash(global_position, color, 30.0, 0.12)
	Fx.text(global_position + Vector2(0.0, -58.0), MODE_NAMES[mode], color, 15)
	mode_changed.emit(mode)


func use_potion() -> void:
	if not alive or _potion_cooldown > 0.0:
		return
	if Game.potions.count <= 0:
		Fx.text(global_position + Vector2(0.0, -40.0), "No potions", Color("#9aa4b2"), 15)
		return
	if health.missing() <= 0:
		Fx.text(global_position + Vector2(0.0, -40.0), "Already full", Color("#9aa4b2"), 15)
		return
	var restored := Game.potions.drink(health)
	if restored <= 0:
		return
	_potion_cooldown = Config.POTION_USE_COOLDOWN
	visual.on_drink()
	Sfx.play("heal")
	Fx.glow(global_position, Color("#6dff9a"), 46.0, 0.45)
	Fx.text(global_position + Vector2(0.0, -40.0), "+%d HP" % restored, Color("#6dff9a"), 18)
	healed.emit(restored)


## Places the player at a spawn point with full health and no pending actions.
func respawn_at(pos: Vector2, face: int) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	controller.facing = face
	controller.reset()
	combat.reset()
	health.restore_full()
	alive = true
	_pending_switch = false
	_potion_cooldown = 0.0
	if mode != Mode.CARL:
		mode = Mode.CARL
		visual.on_mode_changed(mode)
	visual.on_respawn()
	CombatState.reset()


## Applies the floor's max-HP bonus from temporary upgrades. Current HP is restored too.
func apply_floor_stats() -> void:
	health.set_max_hp(Config.PLAYER_MAX_HP + Game.bonus_max_hp())
	health.restore_full()


## Called when a max-HP upgrade is picked up mid-floor: the bonus also adds the same amount of HP.
func refresh_max_hp() -> void:
	health.set_max_hp(Config.PLAYER_MAX_HP + Game.bonus_max_hp(), true)


func _on_died() -> void:
	alive = false
	combat.cancel_attacks()
	combat.cancel_charge()
	visual.on_death()
	Fx.shake(18.0)
	Fx.hitstop(0.12, 0.08)
	died.emit()
