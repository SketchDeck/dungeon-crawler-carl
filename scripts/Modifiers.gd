class_name Modifiers
extends RefCounted
## Floor modifiers ("sponsor events") and Hard mode. Replaying a floor you've
## already beaten adds one random sponsor event; Hard mode adds one to every
## floor on top of its own changes; the Daily Run uses two, picked by the
## day's seed. Each one makes the floor harder and multiplies viewer gains.

const HASTY := &"hasty"
const DRY := &"dry"
const GLASS := &"glass"
const EXPLOSIVE := &"explosive"
const BEEFY := &"beefy"

const DEFS := {
	HASTY: {"name": "Hasty Horde", "text": "Enemies move and attack 30% faster.", "viewers": 1.3},
	DRY: {"name": "Dry Spell", "text": "Enemies never drop potions.", "viewers": 1.3},
	GLASS: {"name": "Glass Cannon", "text": "You deal and take 50% more damage.", "viewers": 1.4},
	EXPLOSIVE: {"name": "Explosive Personality", "text": "Enemies explode when they die. Stand back!", "viewers": 1.3},
	BEEFY: {"name": "Beefy Boys", "text": "Enemies have 50% more health.", "viewers": 1.25},
}

const HASTE := 1.3
const BEEF := 1.5
const GLASS_FACTOR := 1.5
## Hard mode: tougher enemies, harder hits, more viewers.
const HARD_HEALTH := 1.5
const HARD_DAMAGE_TAKEN := 1.3
const HARD_VIEWERS := 1.5
const EXPLOSION_RADIUS := 70.0
const EXPLOSION_ENEMY_DAMAGE := 15.0
const EXPLOSION_PLAYER_DAMAGE := 12.0


static func all() -> Array:
	return DEFS.keys()


static func display_name(id: StringName) -> String:
	return DEFS[id]["name"] if DEFS.has(id) else String(id)


static func description(id: StringName) -> String:
	return DEFS[id]["text"] if DEFS.has(id) else ""


## `count` different modifiers, picked with `rng`.
static func pick(rng: RandomNumberGenerator, count: int) -> Array[StringName]:
	var pool: Array = all()
	var out: Array[StringName] = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


static func viewer_multiplier(mods: Array[StringName], hard: bool) -> float:
	var m := HARD_VIEWERS if hard else 1.0
	for id in mods:
		m *= float(DEFS[id]["viewers"]) if DEFS.has(id) else 1.0
	return m


static func damage_taken_multiplier(mods: Array[StringName], hard: bool) -> float:
	var m := HARD_DAMAGE_TAKEN if hard else 1.0
	if mods.has(GLASS):
		m *= GLASS_FACTOR
	return m


static func damage_dealt_multiplier(mods: Array[StringName]) -> float:
	return GLASS_FACTOR if mods.has(GLASS) else 1.0


## Adjusts a freshly spawned enemy (before it enters the tree).
static func apply_to_enemy(enemy: EnemyBase, mods: Array[StringName], hard: bool) -> void:
	if hard:
		enemy.max_health *= HARD_HEALTH
	if mods.has(BEEFY):
		enemy.max_health *= BEEF
	if mods.has(DRY):
		enemy.potion_drop_chance = 0.0
	if mods.has(HASTY) and not enemy is BossBase:
		enemy.apply_haste(HASTE)


static func summary(mods: Array[StringName], hard: bool) -> String:
	var names: Array[String] = []
	if hard:
		names.append("HARD MODE")
	for id in mods:
		names.append(display_name(id))
	if names.is_empty():
		return ""
	return "%s  (x%.1f viewers)" % [", ".join(names), viewer_multiplier(mods, hard)]
