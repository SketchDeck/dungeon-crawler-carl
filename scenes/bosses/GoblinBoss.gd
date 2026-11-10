class_name GoblinBoss
extends BossBase
## Floor 1 boss: the Goblin Brute.
##
## Waits (DORMANT) until the room starts the fight. Then it walks toward the
## player and picks one of three telegraphed attacks:
##   Charge  - crouches and shows a red arrow, then rushes horizontally.
##             Contact damage. Dazed for a while if it slams into a wall.
##   Slam    - raises both fists over red ground stripes, then sends a
##             shockwave along the floor both ways. Jump over it.
##   Swing   - pulls the club back over a red arc, then a heavy swing in
##             front. Back off or dodge through it.
## Every attack is followed by a recovery window. Below 50% HP it enrages
## (phase 2): faster telegraphs, shorter recovery, faster charges, longer
## shockwaves, and sometimes a second attack chained straight after the first.
## The boss can't be knocked back or interrupted, and is immune while it
## roars (intro and phase change).

enum State { DORMANT, INTRO, APPROACH, TELEGRAPH, CHARGING, ACTIVE, RECOVER, STUNNED, TRANSITION }
enum Attack { CHARGE, SLAM, SWING }

const SKIN := Color("#5f9a45")
const SKIN_ENRAGED := Color("#a8583a")
const ARMOR := Color("#4d4038")
const CLUB := Color("#7a4f28")

@export_group("Movement")
@export var approach_speed := 95.0
@export_group("Timing")
@export var intro_time := 1.4
## Pause while walking in before choosing an attack.
@export var think_time := 0.7
@export var charge_telegraph := 0.8
@export var slam_telegraph := 0.85
@export var swing_telegraph := 0.6
@export var recovery := 1.1
@export var stun_time := 1.6
@export var transition_time := 1.8
@export_group("Phase 2")
@export var phase2_telegraph_multiplier := 0.75
@export var phase2_recovery_multiplier := 0.55
@export var phase2_speed_multiplier := 1.25
@export_range(0.0, 1.0) var phase2_chain_chance := 0.4
@export_group("Charge")
@export var charge_speed := 520.0
@export var charge_distance := 760.0
@export var charge_damage := 20.0
@export var charge_knockback := Vector2(420, -300)
@export_group("Slam")
@export var slam_damage := 15.0
@export var wave_speed := 360.0
@export var wave_range := 300.0
@export var phase2_wave_range := 560.0
@export var wave_height := 26.0
@export var slam_knockback := Vector2(200, -320)
@export_group("Swing")
@export var swing_damage := 22.0
## The boss prefers the swing when the player is closer than this.
@export var swing_range := 120.0
## Hitbox relative to the boss origin, facing right. Tall enough to reach
## someone standing on a low platform next to it.
@export var swing_hitbox := Rect2(4, -74, 112, 108)
@export var swing_knockback := Vector2(480, -280)

var state := State.DORMANT
var attack := Attack.SWING
## Tests set this to choose the next attack instead of rolling for it.
var forced_attack := -1

var _t := 0.0
var _charge_from := 0.0
var _history: Array[int] = []
var _chained := false
var _swing_fx := 0.0
var _anim := 0.0


func _init() -> void:
	boss_name = "GOBLIN BRUTE"
	boss_hint = "Learn his tells: crouch = charge, fists up = slam (jump!), club back = swing"
	phase2_hint = "The Brute is enraged: faster attacks, longer shockwaves"
	defeat_text = "The Goblin Brute is down. Take the stairs."


func _ready() -> void:
	super._ready()
	facing = -1


func is_dormant() -> bool:
	return state == State.DORMANT


func start_fight() -> void:
	if state != State.DORMANT or is_dead:
		return
	state = State.INTRO
	_t = intro_time
	set_engaged(true)
	Audio.play("boss_roar")
	Fx.shake(0.5)
	Fx.text(global_position + Vector2(0, -80), "RAAAGH!", Settings.warn_color(), 24)
	fight_started.emit()


func is_immune() -> bool:
	return state == State.DORMANT or state == State.INTRO or state == State.TRANSITION


func is_telegraphing() -> bool:
	return state == State.TELEGRAPH and not is_dead


func telegraph_time(a: Attack) -> float:
	var base := swing_telegraph
	match a:
		Attack.CHARGE:
			base = charge_telegraph
		Attack.SLAM:
			base = slam_telegraph
	return base * (phase2_telegraph_multiplier if phase == 2 else 1.0) * Settings.telegraph_scale()


func recovery_time() -> float:
	return recovery * (phase2_recovery_multiplier if phase == 2 else 1.0)


func current_wave_range() -> float:
	return phase2_wave_range if phase == 2 else wave_range


func _speed_mult() -> float:
	return phase2_speed_multiplier if phase == 2 else 1.0


# --- AI -------------------------------------------------------------------------

func _ai(delta: float) -> void:
	_anim += delta
	_swing_fx = maxf(_swing_fx - delta, 0.0)
	var player := get_player()
	var player_ok := player != null and not player.health.is_dead
	if not player_ok and state != State.CHARGING:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		return

	match state:
		State.DORMANT:
			velocity.x = 0.0
		State.INTRO, State.TRANSITION, State.RECOVER, State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_approach()
		State.APPROACH:
			_face(player)
			var dx := absf(player.global_position.x - global_position.x)
			if dx > swing_range * 0.7 and not is_wall_ahead(facing):
				velocity.x = facing * approach_speed * _speed_mult()
			else:
				velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_begin_attack(_pick_attack(player))
		State.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_execute()
		State.CHARGING:
			if is_wall_ahead(facing) and absf(global_position.x - _charge_from) > 24.0:
				_hit_wall()
				return
			if absf(global_position.x - _charge_from) >= charge_distance:
				_finish_attack()
				return
			velocity.x = facing * charge_speed * _speed_mult()
			if player_ok:
				_charge_contact()
		State.ACTIVE:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_finish_attack()


func _face(player: Player) -> void:
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 4.0:
		facing = 1 if dx > 0.0 else -1


func _approach() -> void:
	state = State.APPROACH
	_t = think_time * (0.6 if phase == 2 else 1.0)


func _pick_attack(player: Player) -> Attack:
	if forced_attack >= 0:
		return forced_attack as Attack
	var near := absf(player.global_position.x - global_position.x) < swing_range
	var options: Array[int] = []
	if near:
		options.assign([Attack.SWING, Attack.SWING, Attack.SLAM])
	else:
		options.assign([Attack.CHARGE, Attack.CHARGE, Attack.SLAM])
	var choice: int = options[rng.randi() % options.size()]
	# Never the same attack three times in a row.
	if _history.size() >= 2 and _history[-1] == choice and _history[-2] == choice:
		for other: int in options:
			if other != choice:
				choice = other
				break
	return choice as Attack


func _begin_attack(a: Attack) -> void:
	attack = a
	_history.append(a)
	if _history.size() > 4:
		_history.pop_front()
	var player := get_player()
	if player:
		_face(player)
	state = State.TELEGRAPH
	_t = telegraph_time(a)
	velocity.x = 0.0
	Audio.play("boss_warning", -4.0, 0.0)


func _execute() -> void:
	match attack:
		Attack.CHARGE:
			state = State.CHARGING
			_charge_from = global_position.x
			Audio.play("charge")
			Fx.shake(0.2)
		Attack.SLAM:
			_slam()
			state = State.ACTIVE
			_t = 0.3
		Attack.SWING:
			_swing()
			state = State.ACTIVE
			_t = 0.3


func _finish_attack() -> void:
	velocity.x = 0.0
	if phase == 2 and not _chained and rng.randf() < phase2_chain_chance:
		# Chained attack: straight into another telegraph, no recovery between.
		_chained = true
		var player := get_player()
		if player and not player.health.is_dead:
			_begin_attack(_pick_attack(player))
			return
	_chained = false
	state = State.RECOVER
	_t = recovery_time()


func _hit_wall() -> void:
	velocity.x = 0.0
	_chained = false
	state = State.STUNNED
	_t = stun_time
	Audio.play("slam", -4.0)
	Fx.shake(0.6)
	Fx.burst(global_position + Vector2(facing * body_size.x * 0.5, -10), Color("#d8c0a0"), 40.0, 0.35)
	Fx.text(global_position + Vector2(0, -70), "DAZED", Color("#ffd34d"), 18)


func _charge_contact() -> void:
	var hit := Hit.new(charge_damage, Vector2(charge_knockback.x * facing, charge_knockback.y), self, PackedStringArray(["charge"]))
	for target in HitQuery.box(self, global_position, body_size + Vector2(8, 0), HitQuery.LAYER_PLAYER):
		if target.has_method("take_hit"):
			target.take_hit(hit)


func _slam() -> void:
	var feet := global_position + Vector2(0, body_size.y * 0.5)
	for dir in [-1, 1]:
		var wave := Shockwave.new()
		wave.direction = dir
		wave.speed = wave_speed * _speed_mult()
		wave.max_range = current_wave_range()
		wave.height = wave_height
		wave.hit = Hit.new(slam_damage, Vector2(slam_knockback.x * dir, slam_knockback.y), self, PackedStringArray(["shockwave"]))
		get_parent().add_child(wave)
		wave.global_position = feet + Vector2(dir * body_size.x * 0.5, 0)
	Audio.play("slam")
	Fx.shake(0.5)
	Fx.burst(feet, Color("#d8c0a0"), 46.0, 0.3)


func _swing() -> void:
	_swing_fx = 0.25
	var center := swing_hitbox.get_center()
	center.x *= facing
	var world_center := global_position + center
	var hit := Hit.new(swing_damage, Vector2(swing_knockback.x * facing, swing_knockback.y), self, PackedStringArray(["melee", "heavy"]))
	for target in HitQuery.box(self, world_center, swing_hitbox.size, HitQuery.LAYER_PLAYER):
		if target.has_method("take_hit"):
			target.take_hit(hit)
	Fx.slash(world_center, facing, 60.0, Color("#ff6040"), 0.18)
	Fx.shake(0.3)


func _enter_phase_two() -> void:
	_chained = false
	state = State.TRANSITION
	_t = transition_time
	velocity.x = 0.0
	Fx.shake(0.8)
	Fx.burst(global_position, Settings.warn_color(), 70.0, 0.5)
	Fx.text(global_position + Vector2(0, -90), "ENRAGED!", Settings.warn_color(), 26)
	Audio.play("boss_roar")


func _on_died() -> void:
	state = State.DORMANT
	Fx.shake(0.9)
	Fx.hit_stop(0.2)
	Fx.burst(global_position, Color("#ffd34d"), 90.0, 0.7)
	drop_rewards()


func body_color() -> Color:
	return SKIN_ENRAGED if phase == 2 else SKIN


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var feet_y := body_size.y * 0.5
	if is_telegraphing():
		_draw_telegraph(feet_y)

	var skin := body_color()
	if hit_flash() > 0.0:
		skin = skin.lerp(Color.WHITE, 0.75)
	elif is_telegraphing():
		skin = skin.lerp(Settings.warn_color(), 0.3 + 0.2 * sin(_anim * 30.0))
	skin.a = alpha
	var armor := Color(ARMOR, alpha)
	var club := Color(CLUB, alpha)

	var shake := Vector2.ZERO
	if state == State.TRANSITION or state == State.INTRO:
		shake = Vector2(sin(_anim * 70.0) * 2.0, 0)
	var crouch := 8.0 if state == State.TELEGRAPH and attack == Attack.CHARGE else 0.0
	draw_set_transform(shake + Vector2(0, crouch), 0.0, Vector2(facing, 1))
	if is_dead:
		draw_set_transform(Vector2(0, 20), -PI * 0.5 * facing, Vector2(facing, 1))

	# Enraged aura.
	if phase == 2 and not is_dead:
		draw_circle(Vector2(0, -6), 50.0 + 3.0 * sin(_anim * 8.0), Color(Settings.warn_color(), 0.12))
	# Legs.
	var stride := sin(_anim * 10.0) * 6.0 if state == State.APPROACH or state == State.CHARGING else 0.0
	draw_line(Vector2(-11, 14), Vector2(-12 - stride, feet_y - crouch), skin, 11.0)
	draw_line(Vector2(11, 14), Vector2(12 + stride, feet_y - crouch), skin, 11.0)
	# Body, belly and armor straps.
	draw_rect(Rect2(-24, -22, 48, 40), skin)
	draw_circle(Vector2(4, 6), 18.0, skin.lightened(0.08))
	draw_line(Vector2(-22, -20), Vector2(18, 16), armor, 6.0)
	draw_rect(Rect2(-25, 10, 50, 12), armor)
	# Head.
	var head := Vector2(8, -34)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-10, -4), head + Vector2(-28, -14), head + Vector2(-9, -11)]), skin)
	draw_colored_polygon(PackedVector2Array([head + Vector2(10, -4), head + Vector2(26, -16), head + Vector2(9, -11)]), skin)
	draw_circle(head, 15.0, skin)
	var eye := Color(1, 0.15, 0.1, alpha) if phase == 2 else Color(1, 0.9, 0.2, alpha)
	draw_circle(head + Vector2(7, -3), 3.0, eye)
	# Underbite tusks.
	draw_colored_polygon(PackedVector2Array([head + Vector2(4, 8), head + Vector2(6, 1), head + Vector2(8, 8)]), Color(1, 1, 0.9, alpha))
	draw_colored_polygon(PackedVector2Array([head + Vector2(11, 8), head + Vector2(13, 2), head + Vector2(15, 8)]), Color(1, 1, 0.9, alpha))

	# Arms and club, posed by state.
	var hand := Vector2(22, 0)
	var tip := Vector2(36, -40)
	var other_hand := Vector2(-20, 4)
	if state == State.TELEGRAPH:
		match attack:
			Attack.SWING:
				hand = Vector2(-18, -18)
				tip = Vector2(-52, -46)
			Attack.SLAM:
				hand = Vector2(2, -52)
				tip = Vector2(-10, -98)
				other_hand = Vector2(-8, -50)
			Attack.CHARGE:
				hand = Vector2(20, 6)
				tip = Vector2(58, 0)
	elif _swing_fx > 0.0 or (state == State.ACTIVE and attack == Attack.SWING):
		tip = Vector2(76, 10)
	elif state == State.ACTIVE and attack == Attack.SLAM:
		hand = Vector2(24, 12)
		tip = Vector2(56, feet_y - 4)
	elif state == State.CHARGING:
		hand = Vector2(22, 4)
		tip = Vector2(60, -4)
	draw_line(Vector2(-16, -14), other_hand, skin, 9.0)
	draw_line(Vector2(16, -14), hand, skin, 9.0)
	draw_line(hand, tip, club, 9.0)
	draw_circle(tip, 11.0, club)
	draw_circle(tip + (tip - hand).normalized() * 6.0, 3.0, Color(0.7, 0.7, 0.7, alpha))
	draw_circle(hand, 6.0, skin)

	# Dazed stars.
	if state == State.STUNNED:
		for i in 3:
			var a := _anim * 5.0 + i * TAU / 3.0
			draw_circle(head + Vector2(cos(a) * 20.0, -20 + sin(a) * 5.0), 3.5, Color("#ffd34d"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_telegraphing():
		var font := ThemeDB.fallback_font
		var mark := "!!" if attack == Attack.CHARGE else "!"
		draw_string_outline(font, Vector2(-20, -66), mark, HORIZONTAL_ALIGNMENT_CENTER, 40, 30, 5, Color.BLACK)
		draw_string(font, Vector2(-20, -66), mark, HORIZONTAL_ALIGNMENT_CENTER, 40, 30, Settings.warn_color())


## Ground markings that show where the coming attack will land.
func _draw_telegraph(feet_y: float) -> void:
	var progress := 1.0 - clampf(_t / maxf(telegraph_time(attack), 0.01), 0.0, 1.0)
	var pulse := 0.35 + 0.25 * sin(_anim * 24.0)
	match attack:
		Attack.CHARGE:
			# Arrow along the floor in the charge direction.
			var length := 90.0 + 170.0 * progress
			var y := feet_y - 6.0
			draw_rect(Rect2(minf(0.0, facing * length), y - 5, length, 10), Color(Settings.warn_color(), pulse))
			var head_x := facing * (length + 22.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(facing * length, y - 14), Vector2(head_x, y), Vector2(facing * length, y + 14)]), Color(Settings.warn_color(), pulse + 0.2))
		Attack.SLAM:
			# Stripes out to the shockwave's reach on both sides.
			var reach := current_wave_range() + body_size.x * 0.5
			var shown := reach * (0.3 + 0.7 * progress)
			draw_rect(Rect2(-shown, feet_y - 4, shown * 2.0, 4), Color(Settings.warn_color(), pulse))
			var x := 24.0
			while x < shown:
				for dir in [-1, 1]:
					draw_rect(Rect2(dir * x - 3, feet_y - 10, 6, 6), Color(Settings.warn_color(), pulse * 0.8))
				x += 30.0
		Attack.SWING:
			# Outline of the swing's reach.
			var box := swing_hitbox
			var rect := Rect2(Vector2(box.position.x * facing - (box.size.x if facing < 0 else 0.0), box.position.y), box.size)
			draw_rect(rect, Color(Settings.warn_color(), 0.12 + 0.18 * progress))
			draw_rect(rect, Color(Settings.warn_color(), pulse + 0.2), false, 2.0)
