class_name HealthRegen
extends Node
## Out-of-combat automatic healing.
##
## After combat ends, wait `delay` seconds (PENDING). Then heal from the current
## health to full over `duration` seconds (ACTIVE), at a rate fixed when
## regeneration starts: rate = missing health / duration. Combat, death or
## taking damage cancels it; the healing already done is kept, and a new rate
## is calculated the next time it starts. Never consumes potions.

signal state_changed(state: State)

enum State { IDLE, PENDING, ACTIVE }

@export var delay := 3.0
@export var duration := 10.0

var state := State.IDLE
## Seconds since combat ended (or since the last interruption).
var time_out_of_combat := 0.0
var start_health := 0.0
var elapsed := 0.0
var rate := 0.0

var health: PlayerHealth
var combat_state: CombatStateManager


func _ready() -> void:
	var player := get_parent()
	health = player.get_node("Health") as PlayerHealth
	combat_state = player.get_node("CombatState") as CombatStateManager
	combat_state.combat_started.connect(cancel)
	health.damaged.connect(func(_amount: float) -> void: cancel())
	health.died.connect(cancel)


func _physics_process(delta: float) -> void:
	if health.is_dead or combat_state.in_combat:
		if state != State.IDLE or time_out_of_combat > 0.0:
			cancel()
		return

	time_out_of_combat += delta
	if health.current >= health.max_health:
		_set_state(State.IDLE)
		return

	match state:
		State.IDLE:
			_set_state(State.PENDING)
			_try_start()
		State.PENDING:
			_try_start()
		State.ACTIVE:
			elapsed += delta
			var amount := rate * delta
			if elapsed >= duration:
				amount = health.missing()
			health.heal(minf(amount, health.missing()))
			if health.current >= health.max_health:
				_set_state(State.IDLE)


func _try_start() -> void:
	if time_out_of_combat < delay:
		return
	start_health = health.current
	elapsed = 0.0
	rate = health.missing() / duration
	_set_state(State.ACTIVE)


## Stop regenerating and restart the out-of-combat delay.
func cancel() -> void:
	time_out_of_combat = 0.0
	elapsed = 0.0
	_set_state(State.IDLE)


## 0..1 progress through the out-of-combat delay (for the HUD).
func pending_ratio() -> float:
	return clampf(time_out_of_combat / delay, 0.0, 1.0)


func is_active() -> bool:
	return state == State.ACTIVE


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)
