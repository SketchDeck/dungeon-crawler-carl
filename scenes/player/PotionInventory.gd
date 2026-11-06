class_name PotionInventory
extends Node
## Health potions: carried count, pickup capacity and manual use.

signal changed(count: int, capacity: int)
signal used(amount_healed: float)

@export var capacity := 10
@export var starting_count := 3
@export var heal_amount := 30.0
@export var use_cooldown := 0.5

var count := 3
## Seconds since a potion was last used (drives the drink flash).
var time_since_use := 999.0

var _cooldown := 0.0
var _player: Player


func _ready() -> void:
	_player = get_parent() as Player
	count = starting_count


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	time_since_use += delta
	if _player.read_input and Input.is_action_just_pressed("use_potion"):
		if not use():
			_explain_failure()


func is_full() -> bool:
	return count >= capacity


## Adds one potion if there is room. Returns false when full.
func add() -> bool:
	if is_full():
		return false
	count += 1
	changed.emit(count, capacity)
	return true


func can_use() -> bool:
	var health := _player.health
	return _cooldown <= 0.0 and count > 0 and not health.is_dead and health.current < health.max_health


## Drinks a potion. Does nothing (and keeps the potion) at full health.
func use() -> bool:
	if not can_use():
		return false
	count -= 1
	_cooldown = use_cooldown
	time_since_use = 0.0
	var healed := _player.health.heal(heal_amount)
	changed.emit(count, capacity)
	used.emit(healed)
	Fx.burst(_player.global_position, Color("#7dff8a"), 30.0, 0.35)
	Fx.text(_player.global_position + Vector2(0, -52), "+%d" % roundi(healed), Color("#7dff8a"), 18)
	return true


func reset(to_count := -1) -> void:
	count = clampi(starting_count if to_count < 0 else to_count, 0, capacity)
	_cooldown = 0.0
	changed.emit(count, capacity)


func _explain_failure() -> void:
	if _cooldown > 0.0 or _player.health.is_dead:
		return
	var msg := "No potions" if count <= 0 else "Already at full health"
	Fx.text(_player.global_position + Vector2(0, -52), msg, Color(1, 1, 1, 0.8), 13)
