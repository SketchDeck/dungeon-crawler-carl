class_name Upgrade
extends Resource
## A temporary upgrade offered by treasure chests. Lasts until the floor is
## restarted or completed. Edit the .tres files next to this script to rebalance.
##
## Commons are stat boosts that stack. Rares and epics change how an attack
## or move behaves; you can only hold one of each.

enum Kind {
	KICK_DAMAGE, MAGIC_DAMAGE, KNOCKBACK, COOLDOWN, MAX_HEALTH, MOVE_SPEED,
	PIERCING_BOLTS, KICK_WAVE, FIRE_DODGE, POTION_BURST, SWITCH_FRENZY, LIFESTEAL,
	TAG_TEAM, VOLATILE, TWIN_BOLTS, JUGGLE_MASTER,
}
enum Rarity { COMMON, RARE, EPIC }

const RARITY_NAMES := ["COMMON", "RARE", "EPIC"]
const RARITY_COLORS := [Color("#c9d2de"), Color("#5cb8ff"), Color("#d27dff")]
## Relative chance of each rarity coming up in a chest.
const RARITY_WEIGHTS := [6.0, 3.0, 1.2]

@export var kind := Kind.KICK_DAMAGE
@export var title := ""
## A fraction for percentage upgrades (0.25 = +25%), HP for MAX_HEALTH, or the
## effect's strength for behaviour upgrades (see description()).
@export var amount := 0.25
@export var rarity := Rarity.COMMON


## Stat upgrades stack; behaviour upgrades are one of a kind.
func is_stackable() -> bool:
	return rarity == Rarity.COMMON


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func description() -> String:
	var pct := roundi(amount * 100.0)
	match kind:
		Kind.KICK_DAMAGE:
			return "Carl's kicks deal +%d%% damage." % pct
		Kind.MAGIC_DAMAGE:
			return "Donut's spells deal +%d%% damage." % pct
		Kind.KNOCKBACK:
			return "All attacks knock enemies back %d%% further." % pct
		Kind.COOLDOWN:
			return "Ability cooldowns are %d%% shorter." % pct
		Kind.MAX_HEALTH:
			return "+%d maximum health, and heals you by that much." % roundi(amount)
		Kind.MOVE_SPEED:
			return "Move %d%% faster." % pct
		Kind.PIERCING_BOLTS:
			return "Donut's bolts fly through enemies, hitting everything in a line."
		Kind.KICK_WAVE:
			return "The third kick of a combo sends a shockwave along the floor (%d damage)." % roundi(amount)
		Kind.FIRE_DODGE:
			return "Dodging leaves a trail of fire that burns enemies (%d damage per tick)." % roundi(amount)
		Kind.POTION_BURST:
			return "Drinking a potion blasts nearby enemies (%d damage) and knocks them away." % roundi(amount)
		Kind.SWITCH_FRENZY:
			return "Switching between Carl and Donut gives +%d%% damage for 1.5 seconds." % pct
		Kind.LIFESTEAL:
			return "Every enemy you kill heals you %d HP." % roundi(amount)
		Kind.TAG_TEAM:
			return "Switching modes instantly readies the new mode's attacks."
		Kind.VOLATILE:
			return "Enemies you kill explode, hurting their friends (%d damage). Chains!" % roundi(amount)
		Kind.TWIN_BOLTS:
			return "Magic missiles fire a second bolt (%d%% damage)." % pct
		Kind.JUGGLE_MASTER:
			return "Juggling deals x%d magic damage instead of x2." % roundi(amount)
	return ""
