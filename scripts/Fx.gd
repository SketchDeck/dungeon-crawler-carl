extends Node
## Autoload: lightweight game-feel helpers (screen shake, hit stop, placeholder effects).

var camera: GameCamera
## Disabled by the headless test runner so timers run at normal speed.
var hitstop_enabled := true

var _hitstop_active := false


func shake(amount: float) -> void:
	if is_instance_valid(camera) and Settings.screen_shake:
		camera.add_shake(amount)


func hit_stop(duration: float) -> void:
	if not hitstop_enabled or _hitstop_active or duration <= 0.0:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


## Brief slow motion (e.g. the last enemy in a room falls). Skipped while a
## hit stop runs and in tests.
func slow_motion(duration := 0.45, time_scale := 0.3) -> void:
	if not hitstop_enabled or _hitstop_active or duration <= 0.0:
		return
	_hitstop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func burst(pos: Vector2, color: Color, radius := 22.0, duration := 0.25) -> void:
	var effect := BurstEffect.new()
	effect.color = color
	effect.radius = radius
	effect.duration = duration
	_spawn(effect, pos)


func slash(pos: Vector2, facing: int, radius: float, color: Color, duration := 0.12) -> void:
	var effect := SlashEffect.new()
	effect.facing = facing
	effect.radius = radius
	effect.color = color
	effect.duration = duration
	_spawn(effect, pos)


func explosion(pos: Vector2, radius: float, color := Color("#ff9a3c"), duration := 0.4) -> void:
	var effect := ExplosionEffect.new()
	effect.radius = radius
	effect.color = color
	effect.duration = duration
	_spawn(effect, pos)
	shake(clampf(radius / 250.0, 0.2, 0.6))


func text(pos: Vector2, message: String, color := Color.WHITE, font_size := 16) -> void:
	var effect := FloatingText.new()
	effect.message = message
	effect.color = color
	effect.font_size = font_size
	_spawn(effect, pos)


func _spawn(effect: Node2D, pos: Vector2) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(effect)
	effect.global_position = pos
