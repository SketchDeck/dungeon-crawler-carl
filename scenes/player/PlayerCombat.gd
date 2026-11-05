class_name PlayerCombat
extends Node
## Routes attack input to the active mode's abilities and resolves their hits.
## Milestone 1 only has Carl mode; Donut mode is added in Milestone 4.

signal hit_landed(hit: Hit, targets: int)

## Bodies on these layers can be struck by player attacks.
@export_flags_2d_physics var target_mask := HitQuery.LAYER_ENEMIES

## Disabled by tests to drive abilities without real input.
var read_input := true
## Multipliers for temporary upgrades (Milestone 6).
var kick_damage_multiplier := 1.0
var knockback_multiplier := 1.0
var cooldown_multiplier := 1.0

var player: Player

@onready var kick_combo: KickCombo = $KickCombo
@onready var charged_kick: ChargedKick = $ChargedKick


func _ready() -> void:
	player = get_parent() as Player
	for ability in abilities():
		ability.setup(player, self)


func abilities() -> Array[Ability]:
	var list: Array[Ability] = []
	for child in get_children():
		if child is Ability:
			list.append(child)
	return list


func _physics_process(_delta: float) -> void:
	if player.health.is_dead:
		interrupt()
		return
	if not read_input or player.is_dodging():
		return
	if Input.is_action_just_pressed("basic_attack") and not charged_kick.is_active():
		kick_combo.press()
	if Input.is_action_just_pressed("charged_attack") and not kick_combo.is_active():
		charged_kick.press()
	if charged_kick.is_charging() and not Input.is_action_pressed("charged_attack"):
		charged_kick.release()


func is_attacking() -> bool:
	for ability in abilities():
		if ability.is_active():
			return true
	return false


func is_busy() -> bool:
	for ability in abilities():
		if ability.is_busy():
			return true
	return false


func can_turn() -> bool:
	for ability in abilities():
		if ability.locks_facing():
			return false
	return true


func move_speed_factor() -> float:
	var factor := 1.0
	for ability in abilities():
		factor = minf(factor, ability.move_speed_factor())
	return factor


## Cancels any in-progress attacks (dodge, death, respawn). Cooldowns are kept.
func interrupt() -> void:
	for ability in abilities():
		ability.cancel()


## Resolves a melee hitbox in front of the player. Returns the number of targets hit.
func strike(local_box: Rect2, hit: Hit, heavy: bool, color: Color) -> int:
	var center := local_box.get_center()
	center.x *= player.facing
	var world_center := player.global_position + center
	hit.knockback.x *= player.facing
	var count := 0
	for target in HitQuery.box(player, world_center, local_box.size, target_mask):
		if target.has_method("take_hit"):
			target.take_hit(hit)
			count += 1
	Fx.slash(world_center, player.facing, local_box.size.x * 0.55, color)
	if count > 0:
		Fx.hit_stop(0.07 if heavy else 0.035)
		Fx.shake(0.35 if heavy else 0.15)
		hit_landed.emit(hit, count)
	return count
