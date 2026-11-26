class_name GearEffects
extends RefCounted
## What the worn gear and the carried weight do to the hero, listed one by one
## for the inventory's "Bonuses and penalties" box (see Menus._gear_box).
## Both lists always have the same rows, so the box never changes its size:
## a row that does nothing shows a dash.

## The rows of the equipment column, in order; the weight column has WEIGHT_ROWS.
const EQUIPMENT_ROWS := ["hp", "power", "hardening", "armour_value", "speed", "block", "dexterity"]
const WEIGHT_ROWS := ["load", "slow", "armour_skill", "strength"]


## What the worn pieces and the armour set add, per row of EQUIPMENT_ROWS:
## {"hp": int, "power": int, "hardening": int, "armour_value": int,
## "speed": float (0.1 = +10 %), "block": float (0.2 = +20 %), "dexterity": int}.
## A shield does nothing while an injury keeps the arm from holding it.
static func equipment(p: Player) -> Dictionary:
	var sum := {"hp": 0, "power": 0, "hardening": 0, "armour_value": 0, "speed": 0.0, "block": 0.0, "dexterity": 0}
	for slot in p.equipped:
		if slot == "schild" and Injury.cannot_use_shield(p):
			continue
		var item: Dictionary = Items.ALL.get(p.equipped[slot], {})
		sum.hp += int(item.get("hp", 0))
		sum.power += int(item.get("power", 0))
		sum.hardening += int(item.get("armor", 0))
		sum.armour_value += int(item.get("armour_value", 0))
		sum.speed += float(item.get("speed", 0.0))
		sum.block += float(item.get("block", 0.0))
	sum.hardening += ArmourSets.hardening(p.equipped)
	sum.dexterity = ArmourSets.dexterity(p.equipped)
	sum.armour_value = mini(sum.armour_value, Player.ARMOUR_VALUE_MAX)
	return sum


## The weight the hero carries, how it slows them and what eases it:
## {"raw": kg on the scales, "felt": kg as the hero feels it, "slow": share of
## speed lost (0.2 = -20 %), "armour_ease": share of worn armour's weight the
## armour skill takes off, "strength_ease": share of the load Stärke takes off
## (negative when the hero is weaker than a fresh one)}.
static func weight(p: Player) -> Dictionary:
	var raw := 0.0
	for slot in p.equipped:
		raw += Items.weight(p.equipped[slot])
	for id in p.bag:
		raw += Items.weight(id)
	var felt := p.load_weight()
	return {
		"raw": raw,
		"felt": felt,
		"slow": 1.0 - Items.load_factor(felt),
		"armour_ease": minf(1.0, Player.ARMOR_LIGHTER_PER_LEVEL * p.skill("ruestung")),
		"strength_ease": 1.0 - Training.ATTRIBUTES.staerke.start / float(p.attribute("staerke")),
	}


## The load at which the slowdown stops growing, in kg.
static func heaviest_kg() -> float:
	return Items.MAX_WEIGHT_SLOW / Items.WEIGHT_SLOW


static func equipment_name(row: String) -> String:
	match row:
		"hp": return Lang.t("Leben")
		"power": return Lang.t("Kampfkraft")
		"hardening": return Lang.t("Härtung")
		"armour_value": return Lang.t("Rüstungswert")
		"speed": return Lang.t("Tempo")
		"block": return Lang.t("Blockchance")
		"dexterity": return Lang.t("Geschick")
	return row


static func weight_name(row: String) -> String:
	match row:
		"load": return Lang.t("Last")
		"slow": return Lang.t("Tempo")
		"armour_skill": return Lang.t("Rüstung tragen")
		"strength": return Lang.t("Stärke")
	return row


## A signed number as the box shows it ("+3", "-2", "+15 %"); "–" for none.
static func signed(value: float, percent := false) -> String:
	var n := roundi(value * 100.0) if percent else roundi(value)
	if n == 0:
		return "–"
	return ("%+d %%" if percent else "%+d") % n


## The sign of a value for its colour: 1 good, -1 bad, 0 nothing.
static func sign_of(value: float, percent := false) -> int:
	var n := roundi(value * 100.0) if percent else roundi(value)
	return signi(n)


## The rows of the equipment column: [[name, text, sign], ...].
static func equipment_lines(p: Player) -> Array:
	var sum := equipment(p)
	var lines := []
	for row in EQUIPMENT_ROWS:
		var percent: bool = row == "speed" or row == "block"
		var text := signed(sum[row], percent)
		# The armour value is itself a share (see Player.armour_value).
		if row == "armour_value" and text != "–":
			text += " %"
		lines.append([equipment_name(row), text, sign_of(sum[row], percent)])
	return lines


## The rows of the weight column: [[name, text, sign], ...].
static func weight_lines(p: Player) -> Array:
	var w := weight(p)
	var ease_armour: bool = w.armour_ease > 0.0
	var ease_strength: bool = absf(w.strength_ease) >= 0.005
	return [
		[weight_name("load"), Items.weight_text(w.felt), 0],
		[weight_name("slow"), signed(-w.slow, true), sign_of(-w.slow, true)],
		[weight_name("armour_skill"), (Lang.t("%s Gewicht") % signed(-w.armour_ease, true)) if ease_armour else "–", 1 if ease_armour else 0],
		[weight_name("strength"), (Lang.t("%s Last") % signed(-w.strength_ease, true)) if ease_strength else "–", sign_of(w.strength_ease, true) if ease_strength else 0],
	]
