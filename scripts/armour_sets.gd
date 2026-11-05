class_name ArmourSets
extends RefCounted
## Armour sets: a helmet, an armour, gloves and shoes all of one kind ("set"
## in Items.ALL) make a set, and a worn set raises Geschick and Härtung by a
## fixed amount. Cloaks, shields and jewellery are free and do not break a
## set. The bonus grows with the quality of the stuff: light cloth and
## leather give more Geschick, iron and steel more Härtung, and the scales of
## the great beasts give both. Each part is 1 to 4 and the two together at
## most 7; only the dragon scale set reaches 7.
##
## The hydra and wyrm scale pieces are trophies found deep down (see Items,
## "trophy"); the dragon scale pieces are made from the scales Embermaw
## leaves (see Crafting and DragonLair).

## The worn slots that make up a set.
const PIECES := ["kopf", "ruestung", "handschuhe", "schuhe"]

## Every set: its name, and what it adds to Geschick ("dex") and Härtung
## ("hardening"), from plain to finest.
const SETS := {
	"stoff": {"name": "Stoffset", "dex": 2, "hardening": 1},
	"leder": {"name": "Lederset", "dex": 3, "hardening": 1},
	"eisen": {"name": "Eisenset", "dex": 1, "hardening": 3},
	"stahl": {"name": "Stahlset", "dex": 1, "hardening": 4},
	"hydra": {"name": "Hydraschuppenset", "dex": 3, "hardening": 3},
	"wyrm": {"name": "Lindwurmschuppenset", "dex": 2, "hardening": 4},
	"drache": {"name": "Drachenschuppenset", "dex": 3, "hardening": 4},
}


## The set the hero wears completely, or "" for none.
static func worn(equipped: Dictionary) -> String:
	var kind := ""
	for slot in PIECES:
		var id: String = equipped.get(slot, "")
		var piece: String = Items.ALL.get(id, {}).get("set", "")
		if piece == "" or (kind != "" and piece != kind):
			return ""
		kind = piece
	return kind


## What the set worn now adds to Geschick.
static func dexterity(equipped: Dictionary) -> int:
	return int(SETS.get(worn(equipped), {}).get("dex", 0))


## What the set worn now adds to Härtung.
static func hardening(equipped: Dictionary) -> int:
	return int(SETS.get(worn(equipped), {}).get("hardening", 0))


## A set's name in the player's language ("" for none). Not "set_name":
## called from another script, that would be the script resource's own
## Resource.set_name and give nothing back.
static func title(kind: String) -> String:
	return Lang.t(SETS[kind].name) if SETS.has(kind) else ""


## What a set gives, like "+3 Geschick, +1 Härtung".
static func bonus_text(kind: String) -> String:
	if not SETS.has(kind):
		return ""
	return Lang.t("+%d Geschick, +%d Härtung") % [SETS[kind].dex, SETS[kind].hardening]


## How many of a set's pieces are worn now.
static func pieces_worn(equipped: Dictionary, kind: String) -> int:
	var n := 0
	for slot in PIECES:
		if Items.ALL.get(equipped.get(slot, ""), {}).get("set", "") == kind:
			n += 1
	return n


## The line for the character page: the set worn and its bonus.
static func summary(equipped: Dictionary) -> String:
	var kind := worn(equipped)
	if kind != "":
		return Lang.t("%s: %s") % [title(kind), bonus_text(kind)]
	return Lang.t("Kein Rüstungsset")


## The set the hero has most pieces of (at least two), or "" for none: the
## one they are closest to.
static func closest(equipped: Dictionary) -> String:
	var best := ""
	var most := 1
	for kind in SETS:
		var n := pieces_worn(equipped, kind)
		if n > most:
			best = kind
			most = n
	return best


## The news when putting something on or off makes or breaks a set ("" when
## nothing changed).
static func change_news(before: String, after: String) -> String:
	if before == after:
		return ""
	if after != "":
		return Lang.t("%s vollständig: %s") % [title(after), bonus_text(after)]
	return Lang.t("%s abgelegt: der Setbonus ist weg") % title(before)
