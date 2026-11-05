class_name HUD
extends CanvasLayer
## Health bar (with delayed "recent damage" ghost bar), HP text, potion count,
## combat/regeneration status and controls hint.

const GHOST_DELAY := 0.4
const GHOST_SPEED := 60.0
const FILL := Color("#d83a3a")
const FILL_REGEN := Color("#d8583a")
const REGEN_GREEN := Color("#7dff8a")

var _player: Player
var _current := 100.0
var _maximum := 100.0
var _ghost_value := 100.0
var _ghost_wait := 0.0
var _potion_pulse := 0.0
var _fill_box: StyleBoxFlat
var _ghost_fill_box: StyleBoxFlat
var _t := 0.0

@onready var _bar: ProgressBar = %HealthBar
@onready var _ghost: ProgressBar = %GhostBar
@onready var _hp_label: Label = %HPLabel
@onready var _potion_label: Label = %PotionLabel
@onready var _potion_row: Control = %PotionRow
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_fill_box = _flat(FILL)
	_ghost_fill_box = _flat(Color("#f2d0a0"))
	_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0)))
	_bar.add_theme_stylebox_override("fill", _fill_box)
	_ghost.add_theme_stylebox_override("background", _flat(Color("#0d0f14"), Color("#53657c")))
	_ghost.add_theme_stylebox_override("fill", _ghost_fill_box)


func bind_player(player: Player) -> void:
	_player = player
	player.health.health_changed.connect(_on_health_changed)
	player.potions.changed.connect(_on_potions_changed)
	_on_health_changed(player.health.current, player.health.max_health)
	_on_potions_changed(player.potions.count, player.potions.capacity)
	_ghost_value = _current


func _on_health_changed(current: float, maximum: float) -> void:
	if current < _current:
		_ghost_wait = GHOST_DELAY
	_current = current
	_maximum = maximum
	_bar.max_value = maximum
	_ghost.max_value = maximum
	_bar.value = current
	_hp_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_potions_changed(count: int, capacity: int) -> void:
	_potion_label.text = "%d / %d" % [count, capacity]
	_potion_pulse = 0.3


func _process(delta: float) -> void:
	_t += delta
	# Ghost bar trails behind damage; follows heals immediately.
	if _ghost_value > _current:
		if _ghost_wait > 0.0:
			_ghost_wait -= delta
		else:
			_ghost_value = maxf(_ghost_value - GHOST_SPEED * delta, _current)
	else:
		_ghost_value = _current
	_ghost.value = _ghost_value

	_potion_pulse = maxf(_potion_pulse - delta, 0.0)
	var pulse := 1.0 + _potion_pulse * 0.6
	_potion_row.scale = Vector2(pulse, pulse)

	if _player == null:
		return
	_update_status()


func _update_status() -> void:
	var regen := _player.regen
	var regenerating := regen.is_active()
	# Subtle health-bar tint + green border shimmer while regenerating.
	_fill_box.bg_color = FILL_REGEN.lerp(REGEN_GREEN, 0.15 + 0.1 * sin(_t * 4.0)) if regenerating else FILL
	if _player.health.is_dead:
		_set_status("", Color.WHITE)
	elif _player.combat_state.is_boss_active():
		_set_status("BOSS FIGHT · no auto-heal", Color("#ff6b6b"))
	elif _player.combat_state.in_combat:
		_set_status("IN COMBAT", Color("#ff9a7a"))
	elif regenerating:
		_set_status("+ Regenerating", REGEN_GREEN)
	elif regen.state == HealthRegen.State.PENDING:
		var left := maxf(regen.delay - regen.time_out_of_combat, 0.0)
		_set_status("Healing in %.0fs…" % ceilf(left), Color(1, 1, 1, 0.55))
	else:
		_set_status("", Color.WHITE)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _flat(color: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(2)
	return box
