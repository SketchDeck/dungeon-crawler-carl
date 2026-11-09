class_name FireTrail
extends Node2D
## Hot Feet: a strip of fire left behind by a dodge. Burns enemies standing in
## it every `tick` seconds, then dies down. Positioned at floor level where the
## dodge started; extends `length` pixels in `direction`.

var source: Node
var damage := 6.0
var length := 150.0
var direction := 1
var lifetime := 1.8
var tick := 0.3

var _t := 0.0
var _tick_t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	if _t >= lifetime:
		queue_free()
		return
	if _tick_t <= 0.0:
		_tick_t = tick
		var center := global_position + Vector2(direction * length * 0.5, -18.0)
		for body in HitQuery.box(self, center, Vector2(length, 36.0), HitQuery.LAYER_ENEMIES):
			if body is EnemyBase:
				(body as EnemyBase).take_hit(Hit.new(damage, Vector2.ZERO, source, PackedStringArray(["fire"])))
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - _t) / 0.5, 0.0, 1.0)
	var n := int(length / 14.0)
	for i in n:
		var x := direction * (i * 14.0 + 7.0)
		var h := 10.0 + 8.0 * absf(sin(_t * 12.0 + i * 1.7))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 0), Vector2(x, -h), Vector2(x + 6, 0)]),
			Color(1.0, 0.45, 0.15, 0.75 * fade))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 0), Vector2(x, -h * 0.55), Vector2(x + 3, 0)]),
			Color(1.0, 0.9, 0.4, 0.85 * fade))
