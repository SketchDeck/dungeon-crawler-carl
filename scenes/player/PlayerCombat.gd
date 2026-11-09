class_name PlayerCombat
extends Node
## Routes attack input to the active combat mode's abilities and resolves
## their hits. Carl mode kicks; Donut mode casts magic. The special button (L)
## uses the active mode's unlockable special: Explosive Kick or Magic Burst. Switching is instant,
## except during an attack's non-interruptible windup, where it is queued
## until the attack fires. Switching never touches movement, position, health
## or cooldowns.

signal hit_landed(hit: Hit, targets: int)
signal mode_changed(mode: Mode)

enum Mode { CARL, DONUT }

const CARL_COLOR := Color("#ffa53c")
const DONUT_COLOR := Color("#b46cff")

## Bodies on these layers can be struck by player attacks.
@export_flags_2d_physics var target_mask := HitQuery.LAYER_ENEMIES | HitQuery.LAYER_HITTABLE
## Where Donut's bolts start, relative to the player (facing right).
@export var projectile_origin := Vector2(18, -6)

## Disabled by tests to drive abilities without real input.
var read_input := true
## Multipliers for temporary upgrades (Milestone 6).
var kick_damage_multiplier := 1.0
var magic_damage_multiplier := 1.0
var knockback_multiplier := 1.0
var cooldown_multiplier := 1.0
## Damage multiplier for magic hits on launched enemies (upgrades raise it).
var juggle_multiplier := EnemyBase.JUGGLE_MULTIPLIER
## Behaviour upgrades (set by PlayerUpgrades).
var pierce_bolts := false
## Damage fraction of Double Tap's extra bolt (0 = no extra bolt).
var twin_bolt_factor := 0.0
## Damage of Seismic Stomp's finisher shockwave (0 = none).
var kick_wave_damage := 0.0

var mode := Mode.CARL
## A switch requested during a windup, applied once the attack fires.
var switch_queued := false
var time_since_switch := 10.0

var player: Player

@onready var kick_combo: KickCombo = $KickCombo
@onready var charged_kick: ChargedKick = $ChargedKick
@onready var magic_missile: MagicMissile = $MagicMissile
@onready var charged_blast: ChargedBlast = $ChargedBlast
@onready var explosive_kick: ExplosiveKick = $ExplosiveKick
@onready var area_burst: AreaBurst = $AreaBurst

var _locked_notice := 0.0


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


func basic_ability() -> Ability:
	return kick_combo if mode == Mode.CARL else magic_missile


func charged_ability() -> Ability:
	return charged_kick if mode == Mode.CARL else charged_blast


func special_ability() -> Ability:
	return explosive_kick if mode == Mode.CARL else area_burst


static func mode_name(m: Mode) -> String:
	return "CARL" if m == Mode.CARL else "DONUT"


static func mode_color(m: Mode) -> Color:
	return CARL_COLOR if m == Mode.CARL else DONUT_COLOR


func _physics_process(delta: float) -> void:
	time_since_switch += delta
	_locked_notice = maxf(_locked_notice - delta, 0.0)
	if player.health.is_dead:
		interrupt()
		switch_queued = false
		return
	if switch_queued and not is_busy():
		_apply_switch()
	if not read_input:
		return
	if Input.is_action_just_pressed("switch_mode"):
		request_switch()
	if player.is_dodging():
		return
	var basic := basic_ability()
	var charged := charged_ability()
	var special := special_ability()
	if Input.is_action_just_pressed("basic_attack") and not charged.is_active() and not special.is_active():
		basic.press()
	if Input.is_action_just_pressed("charged_attack") and not basic.is_active() and not special.is_active():
		charged.press()
	if Input.is_action_just_pressed("special_attack") and not basic.is_active() and not charged.is_active():
		press_special()
	if charged.is_charging() and not Input.is_action_pressed("charged_attack"):
		charged.release()
	if special.is_charging() and not Input.is_action_pressed("special_attack"):
		special.release()


## Uses the active mode's special if it's unlocked. Returns false when locked.
func press_special() -> bool:
	var special := special_ability()
	if not special.is_unlocked():
		if _locked_notice <= 0.0:
			_locked_notice = 0.8
			var how := "beat Floor 1" if special == explosive_kick else "beat Floor 2"
			Fx.text(player.global_position + Vector2(0, -70), "%s is locked (%s)" % [special.display_name, how],
				Color(1, 1, 1, 0.85), 13)
		return false
	special.press()
	return true


## Switches between Carl and Donut. Instant unless an attack is mid-windup, in
## which case the switch happens as soon as that attack fires. Returns true if
## the mode changed right away.
func request_switch() -> bool:
	if player.health.is_dead:
		return false
	if is_busy():
		switch_queued = true
		return false
	_apply_switch()
	return true


func _apply_switch() -> void:
	switch_queued = false
	# Stop the old mode's charge or recovery. Cooldowns keep running.
	for ability in abilities():
		if ability.mode == mode:
			ability.cancel()
	mode = Mode.DONUT if mode == Mode.CARL else Mode.CARL
	time_since_switch = 0.0
	Audio.play("switch_mode", -4.0, 0.0)
	mode_changed.emit(mode)


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


## Launches one of Donut's bolts in the facing direction.
func fire_projectile(hit: Hit, radius: float, speed: float, max_range: float, heavy: bool, y_offset := 0.0) -> MagicProjectile:
	hit.knockback.x *= player.facing
	var bolt := MagicProjectile.new()
	bolt.hit = hit
	bolt.direction = player.facing
	bolt.radius = radius
	bolt.hit_radius = radius + 3.0
	bolt.speed = speed
	bolt.max_range = max_range
	bolt.heavy = heavy
	bolt.color = DONUT_COLOR.lerp(Color("#ff8af0"), 0.35) if heavy else DONUT_COLOR
	bolt.mask = target_mask | HitQuery.LAYER_WORLD
	bolt.pierce = pierce_bolts
	bolt.hit_target.connect(_on_projectile_hit)
	var origin := player.global_position + Vector2(projectile_origin.x * player.facing, projectile_origin.y + y_offset)
	player.get_parent().add_child(bolt)
	bolt.global_position = origin
	Fx.burst(origin, Color(DONUT_COLOR, 0.7), radius * 1.6, 0.12)
	if heavy:
		Fx.shake(0.12)
	return bolt


## Seismic Stomp: a shockwave runs along the floor from Carl's feet.
func launch_kick_wave(damage: float) -> void:
	var wave := KickWave.new()
	wave.direction = player.facing
	wave.hit = Hit.new(damage, Vector2(260 * player.facing, -200) * knockback_multiplier, player,
		PackedStringArray(["kick", "wave"]))
	wave.mask = target_mask
	player.get_parent().add_child(wave)
	wave.global_position = player.global_position + Vector2(24 * player.facing, 28)


func _on_projectile_hit(bolt: MagicProjectile, _target: Node) -> void:
	if bolt.heavy:
		Fx.hit_stop(0.05)
		Fx.shake(0.25)
	hit_landed.emit(bolt.hit, 1)
