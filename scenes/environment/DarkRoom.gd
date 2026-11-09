class_name DarkRoom
extends Node2D
## Makes a room dark: the screen is dimmed and only light sources show the
## way. Carl carries a small glow; Princess Donut's magic is much brighter
## (her glow grows in Donut mode, and every bolt lights its path). Doors,
## fountains and chests get a faint light so you can find them.

const DARKNESS := Color(0.09, 0.09, 0.13)

var player_light: PointLight2D
var _texture: GradientTexture2D


func _ready() -> void:
	var modulate_node := CanvasModulate.new()
	modulate_node.color = DARKNESS
	add_child(modulate_node)
	_texture = GradientTexture2D.new()
	_texture.width = 256
	_texture.height = 256
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_texture.gradient = g
	player_light = make_light(Color(1.0, 0.85, 0.65), 1.0)
	add_child(player_light)


func make_light(color: Color, scale_factor: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _texture
	light.color = color
	light.energy = 1.2
	light.texture_scale = scale_factor
	return light


## A dim marker light at a world position (doors, fountains, chests).
func add_marker(at: Vector2, color := Color(1.0, 0.8, 0.5)) -> void:
	var light := make_light(color, 0.55)
	light.energy = 0.8
	add_child(light)
	light.global_position = at


func player_light_scale(p: Player) -> float:
	return 2.4 if p.combat.mode == PlayerCombat.Mode.DONUT else 1.3


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		player_light.global_position = p.global_position
		player_light.texture_scale = move_toward(player_light.texture_scale, player_light_scale(p), delta * 4.0)
		player_light.color = Color(0.85, 0.7, 1.0) if p.combat.mode == PlayerCombat.Mode.DONUT else Color(1.0, 0.85, 0.65)
	for bolt in get_tree().get_nodes_in_group(MagicProjectile.GROUP):
		if (bolt as Node).get_node_or_null("Light") == null:
			var light := make_light(Color(0.8, 0.6, 1.0), 1.1)
			light.name = "Light"
			(bolt as Node).add_child(light)
