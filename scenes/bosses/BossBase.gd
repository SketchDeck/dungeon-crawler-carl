class_name BossBase
extends EnemyBase
## Shared boss rules: waits (dormant) until its room starts the fight, can't be
## knocked back or interrupted, ignores damage while immune (roars), switches
## to phase 2 at `phase2_health_ratio`, and drops guaranteed potions on death.
## Subclasses run their own attack state machine.

signal fight_started
signal phase_changed(phase: int)

@export var boss_name := "BOSS"
## One-line tip shown in the banner when the fight starts.
@export var boss_hint := ""
## Banner text when phase 2 starts, and when the boss dies.
@export var phase2_hint := "It's enraged!"
@export var defeat_text := "The boss is down. Take the stairs."
@export var guaranteed_potions := 2
@export_range(0.0, 1.0) var phase2_health_ratio := 0.5

var phase := 1

var _immune_text_at := -10000


## True until the room starts the fight.
func is_dormant() -> bool:
	return false


func start_fight() -> void:
	pass


func is_immune() -> bool:
	return false


func is_armored() -> bool:
	return true


func take_hit(hit: Hit) -> void:
	if is_dead:
		return
	if is_immune():
		if Time.get_ticks_msec() - _immune_text_at > 400:
			_immune_text_at = Time.get_ticks_msec()
			Fx.text(global_position + Vector2(0, -body_size.y * 0.5 - 20), "IMMUNE", Color(0.8, 0.8, 0.8), 14)
		return
	super.take_hit(hit)
	if not is_dead and phase == 1 and health <= max_health * phase2_health_ratio:
		phase = 2
		_enter_phase_two()
		phase_changed.emit(phase)


## Called once when health drops below the phase 2 threshold (phase is already 2).
func _enter_phase_two() -> void:
	pass


func drop_rewards() -> void:
	for i in guaranteed_potions:
		drop_potion()
