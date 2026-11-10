class_name Achievements
extends RefCounted
## Every Dungeon AI achievement: its gallery name, how to earn it (shown once
## unlocked, "???" before), the loot box tier it pays out, and whether it can
## only be earned once per floor run (otherwise once per room encounter).
## DungeonAIManager decides when each one triggers.

enum Tier { BRONZE, SILVER, GOLD }

const TIER_NAMES := ["Bronze", "Silver", "Gold"]
const TIER_COLORS := [Color("#d08a4a"), Color("#c8d4e6"), Color("#ffd34d")]
## Viewers gained when an achievement of each tier is announced.
const TIER_VIEWERS := [50, 120, 250]

const DEFS := {
	&"enemy_collision": {"name": "Bowling Night", "tier": Tier.SILVER, "hint": "Kick an enemy into another enemy."},
	&"environment_kill": {"name": "Let the Dungeon Do the Work", "tier": Tier.SILVER, "hint": "Kill an enemy with spikes or a barrel."},
	&"untouchable": {"name": "Untouchable", "tier": Tier.SILVER, "hint": "Clear a combat room without taking damage."},
	&"juggler": {"name": "Juggler", "tier": Tier.SILVER, "hint": "Hit a launched enemy with magic before it lands."},
	&"first_blood": {"name": "First Blood", "tier": Tier.BRONZE, "hint": "Kill your first enemy on a floor.", "per_floor": true},
	&"triple_kill": {"name": "Triple Kill", "tier": Tier.SILVER, "hint": "Kill three enemies within 1.5 seconds."},
	&"chain_reaction": {"name": "Chain Reaction", "tier": Tier.SILVER, "hint": "Kill two enemies with explosions at the same moment."},
	&"shell_shocked": {"name": "Shell Shocked", "tier": Tier.BRONZE, "hint": "Crack an Armored Slime's shell."},
	&"what_shield": {"name": "What Shield?", "tier": Tier.BRONZE, "hint": "Kick a Shield Goblin from behind."},
	&"bat_swatter": {"name": "Bat Swatter", "tier": Tier.SILVER, "hint": "Kill a Cave Bat with a kick."},
	&"overkill": {"name": "Overkill", "tier": Tier.BRONZE, "hint": "Deal 35 or more damage with one hit."},
	&"close_call": {"name": "Close Call", "tier": Tier.SILVER, "hint": "Clear a combat room with less than 15% health."},
	&"dynamic_duo": {"name": "Dynamic Duo", "tier": Tier.BRONZE, "hint": "In one room, kill enemies with both kicks and magic."},
	&"hoarder": {"name": "Hoarder", "tier": Tier.BRONZE, "hint": "Carry 10 potions at once.", "per_floor": true},
	&"pit_diver": {"name": "Pit Diver", "tier": Tier.BRONZE, "hint": "Fall into pits three times on one floor.", "per_floor": true},
	&"wall_breaker": {"name": "Renovations", "tier": Tier.BRONZE, "hint": "Break a cracked wall."},
	&"spicy": {"name": "Spicy", "tier": Tier.BRONZE, "hint": "Kill an enemy with fire or an exploding corpse."},
	&"sober": {"name": "Stone Cold Sober", "tier": Tier.GOLD, "hint": "Beat a floor without drinking a potion.", "per_floor": true},
	&"deathless": {"name": "Deathless", "tier": Tier.GOLD, "hint": "Beat a floor without losing a life.", "per_floor": true},
	&"speed_boss": {"name": "Boss Rush", "tier": Tier.GOLD, "hint": "Beat a boss within 60 seconds of the fight starting."},
	&"secret_room": {"name": "Nosy Neighbour", "tier": Tier.GOLD, "hint": "Find a secret room.", "per_floor": true},
	&"shopper": {"name": "Valued Customer", "tier": Tier.BRONZE, "hint": "Buy something from a safe-room shop.", "per_floor": true},
}


static func ids() -> Array:
	return DEFS.keys()


static func has(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	return DEFS[id]["name"] if DEFS.has(id) else String(id)


static func hint(id: StringName) -> String:
	return DEFS[id]["hint"] if DEFS.has(id) else ""


static func tier(id: StringName) -> Tier:
	return DEFS[id]["tier"] if DEFS.has(id) else Tier.BRONZE


static func per_floor(id: StringName) -> bool:
	return DEFS.has(id) and DEFS[id].get("per_floor", false)


static func tier_name(t: int) -> String:
	return TIER_NAMES[t]


static func tier_color(t: int) -> Color:
	return TIER_COLORS[t]
