class_name PlayerUpgrades
extends Node
## The player's temporary upgrades for the current floor (stat commons plus
## rare/epic behaviour upgrades, see Upgrade.gd), plus short Dungeon AI
## achievement boosts that last a few rooms. Any change recomputes the combat
## multipliers, move speed and maximum health from their base values, so
## stacking and resetting are always exact.
## Kept when losing a life; cleared when the floor restarts or is completed.

signal changed(active: Array[Upgrade])
signal boosts_changed

## Achievement boost kinds.
const BOOST_KNOCKBACK := &"knockback"
const BOOST_DAMAGE := &"damage"

const POOL: Array[Upgrade] = [
	preload("res://resources/upgrades/KickDamage.tres"),
	preload("res://resources/upgrades/MagicDamage.tres"),
	preload("res://resources/upgrades/Knockback.tres"),
	preload("res://resources/upgrades/Cooldown.tres"),
	preload("res://resources/upgrades/MaxHealth.tres"),
	preload("res://resources/upgrades/MoveSpeed.tres"),
	preload("res://resources/upgrades/PiercingBolts.tres"),
	preload("res://resources/upgrades/KickWave.tres"),
	preload("res://resources/upgrades/FireDodge.tres"),
	preload("res://resources/upgrades/PotionBurst.tres"),
	preload("res://resources/upgrades/SwitchFrenzy.tres"),
	preload("res://resources/upgrades/Lifesteal.tres"),
	preload("res://resources/upgrades/TagTeam.tres"),
	preload("res://resources/upgrades/Volatile.tres"),
	preload("res://resources/upgrades/TwinBolts.tres"),
	preload("res://resources/upgrades/JuggleMaster.tres"),
]
## How long Tag-In Fury's damage bonus lasts after a switch.
const FRENZY_TIME := 1.5

## Cooldowns never drop below this fraction, however many upgrades stack.
const MIN_COOLDOWN_MULTIPLIER := 0.4

var active: Array[Upgrade] = []
## boost kind -> {"amount": float, "rooms_left": int}. rooms_left counts the
## rooms after the current one; the boost ends on entering a room at -1.
var boosts := {}
var rng := RandomNumberGenerator.new()

var _base_max_health := -1.0
## Seconds left on Tag-In Fury's bonus.
var frenzy_left := 0.0


func _ready() -> void:
	rng.randomize()
	var p := player()
	# The player's @onready references aren't set yet (children are ready first).
	(p.get_node("Combat") as PlayerCombat).mode_changed.connect(_on_mode_changed)
	(p.get_node("Potions") as PotionInventory).used.connect(_on_potion_used)
	p.dodged.connect(_on_dodged)
	GameManager.enemy_died.connect(_on_enemy_died)


func _physics_process(delta: float) -> void:
	if frenzy_left > 0.0:
		frenzy_left = maxf(frenzy_left - delta, 0.0)
		if frenzy_left <= 0.0:
			_recompute()


func has(kind: Upgrade.Kind) -> bool:
	for upgrade in active:
		if upgrade.kind == kind:
			return true
	return false


func amount_of(kind: Upgrade.Kind) -> float:
	for upgrade in active:
		if upgrade.kind == kind:
			return upgrade.amount
	return 0.0


# --- Behaviour upgrade hooks ---------------------------------------------------

func _on_mode_changed(_mode: PlayerCombat.Mode) -> void:
	if has(Upgrade.Kind.SWITCH_FRENZY):
		frenzy_left = FRENZY_TIME
		_recompute()
		Fx.burst(player().global_position, Color("#ff5a8a"), 26.0, 0.25)
	if has(Upgrade.Kind.TAG_TEAM):
		var combat := player().combat
		for ability in [combat.basic_ability(), combat.charged_ability()]:
			(ability as Ability).cooldown_remaining = 0.0


func _on_potion_used(_healed: float) -> void:
	if not has(Upgrade.Kind.POTION_BURST):
		return
	var p := player()
	Explosion.detonate(p, p.global_position, 110.0, amount_of(Upgrade.Kind.POTION_BURST), 380.0,
		HitQuery.LAYER_ENEMIES | HitQuery.LAYER_HITTABLE, p, PackedStringArray(["explosion", "heal_burst"]), Color("#7dff8a"))


func _on_dodged(dir: int) -> void:
	if not has(Upgrade.Kind.FIRE_DODGE):
		return
	var p := player()
	var trail := FireTrail.new()
	trail.source = p
	trail.damage = amount_of(Upgrade.Kind.FIRE_DODGE)
	trail.length = p.dodge_speed * p.dodge_duration + 30.0
	trail.direction = dir
	p.get_parent().add_child(trail)
	trail.global_position = p.global_position + Vector2(-dir * 15.0, 28.0)


func _on_enemy_died(enemy: EnemyBase) -> void:
	var p := player()
	if not is_instance_valid(p) or p.health.is_dead or enemy.last_hit == null or enemy.last_hit.source != p:
		return
	if has(Upgrade.Kind.LIFESTEAL):
		var healed := p.health.heal(amount_of(Upgrade.Kind.LIFESTEAL))
		if healed > 0.0:
			Fx.text(p.global_position + Vector2(0, -52), "+%d" % roundi(healed), Color("#ff6a8a"), 14)
	if has(Upgrade.Kind.VOLATILE) and not enemy is BossBase:
		_volatile_blast.call_deferred(enemy.global_position)


func _volatile_blast(at: Vector2) -> void:
	var p := player()
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	Explosion.detonate(p, at, 80.0, amount_of(Upgrade.Kind.VOLATILE), 320.0,
		HitQuery.LAYER_ENEMIES | HitQuery.LAYER_HITTABLE, p, PackedStringArray(["explosion", "volatile"]), Color("#ff5a3c"))


func player() -> Player:
	return get_parent() as Player


## Up to `count` different upgrades, chosen at random and weighted by rarity
## (commons most often). Behaviour upgrades you already hold aren't offered.
## `min_rarity` limits the roll to that rarity or better (gold loot boxes).
func roll(count := 3, min_rarity := Upgrade.Rarity.COMMON, max_rarity := Upgrade.Rarity.EPIC) -> Array[Upgrade]:
	var pool: Array[Upgrade] = []
	for upgrade in POOL:
		if upgrade.rarity >= min_rarity and upgrade.rarity <= max_rarity and (upgrade.is_stackable() or not active.has(upgrade)):
			pool.append(upgrade)
	var picked: Array[Upgrade] = []
	while picked.size() < count and not pool.is_empty():
		var total_weight := 0.0
		for upgrade in pool:
			total_weight += Upgrade.RARITY_WEIGHTS[upgrade.rarity]
		var r := rng.randf() * total_weight
		var index := pool.size() - 1
		for i in pool.size():
			r -= Upgrade.RARITY_WEIGHTS[pool[i].rarity]
			if r <= 0.0:
				index = i
				break
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


func apply(upgrade: Upgrade) -> void:
	active.append(upgrade)
	_recompute()
	if upgrade.kind == Upgrade.Kind.MAX_HEALTH:
		player().health.heal(upgrade.amount)
	changed.emit(active)


## Clears upgrades and boosts (floor restarted or completed).
func clear() -> void:
	active.clear()
	boosts.clear()
	frenzy_left = 0.0
	_recompute()
	changed.emit(active)
	boosts_changed.emit()


## Grants (or refreshes, without stacking) an achievement boost for the
## current room and the next `rooms` rooms.
func add_boost(kind: StringName, amount: float, rooms: int) -> void:
	boosts[kind] = {"amount": amount, "rooms_left": rooms}
	_recompute()
	boosts_changed.emit()


func boost(kind: StringName) -> float:
	return boosts[kind]["amount"] if boosts.has(kind) else 0.0


func boost_rooms_left(kind: StringName) -> int:
	return boosts[kind]["rooms_left"] if boosts.has(kind) else -1


## Called when the player moves on to a new room.
func on_new_room() -> void:
	if boosts.is_empty():
		return
	for kind: StringName in boosts.keys():
		boosts[kind]["rooms_left"] -= 1
		if boosts[kind]["rooms_left"] < 0:
			boosts.erase(kind)
	_recompute()
	boosts_changed.emit()


## Recomputes every multiplier (e.g. after floor modifiers change).
func refresh() -> void:
	_recompute()


func total(kind: Upgrade.Kind) -> float:
	var sum := 0.0
	for upgrade in active:
		if upgrade.kind == kind:
			sum += upgrade.amount
	return sum


func _recompute() -> void:
	var p := player()
	var combat := p.combat
	var frenzy := amount_of(Upgrade.Kind.SWITCH_FRENZY) if frenzy_left > 0.0 else 0.0
	var mod := combat.modifier_damage_multiplier
	combat.kick_damage_multiplier = (1.0 + total(Upgrade.Kind.KICK_DAMAGE) + boost(BOOST_DAMAGE) + frenzy) * mod
	combat.magic_damage_multiplier = (1.0 + total(Upgrade.Kind.MAGIC_DAMAGE) + boost(BOOST_DAMAGE) + frenzy) * mod
	combat.pierce_bolts = has(Upgrade.Kind.PIERCING_BOLTS)
	combat.twin_bolt_factor = amount_of(Upgrade.Kind.TWIN_BOLTS)
	combat.kick_wave_damage = amount_of(Upgrade.Kind.KICK_WAVE)
	combat.juggle_multiplier = maxf(EnemyBase.JUGGLE_MULTIPLIER, amount_of(Upgrade.Kind.JUGGLE_MASTER))
	combat.knockback_multiplier = 1.0 + total(Upgrade.Kind.KNOCKBACK) + boost(BOOST_KNOCKBACK)
	combat.cooldown_multiplier = maxf(MIN_COOLDOWN_MULTIPLIER, 1.0 - total(Upgrade.Kind.COOLDOWN))
	p.move_speed_multiplier = 1.0 + total(Upgrade.Kind.MOVE_SPEED)
	var health := p.health
	if _base_max_health < 0.0:
		_base_max_health = health.max_health
	health.max_health = _base_max_health + total(Upgrade.Kind.MAX_HEALTH)
	health.current = minf(health.current, health.max_health)
	health.health_changed.emit(health.current, health.max_health)
