class_name Decor
extends RefCounted
## Procedural room art. Static helpers draw into any CanvasItem, so RoomBackdrop (drawn once) and
## RoomBase (animated torches and motes) share one visual language.

const PALETTES := {
	"warrens": {
		"top": Color("#1a1328"), "bottom": Color("#0b0712"),
		"brick": Color("#2f2439"), "brick_alt": Color("#372b44"), "mortar": Color("#150f1e"),
		"face": Color("#3b2c48"), "edge": Color("#9a7bb0"), "moss": Color("#6a4a7a"),
		"pillar": Color("#231a2d"), "glow": Color("#ffb347"), "mote": Color("#ffd29a"),
		"fog": Color("#6a3d8a"),
	},
	"fungal": {
		"top": Color("#0e2a2b"), "bottom": Color("#051314"),
		"brick": Color("#1e4339"), "brick_alt": Color("#245244"), "mortar": Color("#0a1d1a"),
		"face": Color("#25594a"), "edge": Color("#86e7aa"), "moss": Color("#2f8a5b"),
		"pillar": Color("#15362f"), "glow": Color("#9dff7a"), "mote": Color("#b8ff9a"),
		"fog": Color("#1f7a6a"),
	},
}


static func palette(theme: String) -> Dictionary:
	return PALETTES.get(theme, PALETTES["warrens"])


static func draw_background(c: CanvasItem, pal: Dictionary, size: Vector2) -> void:
	var bands := 28
	var span := size.y + 80.0
	for i in range(bands):
		var t := float(i) / float(bands)
		var col: Color = (pal.top as Color).lerp(pal.bottom, t)
		c.draw_rect(Rect2(-40.0, -40.0 + t * span, size.x + 80.0, span / float(bands) + 1.0), col)
	# Soft fog banks give depth without any textures.
	var fog: Color = pal.fog
	for i in range(7):
		var x := 90.0 + i * 190.0 + hash_float(i) * 60.0
		var y := 420.0 + hash_float(i + 9) * 120.0
		c.draw_circle(Vector2(x, y), 120.0 + hash_float(i + 3) * 40.0, Color(fog.r, fog.g, fog.b, 0.028))


static func draw_pillars(c: CanvasItem, pal: Dictionary, size: Vector2) -> void:
	var pillar: Color = pal.pillar
	var edge: Color = pal.edge
	for x in [170.0, 640.0, 1110.0]:
		var base_x: float = x - 28.0
		c.draw_rect(Rect2(base_x, 40.0, 56.0, 560.0), pillar)
		c.draw_rect(Rect2(base_x - 8.0, 30.0, 72.0, 14.0), pillar.lightened(0.08))
		c.draw_rect(Rect2(base_x - 8.0, 592.0, 72.0, 14.0), pillar.lightened(0.08))
		for i in range(4):
			var fx := base_x + 10.0 + i * 11.0
			c.draw_line(Vector2(fx, 60.0), Vector2(fx, 580.0), pillar.darkened(0.35), 2.0, true)
		c.draw_line(Vector2(base_x, 40.0), Vector2(base_x, 600.0), Color(edge.r, edge.g, edge.b, 0.12), 1.0, true)


## Stone block for walls, floor, and ceiling.
static func draw_shell_block(c: CanvasItem, pal: Dictionary, r: Rect2) -> void:
	_bricks(c, pal, r, 40.0, 20.0)
	c.draw_rect(r, Color(0.0, 0.0, 0.0, 0.25), false, 2.0)


## Platform with a lit top edge and a brick face. One-way platforms are thinner and metallic.
static func draw_platform(c: CanvasItem, pal: Dictionary, r: Rect2, one_way: bool) -> void:
	var shadow := Rect2(r.position + Vector2(4.0, 6.0), r.size)
	c.draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.3))
	if one_way:
		c.draw_rect(r, Color("#6f7d8f"))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Color("#d8e4f0"))
		c.draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 3.0), Vector2(r.size.x, 3.0)), Color("#3b4656"))
		for x in range(int(r.size.x / 14.0)):
			var px := r.position.x + 7.0 + x * 14.0
			c.draw_line(Vector2(px, r.position.y + 3.0), Vector2(px, r.end.y - 3.0), Color("#4b5666"), 1.0, true)
		return
	_bricks(c, pal, Rect2(r.position + Vector2(0.0, 3.0), Vector2(r.size.x, r.size.y - 3.0)), 32.0, 16.0)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 5.0)), pal.edge)
	c.draw_rect(Rect2(r.position + Vector2(0.0, 5.0), Vector2(r.size.x, 2.0)), Color(1.0, 1.0, 1.0, 0.12))
	var drip_count := int(r.size.x / 40.0)
	for i in range(drip_count):
		var dx := r.position.x + 10.0 + i * 40.0 + hash_float(i + int(r.position.x)) * 14.0
		var length := 4.0 + hash_float(i * 3 + int(r.position.y)) * 8.0
		c.draw_rect(Rect2(dx, r.position.y + 5.0, 3.0, length), pal.moss)
	c.draw_rect(r, Color(0.0, 0.0, 0.0, 0.35), false, 1.5)


static func _bricks(c: CanvasItem, pal: Dictionary, r: Rect2, bw: float, bh: float) -> void:
	c.draw_rect(r, pal.mortar)
	var rows := int(ceil(r.size.y / bh))
	var cols := int(ceil(r.size.x / bw)) + 1
	for row in range(rows):
		var offset := 0.0 if row % 2 == 0 else bw * 0.5
		for col in range(cols):
			var x := r.position.x + col * bw - offset
			var y := r.position.y + row * bh
			var cell := Rect2(x + 1.0, y + 1.0, bw - 2.0, bh - 2.0)
			var clipped := cell.intersection(r)
			if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
				continue
			var tone: Color = pal.brick if hash_float(row * 31 + col) < 0.6 else pal.brick_alt
			c.draw_rect(clipped, tone)
			c.draw_rect(Rect2(clipped.position, Vector2(clipped.size.x, 2.0)), tone.lightened(0.07))


static func draw_torches(c: CanvasItem, pal: Dictionary, size: Vector2, clock: float) -> void:
	var glow: Color = pal.glow
	var mote: Color = pal.mote
	for i in range(3):
		var x := 170.0 + i * 470.0
		var y := 276.0 + (i % 2) * 22.0
		var flicker := 0.5 + 0.5 * sin(clock * 11.0 + i * 1.7) * sin(clock * 6.3 + i)
		# Stacked translucent discs fake a soft radial falloff: the centre is brightest.
		for k in range(6):
			var radius := 112.0 - k * 16.0
			c.draw_circle(Vector2(x, y - 6.0), radius, Color(glow.r, glow.g, glow.b, (0.011 + 0.005 * flicker) * (k + 1)))
		c.draw_rect(Rect2(x - 5.0, y, 10.0, 16.0), Color("#4a3a2a"))
		var flame_h := 14.0 + flicker * 6.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 6.0, y), Vector2(x, y - flame_h), Vector2(x + 6.0, y),
		]), Color("#ff8a3c"))
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3.0, y), Vector2(x, y - flame_h * 0.6), Vector2(x + 3.0, y),
		]), Color("#ffe08a"))
	for i in range(22):
		var seed_v := float(i) * 1.37
		var px := fposmod(hash_float(i) * size.x + sin(clock * 0.4 + seed_v) * 18.0, size.x)
		var py := fposmod(size.y - fposmod(clock * (12.0 + hash_float(i + 40) * 14.0) + hash_float(i + 80) * size.y, size.y), size.y)
		var alpha := 0.25 + 0.25 * sin(clock * 2.0 + seed_v)
		c.draw_circle(Vector2(px, py), 1.3 + hash_float(i + 5) * 1.2, Color(mote.r, mote.g, mote.b, alpha))


## Deterministic pseudo-random value in [0, 1) from an integer seed.
static func hash_float(n: int) -> float:
	var x := sin(float(n) * 12.9898 + 78.233) * 43758.5453
	return x - floor(x)
