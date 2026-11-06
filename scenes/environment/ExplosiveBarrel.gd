class_name ExplosiveBarrel
extends StaticBody2D
## Explodes shortly after any attack hits it (or another explosion reaches
## it, so barrels chain). Hurts enemies and the player in the blast radius and
## knocks them away. Sits on the hittable layer only, so it never blocks
## movement. Origin is at the barrel's base.

@export var radius := 100.0
@export var enemy_damage := 30.0
@export var player_damage := 20.0
@export var knockback := 480.0
@export var fuse := 0.15

var lit := false
var _fuse_t := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = HitQuery.LAYER_HITTABLE
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	add_child(shape)


func take_hit(_hit: Hit) -> void:
	if lit:
		return
	lit = true
	_fuse_t = fuse


func _physics_process(delta: float) -> void:
	_t += delta
	if lit:
		_fuse_t -= delta
		if _fuse_t <= 0.0:
			explode()
			return
	queue_redraw()


func explode() -> void:
	set_physics_process(false)
	collision_layer = 0
	Explosion.detonate(self, global_position + Vector2(0, -15), radius, enemy_damage, knockback,
		HitQuery.LAYER_ENEMIES | HitQuery.LAYER_PLAYER | HitQuery.LAYER_HITTABLE, self,
		PackedStringArray(["explosion", "hazard", "heavy"]), Color("#ff7a1a"), player_damage)
	queue_free()


func _draw() -> void:
	var body := Color("#b0362a")
	if lit and int(_t * 30.0) % 2 == 0:
		body = Color("#ffe080")
	draw_rect(Rect2(-12, -30, 24, 30), body)
	draw_rect(Rect2(-12, -24, 24, 3), Color("#5a1a14"))
	draw_rect(Rect2(-12, -9, 24, 3), Color("#5a1a14"))
	# Hazard mark.
	draw_colored_polygon(PackedVector2Array([Vector2(0, -21), Vector2(-6, -12), Vector2(6, -12)]), Color("#ffd34d"))
	draw_rect(Rect2(-0.75, -19, 1.5, 4), Color.BLACK)
	draw_rect(Rect2(-12, -30, 24, 30), Color("#3a0e0a"), false, 1.5)
