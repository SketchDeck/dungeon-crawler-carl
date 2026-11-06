class_name Upgrade
extends Resource
## A temporary upgrade offered by treasure chests. Lasts until the floor is
## restarted or completed. Edit the .tres files next to this script to rebalance.

enum Kind { KICK_DAMAGE, MAGIC_DAMAGE, KNOCKBACK, COOLDOWN, MAX_HEALTH, MOVE_SPEED }

@export var kind := Kind.KICK_DAMAGE
@export var title := ""
## A fraction for percentage upgrades (0.25 = +25%), or HP for MAX_HEALTH.
@export var amount := 0.25


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
	return ""
