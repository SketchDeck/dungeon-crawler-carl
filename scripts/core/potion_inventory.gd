class_name PotionInventory
extends RefCounted
## Health potion count. Pure logic; the player node decides when using is allowed.

signal changed(count: int)

var count: int = 0
var capacity: int = Config.POTION_CAPACITY


func _init(start_count: int = Config.POTION_START, cap: int = Config.POTION_CAPACITY) -> void:
	capacity = maxi(1, cap)
	count = clampi(start_count, 0, capacity)


func is_full() -> bool:
	return count >= capacity


func space_left() -> int:
	return capacity - count


## Adds potions up to capacity. Returns how many were accepted; the rest stay on the ground.
func add(amount: int = 1) -> int:
	var accepted := clampi(amount, 0, space_left())
	if accepted > 0:
		count += accepted
		changed.emit(count)
	return accepted


## Drinks one potion if the player has one, is alive, and is missing health.
## Returns HP restored. Returns 0 and consumes nothing when there is no effect.
func drink(health: HealthState) -> int:
	if count <= 0 or not health.is_alive() or health.missing() <= 0:
		return 0
	var restored := health.heal(Config.POTION_HEAL)
	count -= 1
	changed.emit(count)
	return restored


## Roll for a potion drop using a supplied RNG so tests can be deterministic.
static func roll_drop(rng: RandomNumberGenerator, chance: float = Config.POTION_DROP_CHANCE) -> bool:
	return rng.randf() < chance
