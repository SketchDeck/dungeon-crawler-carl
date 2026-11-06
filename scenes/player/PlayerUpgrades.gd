class_name PlayerUpgrades
extends Node
## The player's temporary upgrades for the current floor. Applying or clearing
## them recomputes the combat multipliers, move speed and maximum health from
## their base values, so stacking and resetting are always exact.
## Kept when losing a life; cleared when the floor restarts or is completed.

signal changed(active: Array[Upgrade])

const POOL: Array[Upgrade] = [
	preload("res://resources/upgrades/KickDamage.tres"),
	preload("res://resources/upgrades/MagicDamage.tres"),
	preload("res://resources/upgrades/Knockback.tres"),
	preload("res://resources/upgrades/Cooldown.tres"),
	preload("res://resources/upgrades/MaxHealth.tres"),
	preload("res://resources/upgrades/MoveSpeed.tres"),
]
## Cooldowns never drop below this fraction, however many upgrades stack.
const MIN_COOLDOWN_MULTIPLIER := 0.4

var active: Array[Upgrade] = []
var rng := RandomNumberGenerator.new()

var _base_max_health := -1.0


func _ready() -> void:
	rng.randomize()


func player() -> Player:
	return get_parent() as Player


## Up to `count` different upgrades, chosen at random.
func roll(count := 3) -> Array[Upgrade]:
	var pool: Array[Upgrade] = POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(count, pool.size()))


func apply(upgrade: Upgrade) -> void:
	active.append(upgrade)
	_recompute()
	if upgrade.kind == Upgrade.Kind.MAX_HEALTH:
		player().health.heal(upgrade.amount)
	changed.emit(active)


func clear() -> void:
	active.clear()
	_recompute()
	changed.emit(active)


func total(kind: Upgrade.Kind) -> float:
	var sum := 0.0
	for upgrade in active:
		if upgrade.kind == kind:
			sum += upgrade.amount
	return sum


func _recompute() -> void:
	var p := player()
	var combat := p.combat
	combat.kick_damage_multiplier = 1.0 + total(Upgrade.Kind.KICK_DAMAGE)
	combat.magic_damage_multiplier = 1.0 + total(Upgrade.Kind.MAGIC_DAMAGE)
	combat.knockback_multiplier = 1.0 + total(Upgrade.Kind.KNOCKBACK)
	combat.cooldown_multiplier = maxf(MIN_COOLDOWN_MULTIPLIER, 1.0 - total(Upgrade.Kind.COOLDOWN))
	p.move_speed_multiplier = 1.0 + total(Upgrade.Kind.MOVE_SPEED)
	var health := p.health
	if _base_max_health < 0.0:
		_base_max_health = health.max_health
	health.max_health = _base_max_health + total(Upgrade.Kind.MAX_HEALTH)
	health.current = minf(health.current, health.max_health)
	health.health_changed.emit(health.current, health.max_health)
