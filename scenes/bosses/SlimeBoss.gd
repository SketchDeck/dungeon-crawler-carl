class_name SlimeBoss
extends BossBase
## Floor 2 boss: the Mutating Slime.
##
## Phase 1:
##   Volley    - swells up while dotted arcs show where each glob will land,
##               then lobs a fan of globs toward the player. Fixed arcs, so
##               there are safe gaps between the landing spots.
##   Jump slam - crouches while a red marker shows where it will land (where
##               the player stood), then leaps there. Landing on the player
##               hurts, and it leaves an acid pool behind.
## It never lands on one-way platforms (it sinks through them back to the
## floor), so the volley previews always end on the floor.
## Phase 2 (below 50% HP): faster telegraphs and shorter recovery, more globs,
## every glob leaves a small acid pool, bigger landing pools, and it splits
## off mini slimes. When it dies the minis and all acid go with it.

enum State { DORMANT, INTRO, THINK, TELEGRAPH, AIRBORNE, ACTIVE, RECOVER, TRANSITION }
enum Attack { VOLLEY, JUMP, SPAWN }

const COLOR_P1 := Color("#5ccf6a")
const COLOR_P2 := Color("#9a5cff")
const WARN := Color("#ff3a2a")
const MINI_SCENE := preload("res://scenes/enemies/MiniSlime.tscn")

@export_group("Timing")
@export var intro_time := 1.4
@export var think_time := 0.8
@export var volley_telegraph := 0.95
@export var jump_telegraph := 0.8
@export var spawn_telegraph := 0.7
@export var recovery := 1.2
@export var transition_time := 1.8
@export_group("Phase 2")
@export var phase2_telegraph_multiplier := 0.75
@export var phase2_recovery_multiplier := 0.6
@export_group("Volley")
@export var glob_damage := 12.0
## Steep arcs leave clear gaps between landing spots: a glob passes over a
## gap's midpoint high enough to clear the player.
@export var glob_launch_speed := 680.0
## Horizontal speeds of the globs (one glob each), toward the player.
@export var volley_speeds: Array[float] = [130.0, 220.0, 310.0, 400.0, 490.0]
@export var phase2_volley_speeds: Array[float] = [100.0, 170.0, 240.0, 310.0, 380.0, 450.0, 520.0]
@export var glob_knockback := Vector2(180, -200)
@export_group("Jump")
@export var jump_velocity := 720.0
@export var max_jump_speed := 520.0
@export var land_damage := 20.0
@export var land_knockback := Vector2(380, -320)
@export var pool_width := 150.0
@export var pool_duration := 2.5
@export var phase2_pool_duration := 3.5
@export var pool_damage := 8.0
@export_group("Minis")
@export var minis_per_spawn := 2
@export var max_minis := 4

var state := State.DORMANT
var attack := Attack.VOLLEY
## Tests set this to choose the next attack instead of rolling for it.
var forced_attack := -1
var target_x := 0.0
var minis: Array[EnemyBase] = []

var _t := 0.0
var _air_t := 0.0
var _hit_this_jump := false
var _history: Array[int] = []
var _anim := 0.0


func _init() -> void:
	boss_name = "MUTATING SLIME"
	boss_hint = "Dotted arcs show where globs land. A red marker shows where it jumps. Keep moving!"


func _ready() -> void:
	super._ready()
	facing = -1


func is_dormant() -> bool:
	return state == State.DORMANT


func is_immune() -> bool:
	return state == State.DORMANT or state == State.INTRO or state == State.TRANSITION


func is_telegraphing() -> bool:
	return state == State.TELEGRAPH and not is_dead


func start_fight() -> void:
	if state != State.DORMANT or is_dead:
		return
	for platform in get_tree().get_nodes_in_group("one_way_platforms"):
		add_collision_exception_with(platform)
	state = State.INTRO
	_t = intro_time
	set_engaged(true)
	Fx.shake(0.5)
	Fx.text(global_position + Vector2(0, -70), "BLORP!", COLOR_P1, 24)
	fight_started.emit()


func telegraph_time(a: Attack) -> float:
	var base := volley_telegraph
	match a:
		Attack.JUMP:
			base = jump_telegraph
		Attack.SPAWN:
			base = spawn_telegraph
	return base * (phase2_telegraph_multiplier if phase == 2 else 1.0)


func recovery_time() -> float:
	return recovery * (phase2_recovery_multiplier if phase == 2 else 1.0)


func current_volley_speeds() -> Array[float]:
	return phase2_volley_speeds if phase == 2 else volley_speeds


func glob_origin() -> Vector2:
	return global_position + Vector2(0, -body_size.y * 0.5)


func feet_y() -> float:
	return global_position.y + body_size.y * 0.5


## Launch velocities for the next volley (toward the current facing).
func volley_velocities() -> Array[Vector2]:
	var list: Array[Vector2] = []
	for vx in current_volley_speeds():
		list.append(Vector2(vx * facing, -glob_launch_speed))
	return list


## Where a glob launched with `vel` first touches the floor.
func glob_landing_x(vel: Vector2) -> float:
	return SlimeGlob.landing_x(glob_origin(), vel, feet_y() - SlimeGlob.DEFAULT_RADIUS)


func alive_minis() -> int:
	var n := 0
	for m in minis:
		if is_instance_valid(m) and not m.is_dead:
			n += 1
	return n


# --- AI ---------------------------------------------------------------------------

func _ai(delta: float) -> void:
	_anim += delta
	var player := get_player()
	var player_ok := player != null and not player.health.is_dead
	if not player_ok and state != State.AIRBORNE:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		return
	match state:
		State.DORMANT:
			velocity.x = 0.0
		State.INTRO, State.TRANSITION, State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = State.THINK
				_t = think_time * (0.6 if phase == 2 else 1.0)
		State.THINK:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_face(player)
			_t -= delta
			if _t <= 0.0:
				_begin_attack(_pick_attack())
		State.TELEGRAPH:
			velocity.x = 0.0
			_t -= delta
			if _t <= 0.0:
				_execute()
		State.AIRBORNE:
			_air_t += delta
			if player_ok and not _hit_this_jump:
				_jump_contact(player)
			if _air_t > 0.1 and is_on_floor():
				_land()
		State.ACTIVE:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = State.RECOVER
				_t = recovery_time()


func _face(player: Player) -> void:
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 4.0:
		facing = 1 if dx > 0.0 else -1


func _pick_attack() -> Attack:
	if forced_attack >= 0:
		return forced_attack as Attack
	var options: Array[int] = [Attack.VOLLEY, Attack.JUMP]
	if phase == 2 and alive_minis() < max_minis - 1:
		options.append(Attack.SPAWN)
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
	var player := get_player()
	if player:
		_face(player)
		target_x = player.global_position.x
	state = State.TELEGRAPH
	_t = telegraph_time(a)


func _execute() -> void:
	match attack:
		Attack.VOLLEY:
			_volley()
			state = State.ACTIVE
			_t = 0.3
		Attack.JUMP:
			_jump()
		Attack.SPAWN:
			_spawn_minis()
			state = State.ACTIVE
			_t = 0.3


func _volley() -> void:
	for vel in volley_velocities():
		var glob := SlimeGlob.new()
		glob.velocity = vel
		glob.hit = Hit.new(glob_damage, Vector2(glob_knockback.x * signf(vel.x), glob_knockback.y), self,
			PackedStringArray(["glob"]))
		glob.leaves_pool = phase == 2
		glob.pool_duration = phase2_pool_duration
		get_parent().add_child(glob)
		glob.global_position = glob_origin()
	Fx.burst(glob_origin(), COLOR_P1, 40.0, 0.25)
	Fx.shake(0.2)


func _jump() -> void:
	var air_time := 2.0 * jump_velocity / gravity
	var vx := clampf((target_x - global_position.x) / air_time, -max_jump_speed, max_jump_speed)
	velocity = Vector2(vx, -jump_velocity)
	state = State.AIRBORNE
	_air_t = 0.0
	_hit_this_jump = false


func _jump_contact(player: Player) -> void:
	for target in HitQuery.box(self, global_position, body_size, HitQuery.LAYER_PLAYER):
		if target == player:
			var dir := 1.0 if player.global_position.x >= global_position.x else -1.0
			if player.take_hit(Hit.new(land_damage, Vector2(land_knockback.x * dir, land_knockback.y), self,
					PackedStringArray(["slam"]))):
				_hit_this_jump = true


func _land() -> void:
	velocity.x = 0.0
	var pool := AcidPool.new()
	pool.width = pool_width * (1.3 if phase == 2 else 1.0)
	pool.duration = phase2_pool_duration if phase == 2 else pool_duration
	pool.damage = pool_damage
	get_parent().add_child(pool)
	pool.global_position = Vector2(global_position.x, feet_y())
	Fx.shake(0.55)
	Fx.burst(Vector2(global_position.x, feet_y()), COLOR_P1, 70.0, 0.35)
	state = State.ACTIVE
	_t = 0.3


func _spawn_minis() -> void:
	for i in minis_per_spawn:
		var mini := MINI_SCENE.instantiate() as EnemyBase
		var side := -1.0 if i % 2 == 0 else 1.0
		mini.position = position + Vector2(side * (body_size.x * 0.5 + 14.0), body_size.y * 0.5 - 8.0)
		get_parent().add_child(mini)
		mini.velocity = Vector2(side * 160.0, -300.0)
		mini.set_engaged(true)
		minis.append(mini)
	Fx.burst(global_position, COLOR_P2, 60.0, 0.3)
	Fx.text(global_position + Vector2(0, -70), "SPLIT!", COLOR_P2, 18)


func _enter_phase_two() -> void:
	state = State.TRANSITION
	_t = transition_time
	velocity.x = 0.0
	Fx.shake(0.8)
	Fx.burst(global_position, COLOR_P2, 90.0, 0.5)
	Fx.text(global_position + Vector2(0, -90), "MUTATING!", COLOR_P2, 26)


func _on_died() -> void:
	state = State.DORMANT
	Fx.shake(0.9)
	Fx.hit_stop(0.2)
	Fx.burst(global_position, COLOR_P1, 110.0, 0.7)
	for m in minis:
		if is_instance_valid(m) and not m.is_dead:
			m.die()
	for node in get_tree().get_nodes_in_group("boss_hazards"):
		node.queue_free()
	drop_rewards()


func body_color() -> Color:
	return COLOR_P2 if phase == 2 else COLOR_P1


# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var w := body_size.x * 0.5
	var h := body_size.y
	var feet := h * 0.5

	if is_telegraphing():
		_draw_telegraph(feet)

	var c := body_color()
	if hit_flash() > 0.0:
		c = c.lerp(Color.WHITE, 0.7)
	elif is_telegraphing():
		c = c.lerp(Color("#fff27a"), 0.25 + 0.2 * sin(_anim * 30.0))
	c.a = 0.9 * alpha
	var sx := 1.0
	var sy := 1.0 + 0.04 * sin(_anim * 3.0)
	if state == State.TELEGRAPH:
		var k := 1.0 - _t / maxf(telegraph_time(attack), 0.01)
		match attack:
			Attack.VOLLEY:
				sx = 1.0 + 0.12 * k
				sy = 1.0 + 0.15 * k
			Attack.JUMP:
				sx = 1.0 + 0.25 * k
				sy = 1.0 - 0.3 * k
			Attack.SPAWN:
				sx = 1.0 + 0.08 * sin(_anim * 40.0)
	elif state == State.AIRBORNE:
		sx = 0.85
		sy = 1.2
	elif state == State.TRANSITION:
		sx = 1.0 + 0.1 * sin(_anim * 50.0)
	if is_dead:
		sy *= 1.0 - 0.8 * death_progress()
		sx *= 1.0 + 0.5 * death_progress()
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		var wobble := 1.0 + 0.04 * sin(_anim * 6.0 + i)
		pts.append(Vector2(cos(a) * w * sx * wobble, feet + sin(a) * h * sy * wobble))
	pts.append(Vector2(w * sx, feet))
	pts.append(Vector2(-w * sx, feet))
	if phase == 2 and not is_dead:
		draw_circle(Vector2(0, feet - h * 0.5), w * 1.2, Color(COLOR_P2, 0.12))
	draw_colored_polygon(pts, c)
	draw_polyline(pts, Color(c.darkened(0.4), alpha), 2.0)
	# Glowing core (it's mutating) and floating bits inside.
	var core := Vector2(0, feet - h * 0.45 * sy)
	draw_circle(core, w * 0.28, Color(1, 1, 0.6, 0.5 * alpha) if phase == 1 else Color(1, 0.4, 0.8, 0.6 * alpha))
	for i in 3:
		var a := _anim * (1.0 + i * 0.4) + i * 2.0
		draw_circle(core + Vector2(cos(a), sin(a)) * w * 0.5, 4.0, Color(0, 0, 0, 0.25 * alpha))
	# Eyes.
	for ex in [-0.3, 0.3]:
		var e := Vector2((ex + 0.15 * facing) * w, feet - h * 0.72 * sy)
		draw_circle(e, 7.0, Color(1, 1, 1, alpha))
		draw_circle(e + Vector2(facing * 2.0, 1.0), 3.5, Color(0.6, 0, 0, alpha) if phase == 2 else Color(0, 0, 0, alpha))
	draw_circle(Vector2(-w * 0.45 * sx, feet - h * 0.8 * sy), 6.0, Color(1, 1, 1, 0.35 * alpha))

	if is_telegraphing():
		var font := ThemeDB.fallback_font
		var mark := "!!" if attack == Attack.JUMP else "!"
		draw_string_outline(font, Vector2(-20, -h * 0.5 - 18), mark, HORIZONTAL_ALIGNMENT_CENTER, 40, 30, 5, Color.BLACK)
		draw_string(font, Vector2(-20, -h * 0.5 - 18), mark, HORIZONTAL_ALIGNMENT_CENTER, 40, 30, WARN)


func _draw_telegraph(feet: float) -> void:
	var progress := 1.0 - clampf(_t / maxf(telegraph_time(attack), 0.01), 0.0, 1.0)
	var pulse := 0.35 + 0.25 * sin(_anim * 24.0)
	match attack:
		Attack.VOLLEY:
			# Dotted arc for every glob, ending in a landing mark.
			var origin := to_local(glob_origin())
			# Arcs stop at the room's walls, where the globs would splat.
			var room := get_parent().get_parent() as RoomBase
			var min_x := -INF
			var max_x := INF
			if room:
				min_x = to_local(room.global_position + Vector2(room.bounds.position.x + 32.0, 0)).x
				max_x = to_local(room.global_position + Vector2(room.bounds.end.x - 32.0, 0)).x
			for vel in volley_velocities():
				var p := origin
				var v := vel
				var dt := 0.05
				var steps := 0
				while p.y <= feet and steps < 80 and p.x > min_x and p.x < max_x:
					if steps % 2 == 0:
						draw_circle(p, 2.0, Color(0.6, 1.0, 0.4, 0.25 + 0.4 * progress))
					v.y += SlimeGlob.GRAVITY * dt
					p += v * dt
					steps += 1
				var land_x := to_local(Vector2(glob_landing_x(vel), 0)).x
				if land_x > min_x and land_x < max_x:
					draw_rect(Rect2(land_x - 9, feet - 4, 18, 4), Color(WARN, pulse + 0.2))
		Attack.JUMP:
			var x := to_local(Vector2(target_x, 0)).x
			var r := pool_width * 0.5 * (1.3 if phase == 2 else 1.0)
			draw_set_transform(Vector2(x, feet - 2), 0.0, Vector2(1.0, 0.2))
			draw_circle(Vector2.ZERO, r, Color(WARN, 0.12 + 0.2 * progress))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(WARN, pulse + 0.2), 6.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_line(Vector2(x, feet - 70), Vector2(x, feet - 20), Color(WARN, pulse + 0.2), 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 8, feet - 30), Vector2(x + 8, feet - 30), Vector2(x, feet - 16)]),
				Color(WARN, pulse + 0.2))
		Attack.SPAWN:
			for i in 6:
				var a := _anim * 4.0 + i * TAU / 6.0
				draw_circle(Vector2(cos(a) * body_size.x * 0.6, feet - body_size.y * 0.5 + sin(a) * 20.0), 5.0,
					Color(COLOR_P2, 0.6))
