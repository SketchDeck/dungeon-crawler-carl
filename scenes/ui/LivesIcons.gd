extends Control
## Row of heart icons: filled for remaining lives, outlined for lost ones.

var lives := 3:
	set(value):
		lives = value
		queue_redraw()
var max_lives := 3


func _draw() -> void:
	for i in max_lives:
		var c := Vector2(10 + i * 24, size.y * 0.5)
		var filled := i < lives
		var pts := PackedVector2Array()
		for k in 24:
			var t := TAU * k / 24.0
			# Classic heart curve, scaled to ~18px.
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			pts.append(c + Vector2(x, y) * 0.55)
		if filled:
			draw_colored_polygon(pts, Color("#ff4d6a"))
		pts.append(pts[0])
		draw_polyline(pts, Color("#ff4d6a") if filled else Color(1, 1, 1, 0.35), 1.5)
