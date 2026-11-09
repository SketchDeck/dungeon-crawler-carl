class_name SewerKing
extends BossBase
## Floor 3 boss: the Sewer King, a rat the size of a sofa wearing a bottle-cap
## crown. Its body swaps between two stances, shown by its colour and the
## weakness icon over its head:
##   Slick (purple sheen) - kicks slide off; magic hurts.
##   Plated (steel scales) - magic splashes off; kicks hurt.
## It swaps every `stance_time` seconds, or sooner once it has taken
## `stance_damage` in the current stance. Attacks, each telegraphed:
##   Tail sweep - coils (red bar along the floor), then sweeps the ground on
##                both sides. Jump over it.
##   Sludge wave - rears up, then slams, sending shockwaves both ways.
##   Rat call   - squeaks (pipes flash), and rats pour out of the side pipes.
## Phase 2 (half health): faster stance swaps, shorter tells and recovery,
## longer waves and more rats. Can't be knocked back.

enum State { DORMANT, INTRO, APPROACH, TELEGRAPH, ACTIVE, RECOVER, TRANSITION }
enum Attack { SWEEP, WAVE, SUMMON }
enum Stance { SLICK, PLATED }

const RAT_SCENE := preload("res://scenes/enemies/Rat.tscn")
const FUR := Color("#6a5a54")
const SLICK_TINT := Color("#9b5cff")
const PLATED_TINT := Color("#9aa4b2")

@export_group("Timing")
@export var intro_time := 1.4
@export var think_time := 0.8
@export var sweep_telegraph := 0.75
@export var wave_telegraph := 0.85
@export var summon_telegraph := 0.7
@export var recovery := 1.0
@export var transition_time := 1.6
@export_group("Stance")
@export var stance_time := 7.0
@export var phase2_stance_time := 4.5
@export var stance_damage := 70.0
@export_group("Phase 2")
@export var phase2_telegraph_multiplier := 0.75
@export var phase2_recovery_multiplier := 0.6
@export_group("Attacks")
@export var approach_speed := 80.0
@export var sweep_damage := 18.0
@export var sweep_reach := 150.0
@export var sweep_height := 30.0
@export var wave_damage := 15.0
@export var wave_speed := 380.0
@export var wave_range := 320.0
@export var phase2_wave_range := 560.0
@export var rats_per_call := 2
@export var phase2_rats_per_call := 3
@export var max_rats := 4

var state := State.DORMANT
var attack := Attack.SWEEP
var stance := Stance.SLICK
## Tests set these to choose the next attack instead of rolling for it.
var forced_attack := -1
var rats: Array[EnemyBase] = []

var _t := 0.0
var _stance_t := 0.0
var _stance_hurt := 0.0
var _history: Array[int] = []
var _anim := 0.0
var _sweep_fx := 0.0
var _swap_flash := 0.0


func _init() -> void:
	boss_name = "THE SEWER KING"
	boss_hint = "Purple = magic only, steel = kicks only. Watch the icon over his crown and switch!"
	phase2_hint = "The King is furious: faster stance swaps, longer waves, more rats"
	defeat_text = "The Sewer King is dethroned. Take the stairs."


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
	_stance_t = current_stance_time()
	set_engaged(true)
	Audio.play("boss_roar")
	Fx.shake(0.5)
	Fx.text(global_position + Vector2(0, -90), "SQUEEEE!", Settings.warn_color(), 24)
	fight_started.emit()


func is_immune() -> bool:
	return state == State.DORMANT or state == State.INTRO or state == State.TRANSITION


func is_telegraphing() -> bool:
	return state == State.TELEGRAPH and not is_dead


func current_stance_time() -> float:
	return phase2_stance_time if phase == 2 else stance_time


func telegraph_time(a: Attack) -> float:
	var base := sweep_telegraph
	match a:
		Attack.WAVE:
			base = wave_telegraph
		Attack.SUMMON:
			base = summon_telegraph
	return base * (phase2_telegraph_multiplier if phase == 2 else 1.0) * Settings.telegraph_scale()


# --- Stances --------------------------------------------------------------------

func hit_multiplier(hit: Hit) -> float:
	if stance == Stance.SLICK and hit.has_tag("kick") and not hit.has_tag("explosion"):
		return 0.0
	if stance == Stance.PLATED and hit.has_tag("magic"):
		return 0.0
	return 1.0


func resist_text(_hit: Hit) -> String:
	return "SLIPS OFF! Use magic" if stance == Stance.SLICK else "CLANG! Use kicks"


func weakness() -> Weakness:
	return Weakness.MAGIC if stance == Stance.SLICK else Weakness.KICKS


func take_hit(hit: Hit) -> void:
	var before := health
	super.take_hit(hit)
	_stance_hurt += before - health
	if not is_dead and _stance_hurt >= stance_damage and state != State.TRANSITION:
		swap_stance()


func swap_stance() -> void:
	stance = Stance.PLATED if stance == Stance.SLICK else Stance.SLICK
	_stance_t = current_stance_time()
	_stance_hurt = 0.0
	_swap_flash = 0.5
	Audio.play("switch_mode", -2.0, 0.0)
	Fx.burst(global_position, SLICK_TINT if stance == Stance.SLICK else PLATED_TINT, 60.0, 0.35)
	Fx.text(global_position + Vector2(0, -100), "MAGIC ONLY!" if stance == Stance.SLICK else "KICKS ONLY!",
		SLICK_TINT if stance == Stance.SLICK else PlayerCombat.CARL_COLOR, 20)


# --- AI ---------------------------------------------------------------------------

func _ai(delta: float) -> void:
	_anim += delta
	_sweep_fx = maxf(_sweep_fx - delta, 0.0)
	_swap_flash = maxf(_swap_flash - delta, 0.0)
	rats = rats.filter(func(r: EnemyBase) -> bool: return is_instance_valid(r) and not r.is_dead)
	var player := get_player()
	if player == null or player.health.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		return
	if state != State.DORMANT and state != State.INTRO and state != State.TRANSITION:
		_stance_t -= delta
		if _stance_t <= 0.0:
			swap_stance()
	match state:
		State.DORMANT:
			velocity.x = 0.0
		State.INTRO, State.TRANSITION, State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = State.APPROACH
				_t = think_time * (0.6 if phase == 2 else 1.0)
		State.APPROACH:
			_face(player)
			var dx := absf(player.global_position.x - global_position.x)
			if dx > sweep_reach * 0.6 and not is_wall_ahead(facing):
				velocity.x = facing * approach_speed
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
		State.ACTIVE:
			_t -= delta
			if _t <= 0.0:
				state = State.RECOVER
				_t = recovery * (phase2_recovery_multiplier if phase == 2 else 1.0)


func _face(player: Player) -> void:
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 4.0:
		facing = 1 if dx > 0.0 else -1


func _pick_attack(player: Player) -> Attack:
	if forced_attack >= 0:
		return forced_attack as Attack
	var near := absf(player.global_position.x - global_position.x) < sweep_reach
	var options: Array[int] = [Attack.WAVE]
	options.append(Attack.SWEEP if near else Attack.WAVE)
	if near:
		options.append(Attack.SWEEP)
	if rats.size() < max_rats:
		options.append(Attack.SUMMON)
	var choice: int = options[rng.randi() % options.size()]
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
	state = State.TELEGRAPH
	_t = telegraph_time(a)
	velocity.x = 0.0
	Audio.play("boss_warning", -4.0, 0.0)


func _execute() -> void:
	state = State.ACTIVE
	_t = 0.35
	match attack:
		Attack.SWEEP:
			_sweep()
		Attack.WAVE:
			_wave()
		Attack.SUMMON:
			_summon()


func _sweep() -> void:
	_sweep_fx = 0.3
	var feet := global_position + Vector2(0, body_size.y * 0.5)
	var hit_box := Vector2(sweep_reach * 2.0 + body_size.x, sweep_height)
	for target in HitQuery.box(self, feet - Vector2(0, sweep_height * 0.5), hit_box, HitQuery.LAYER_PLAYER):
		if target is Player:
			var dir := 1.0 if (target as Player).global_position.x >= global_position.x else -1.0
			(target as Player).take_hit(Hit.new(sweep_damage, Vector2(380 * dir, -260), self, PackedStringArray(["melee"])))
	Audio.play("kick_heavy")
	Fx.shake(0.35)


func _wave() -> void:
	var feet := global_position + Vector2(0, body_size.y * 0.5)
	for dir in [-1, 1]:
		var wave := Shockwave.new()
		wave.direction = dir
		wave.speed = wave_speed
		wave.max_range = phase2_wave_range if phase == 2 else wave_range
		wave.height = 26.0
		wave.hit = Hit.new(wave_damage, Vector2(220 * dir, -300), self, PackedStringArray(["shockwave"]))
		get_parent().add_child(wave)
		wave.global_position = feet + Vector2(dir * body_size.x * 0.5, 0)
	Audio.play("slam")
	Fx.shake(0.5)
	Fx.burst(feet, Color("#5a8a4a"), 50.0, 0.3)


func _summon() -> void:
	Audio.play("squeak")
	var room := get_parent()
	var bounds_x := Vector2(64.0, 0.0)
	var r := room.get_parent() as RoomBase
	if r:
		bounds_x = Vector2(r.bounds.position.x + 64.0, r.bounds.end.x - 64.0)
	var count := phase2_rats_per_call if phase == 2 else rats_per_call
	for i in count:
		if rats.size() >= max_rats:
			break
		var rat := RAT_SCENE.instantiate() as EnemyBase
		rat.potion_drop_chance = 0.0
		rat.gold_value = 0
		var left := i % 2 == 0
		rat.position = Vector2(bounds_x.x if left else bounds_x.y, position.y + body_size.y * 0.5 - 10.0)
		room.add_child(rat)
		rats.append(rat)
		Fx.burst(rat.global_position, Color("#5a8a4a"), 24.0, 0.3)


func _enter_phase_two() -> void:
	state = State.TRANSITION
	_t = transition_time
	velocity.x = 0.0
	Fx.shake(0.8)
	Fx.burst(global_position, Settings.warn_color(), 70.0, 0.5)
	Fx.text(global_position + Vector2(0, -100), "FURIOUS!", Settings.warn_color(), 26)
	Audio.play("boss_roar")


func _on_died() -> void:
	state = State.DORMANT
	Fx.shake(0.9)
	Fx.hit_stop(0.2)
	Fx.burst(global_position, SLICK_TINT, 110.0, 0.7)
	for rat in rats:
		if is_instance_valid(rat) and not rat.is_dead:
			rat.die()
	drop_rewards()


func body_color() -> Color:
	return FUR


func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var tint := SLICK_TINT if stance == Stance.SLICK else PLATED_TINT
	var fur := FUR.lerp(tint, 0.35 + 0.15 * sin(_anim * 3.0))
	if hit_flash() > 0.0 or _swap_flash > 0.0:
		fur = fur.lerp(Color.WHITE, 0.6)
	if phase == 2:
		fur = fur.lerp(Color("#a8403a"), 0.25)
	if is_telegraphing():
		fur = fur.lerp(Settings.warn_color(), 0.25 + 0.2 * sin(_anim * 30.0))
	fur.a = alpha
	var h := body_size.y
	var w := body_size.x
	var feet := h * 0.5
	var rear := 0.0
	if state == State.TELEGRAPH and attack == Attack.WAVE:
		rear = 14.0
	# Telegraph markers on the floor.
	if is_telegraphing() and attack == Attack.SWEEP:
		var k := 0.5 + 0.5 * sin(_anim * 25.0)
		draw_rect(Rect2(-sweep_reach - w * 0.5, feet - 6, sweep_reach * 2.0 + w, 6), Color(Settings.warn_color(), 0.35 + 0.35 * k))
	if _sweep_fx > 0.0:
		draw_rect(Rect2(-sweep_reach - w * 0.5, feet - sweep_height, sweep_reach * 2.0 + w, sweep_height),
			Color(1, 0.6, 0.4, _sweep_fx * 1.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	# Tail.
	var swish := sin(_anim * 4.0) * 8.0
	if state == State.TELEGRAPH and attack == Attack.SWEEP:
		swish = 18.0
	draw_polyline(PackedVector2Array([Vector2(-w * 0.45, feet - 12), Vector2(-w * 0.9, feet - 20 + swish),
		Vector2(-w * 1.3, feet - 8 - swish)]), Color(Color("#e8a0a8"), alpha), 5.0)
	# Body and head.
	draw_circle(Vector2(-6, feet - h * 0.42 - rear * 0.5), h * 0.42, fur)
	var head := Vector2(w * 0.32, feet - h * 0.62 - rear)
	draw_circle(head, h * 0.25, fur)
	draw_colored_polygon(PackedVector2Array([head + Vector2(10, -2), head + Vector2(30, 6), head + Vector2(10, 12)]), fur)
	draw_circle(head + Vector2(30, 6), 3.5, Color(Color("#e8a0a8"), alpha))
	draw_circle(head + Vector2(-4, -16), 7.0, Color(Color("#c08088"), alpha))
	draw_circle(head + Vector2(8, -2), 3.0, Color(1, 0.25, 0.2, alpha))
	# Plated stance: steel scales on the back.
	if stance == Stance.PLATED and not is_dead:
		for i in 4:
			var a := PI + PI * (0.2 + 0.18 * i)
			var c := Vector2(-6, feet - h * 0.42 - rear * 0.5) + Vector2(cos(a), sin(a)) * h * 0.36
			draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), Color(PLATED_TINT, alpha))
			draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), Color(PLATED_TINT.darkened(0.4), alpha), false, 1.5)
	# Bottle-cap crown.
	var crown := head + Vector2(-2, -h * 0.25 - 4)
	var pts := PackedVector2Array()
	for i in 9:
		var r := 11.0 if i % 2 == 0 else 7.0
		var a := PI + PI * i / 8.0
		pts.append(crown + Vector2(cos(a) * r, sin(a) * r * 0.8))
	draw_colored_polygon(pts, Color(Color("#d8b030"), alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_telegraphing():
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-12, -h * 0.5 - 30), "!!", HORIZONTAL_ALIGNMENT_CENTER, 24, 26, 5, Color.BLACK)
		draw_string(font, Vector2(-12, -h * 0.5 - 30), "!!", HORIZONTAL_ALIGNMENT_CENTER, 24, 26, Settings.warn_color())
	if not is_dormant():
		draw_weakness(Vector2(0, -h * 0.5 - 52))
