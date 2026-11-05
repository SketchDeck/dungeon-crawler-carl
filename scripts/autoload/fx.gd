extends Node
## Global game feel: screen shake, hit-stop, particle bursts, floating numbers, rings and glows.
## Effects are spawned into the world node bound by Main, so they live in game space.

var _world: Node2D = null
var _camera: Camera2D = null
var _shake: float = 0.0
var _stop_token: int = 0


func bind(world: Node2D, camera: Camera2D) -> void:
	_world = world
	_camera = camera


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, 85.0 * delta)
	if _camera != null and is_instance_valid(_camera):
		if _shake > 0.1:
			_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		else:
			_camera.offset = Vector2.ZERO


## Adds screen shake. Strongest value wins, so overlapping hits do not stack into chaos.
func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 24.0)


## Briefly slows the game for impact. Uses real time for the timer, so it always ends.
func hitstop(duration: float = 0.05, time_scale: float = 0.06) -> void:
	_stop_token += 1
	var token := _stop_token
	Engine.time_scale = time_scale
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void:
		if token == _stop_token:
			Engine.time_scale = 1.0)


func burst(pos: Vector2, color: Color, amount: int = 14, speed: float = 220.0, life: float = 0.5) -> void:
	if _world == null:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 55
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0.0, 520.0)
	p.damping_min = 3.0
	p.damping_max = 6.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = grad
	p.emitting = true
	_world.add_child(p)
	_free_later(p, life + 0.3)


func text(pos: Vector2, msg: String, color: Color = Color.WHITE, font_size: int = 18) -> void:
	if _world == null:
		return
	var label := Label.new()
	label.text = msg
	label.position = pos + Vector2(-12.0, -24.0)
	label.z_index = 90
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	_world.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 40.0, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tw.finished.connect(label.queue_free)


func ring(pos: Vector2, color: Color, radius: float = 60.0, life: float = 0.3, width: float = 4.0) -> void:
	_spawn_shape("ring", pos, color, radius, life, width)


func glow(pos: Vector2, color: Color, radius: float = 40.0, life: float = 0.35) -> void:
	_spawn_shape("glow", pos, color, radius, life, 0.0)


func flash(pos: Vector2, color: Color, radius: float = 40.0, life: float = 0.15) -> void:
	_spawn_shape("flash", pos, color, radius, life, 0.0)


func _spawn_shape(kind: String, pos: Vector2, color: Color, radius: float, life: float, width: float) -> void:
	if _world == null:
		return
	var fx := ShapeFx.new()
	fx.kind = kind
	fx.color = color
	fx.radius = radius
	fx.life = life
	fx.width = width
	fx.position = pos
	_world.add_child(fx)


func _free_later(node: Node, seconds: float) -> void:
	# Connecting the method directly lets Godot drop the connection if the node is freed first.
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(node.queue_free)
