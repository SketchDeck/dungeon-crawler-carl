extends Control
## Ability slots with cooldown sweeps: Carl's kicks, Donut's spells, each
## mode's special (shown LOCKED until unlocked) and the dodge. The inactive
## mode's slots are dimmed but keep counting down, so you can see cooldowns
## carry over when you switch.

const SLOT := Vector2(50, 34)
const GAP := 4.0
const GROUP_GAP := 12.0

var player: Player


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var combat := player.combat
	var font := ThemeDB.fallback_font
	var x := 0.0
	var groups := [
		[PlayerCombat.Mode.CARL, [[combat.kick_combo, "Kick", "J"], [combat.charged_kick, "Power", "K"],
			[combat.explosive_kick, "Boom", "L"]]],
		[PlayerCombat.Mode.DONUT, [[combat.magic_missile, "Missile", "J"], [combat.charged_blast, "Blast", "K"],
			[combat.area_burst, "Burst", "L"]]],
	]
	for group: Array in groups:
		var m: PlayerCombat.Mode = group[0]
		var active := combat.mode == m
		var color := PlayerCombat.mode_color(m)
		for slot: Array in group[1]:
			var ability: Ability = slot[0]
			var unlocked := ability.is_unlocked()
			_draw_slot(font, Rect2(Vector2(x, 0), SLOT), slot[1], slot[2] if unlocked else "LOCKED", color,
				active and unlocked, ability.cooldown_ratio(), ability.charge_ratio() if ability.is_charging() else -1.0)
			x += SLOT.x + GAP
		x += GROUP_GAP - GAP
	_draw_slot(font, Rect2(Vector2(x, 0), SLOT), "Dodge", "Shift", Color("#9fc4ff"), true,
		player.dodge_cooldown_ratio(), -1.0)


func _draw_slot(font: Font, rect: Rect2, label: String, key: String, color: Color, active: bool,
		cooldown: float, charge: float) -> void:
	var a := 1.0 if active else 0.35
	draw_rect(rect, Color(0.05, 0.06, 0.09, 0.75 * a + 0.1))
	if cooldown > 0.0:
		# Remaining cooldown fills the slot from the bottom and drains away.
		var h := rect.size.y * cooldown
		draw_rect(Rect2(rect.position.x, rect.end.y - h, rect.size.x, h), Color(0, 0, 0, 0.55))
	if charge >= 0.0:
		draw_rect(Rect2(rect.position.x, rect.end.y - 4, rect.size.x * charge, 4), Color(color.lightened(0.3), 0.95))
	draw_rect(rect, Color(color, a * (1.0 if cooldown <= 0.0 else 0.5)), false, 2.0 if active else 1.0)
	var text_color := Color(1, 1, 1, a * (1.0 if cooldown <= 0.0 else 0.55))
	draw_string(font, rect.position + Vector2(0, 14), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, text_color)
	draw_string(font, rect.position + Vector2(0, 28), key, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11,
		Color(color.lightened(0.4), a * 0.8))
