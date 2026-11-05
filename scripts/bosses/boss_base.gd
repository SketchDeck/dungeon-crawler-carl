class_name BossBase
extends EnemyBase
## Base for floor bosses. Bosses shrug off most knockback, switch to phase 2 at 50% health,
## and drop potions that stay on the ground until the encounter is over.

signal phase_changed(phase: int)

var phase: int = 1


func is_boss() -> bool:
	return true


func receive_hit(hit: HitInfo) -> bool:
	hit.knockback *= 0.3
	return super.receive_hit(hit)


func _on_hurt(_hit: HitInfo) -> void:
	if phase == 1 and hp_state.hp * 2 <= max_hp:
		phase = 2
		_enter_phase_two()
		phase_changed.emit(2)


func _enter_phase_two() -> void:
	Sfx.play("roar")
	Fx.shake(16.0)
	Fx.hitstop(0.12, 0.05)
	Fx.ring(global_position, Color("#ff5f6d"), 130.0, 0.6, 8.0)
	Fx.burst(global_position + Vector2(0.0, -20.0), Color("#ff7a5a"), 40, 420.0, 0.7)
	Fx.text(global_position + Vector2(0.0, -96.0), "ENRAGED!", Color("#ff5f6d"), 26)
	_on_phase_two()


## Override for phase-two changes such as faster attacks.
func _on_phase_two() -> void:
	pass


## Bosses drop two potions that the room makes collectible only once the fight is over.
func _drop_loot() -> void:
	for i in range(2):
		var pickup := PotionPickup.spawn(get_parent(), global_position + Vector2(-18.0 + 36.0 * i, -24.0))
		pickup.collectible = false
		pickup.add_to_group("boss_drops")
