class_name TrainingDummy
extends EnemyBase
## Practice room target: a straw dummy on a post. It never dies (its health
## refills), never attacks, and shows the damage you dealt over the last
## few seconds. `kind` makes it behave like a shielded (magic only) or
## armored (kicks only) enemy for practising switches.

enum Kind { PLAIN, MAGIC_ONLY, KICKS_ONLY }

@export var kind := Kind.PLAIN

## Damage dealt in the last `WINDOW` seconds.
var recent_damage := 0.0
var _hits: Array[Vector2] = []  # (time, amount)
var _clock := 0.0

const WINDOW := 3.0


func _ready() -> void:
	super._ready()
	ai_enabled = false
	gold_value = 0
	potion_drop_chance = 0.0
	knockback_multiplier = 0.0
	display_name = "Training Dummy"


func _physics_process(delta: float) -> void:
	_clock += delta
	while not _hits.is_empty() and _clock - _hits[0].x > WINDOW:
		_hits.pop_front()
	recent_damage = 0.0
	for h in _hits:
		recent_damage += h.y
	super._physics_process(delta)


func take_hit(hit: Hit) -> void:
	# Never dies: top up before any hit that could finish it.
	if health < max_health * 0.5 or hit.damage * 4.0 >= health:
		health = max_health
	var before := health
	super.take_hit(hit)
	var dealt := before - health
	if dealt > 0.0:
		_hits.append(Vector2(_clock, dealt))


## Never engages: practice shouldn't count as combat.
func set_engaged(_value: bool) -> void:
	pass


func hit_multiplier(hit: Hit) -> float:
	match kind:
		Kind.MAGIC_ONLY:
			return 1.0 if hit.has_tag("magic") or hit.has_tag("explosion") else 0.0
		Kind.KICKS_ONLY:
			return 1.0 if hit.has_tag("kick") or hit.has_tag("explosion") else 0.0
	return 1.0


func weakness() -> Weakness:
	match kind:
		Kind.MAGIC_ONLY:
			return Weakness.MAGIC
		Kind.KICKS_ONLY:
			return Weakness.KICKS
	return Weakness.NONE


func _draw() -> void:
	var straw := Color("#d8b860") if hit_flash() <= 0.0 else Color.WHITE
	draw_rect(Rect2(-3, 0, 6, 28), Color("#6a4a2a"))
	draw_rect(Rect2(-12, -20, 24, 26), straw)
	draw_line(Vector2(-12, -6), Vector2(12, -6), Color("#a08040"), 2.0)
	draw_circle(Vector2(0, -28), 9.0, straw)
	draw_line(Vector2(-4, -31), Vector2(-1, -28), Color.BLACK, 1.5)
	draw_line(Vector2(-1, -31), Vector2(-4, -28), Color.BLACK, 1.5)
	draw_line(Vector2(2, -31), Vector2(5, -28), Color.BLACK, 1.5)
	draw_line(Vector2(5, -31), Vector2(2, -28), Color.BLACK, 1.5)
	var font := ThemeDB.fallback_font
	var line := "%d dmg / %ds" % [roundi(recent_damage), roundi(WINDOW)]
	draw_string_outline(font, Vector2(-50, -48), line, HORIZONTAL_ALIGNMENT_CENTER, 100, 13, 4, Color.BLACK)
	draw_string(font, Vector2(-50, -48), line, HORIZONTAL_ALIGNMENT_CENTER, 100, 13, Color("#ffd34d"))
	draw_weakness(Vector2(0, -64))
