class_name Items
extends RefCounted
## Everything the hero can carry: weapons, shields, clothes, jewellery and specials.
## Each item adds to one of the hero's values while it is worn. Hard armour
## takes "armor" off every hit (a hit still costs at least 1 life) and has
## "durability": each hit may wear it down, and at 0 it breaks. Shields have
## a "block" chance: a blocked hit does no harm at all, but may wear the shield.
## Every item has a "weight" in kg; everything the hero carries, worn or in the
## bag, slows them down by WEIGHT_SLOW per kg (at most MAX_WEIGHT_SLOW).
## A weapon "uses" a skill (see Training): the hero gets better with it by
## fighting, and only while holding it. "skills" are levels an item adds.

const SLOTS := ["kopf", "waffe", "schild", "umhang", "ruestung", "schuhe",
		"amulett", "ring", "armreif", "spezial_1", "spezial_2"]
const SLOT_NAMES := {"kopf": "Kopf", "waffe": "Waffe", "schild": "Schild", "umhang": "Umhang",
		"ruestung": "Rüstung", "schuhe": "Schuhe", "amulett": "Amulett", "ring": "Ring",
		"armreif": "Armreif", "spezial_1": "Spezial 1", "spezial_2": "Spezial 2"}
const BAG_SIZE := 8
const WEIGHT_SLOW := 0.01
const MAX_WEIGHT_SLOW := 0.35

## Cloaks, armour and shoes also colour the hero ("tint"; "metal" makes it shine).
## Specials ("spezial") have an effect of their own instead of plain numbers.
const ALL := {
	"schwert": {"name": "Schwert", "slot": "waffe", "uses": "klingen", "weight": 3, "power": 1, "price": 12, "model": "res://assets/weapons/sword_1handed.gltf"},
	"axt": {"name": "Axt", "slot": "waffe", "uses": "aexte", "weight": 4, "power": 2, "price": 25, "model": "res://assets/weapons/axe_1handed.gltf"},
	"rundschild": {"name": "Rundschild", "slot": "schild", "weight": 3, "hp": 1, "block": 0.2, "durability": 5, "price": 10, "model": "res://assets/weapons/shield_round.gltf"},
	"wappenschild": {"name": "Wappenschild", "slot": "schild", "weight": 5, "hp": 2, "armor": 1, "block": 0.25, "durability": 6, "skills": {"blocken": 1}, "price": 22, "model": "res://assets/weapons/shield_badge.gltf"},
	"stachelschild": {"name": "Stachelschild", "slot": "schild", "weight": 6, "hp": 2, "power": 1, "block": 0.3, "durability": 7, "price": 35, "model": "res://assets/weapons/shield_spikes.gltf"},
	"knochenhelm": {"name": "Knochenhelm", "slot": "kopf", "weight": 1, "power": 1, "price": 18, "hat": ["res://assets/enemies/Skeleton_Warrior.glb", "Skeleton_Warrior_Helmet"]},
	"zauberhut": {"name": "Zauberhut", "slot": "kopf", "weight": 0.5, "hp": 1, "speed": 0.07, "price": 26, "hat": ["res://assets/characters/Mage.glb", "Mage_Hat"]},
	"ritterhelm": {"name": "Ritterhelm", "slot": "kopf", "weight": 3, "hp": 2, "armor": 1, "durability": 4, "price": 30, "hat": ["res://assets/characters/Knight.glb", "Knight_Helmet"]},
	"baerenkappe": {"name": "Bärenkappe", "slot": "kopf", "weight": 1, "hp": 1, "power": 1, "price": 34, "hat": ["res://assets/characters/Barbarian.glb", "Barbarian_Hat"]},
	"wollumhang": {"name": "Wollumhang", "slot": "umhang", "weight": 1, "hp": 1, "price": 12, "tint": Color(0.55, 0.4, 0.28)},
	"schattenumhang": {"name": "Schattenumhang", "slot": "umhang", "weight": 1, "hp": 1, "speed": 0.1, "skills": {"schleichen": 2}, "price": 26, "tint": Color(0.16, 0.15, 0.24)},
	"koenigsumhang": {"name": "Königsumhang", "slot": "umhang", "weight": 2, "hp": 2, "power": 1, "price": 42, "tint": Color(0.75, 0.08, 0.1)},
	"lederwams": {"name": "Lederwams", "slot": "ruestung", "weight": 2, "hp": 1, "price": 14, "tint": Color(0.5, 0.3, 0.15)},
	"kettenhemd": {"name": "Kettenhemd", "slot": "ruestung", "weight": 5, "hp": 2, "armor": 1, "durability": 5, "skills": {"ruestung": 1}, "price": 28, "tint": Color(0.62, 0.64, 0.68), "metal": 0.4},
	"plattenpanzer": {"name": "Plattenpanzer", "slot": "ruestung", "weight": 8, "hp": 3, "armor": 2, "durability": 6, "power": 1, "price": 48, "tint": Color(1.0, 1.02, 1.1), "metal": 0.55},
	"lederstiefel": {"name": "Lederstiefel", "slot": "schuhe", "weight": 1, "speed": 0.05, "price": 10, "tint": Color(0.45, 0.27, 0.13)},
	"eilstiefel": {"name": "Eilstiefel", "slot": "schuhe", "weight": 1, "speed": 0.15, "price": 26, "tint": Color(0.25, 0.45, 0.95)},
	"amulett_tempo": {"name": "Amulett der Eile", "slot": "amulett", "weight": 0.3, "speed": 0.1, "price": 15},
	"amulett_kraft": {"name": "Amulett der Stärke", "slot": "amulett", "weight": 0.3, "power": 1, "price": 18},
	"amulett_leben": {"name": "Amulett des Lebens", "slot": "amulett", "weight": 0.3, "hp": 1, "price": 15},
	"kupferring": {"name": "Kupferring", "slot": "ring", "weight": 0.1, "power": 1, "price": 16},
	"rubinring": {"name": "Rubinring", "slot": "ring", "weight": 0.1, "hp": 1, "power": 1, "price": 32},
	"bronzearmreif": {"name": "Bronzearmreif", "slot": "armreif", "weight": 0.4, "hp": 1, "price": 12},
	"silberarmreif": {"name": "Silberarmreif", "slot": "armreif", "weight": 0.3, "power": 1, "speed": 0.05, "skills": {"werfen": 1}, "price": 27},
	"vampirzahn": {"name": "Vampirzahn", "slot": "spezial", "weight": 0.1, "price": 40, "effect": "Jeder besiegte Gegner gibt dir 1 Leben"},
	"gluecksklee": {"name": "Glücksklee", "slot": "spezial", "weight": 0.1, "price": 40, "effect": "Doppeltes Gold"},
	"dornenrune": {"name": "Dornenrune", "slot": "spezial", "weight": 0.5, "price": 45, "effect": "Wer dich im Nahkampf trifft, erleidet 1 Schaden"},
	"phoenixfeder": {"name": "Phönixfeder", "slot": "spezial", "weight": 0.1, "price": 60, "effect": "Rettet dich einmal vor dem Tod, dann verbrennt sie"},
}


static func weight(id: String) -> float:
	return float(ALL[id].get("weight", 0.0)) if ALL.has(id) else 0.0


## How much of its speed a body keeps under this load (1.0 = unburdened).
static func load_factor(total_weight: float) -> float:
	return 1.0 - minf(MAX_WEIGHT_SLOW, total_weight * WEIGHT_SLOW)


## A weight like "3 kg" or "0,5 kg".
static func weight_text(kg: float) -> String:
	var text := ("%d" % roundi(kg)) if is_equal_approx(kg, roundf(kg)) else ("%.1f" % kg)
	return (text if Lang.language == "en" else text.replace(".", ",")) + " kg"


static func item_name(id: String) -> String:
	return Lang.t(ALL[id].name) if ALL.has(id) else ""


## A short line like "+1 Kampfkraft, +2 Leben".
static func describe(id: String, worn := 0) -> String:
	if not ALL.has(id):
		return ""
	var item: Dictionary = ALL[id]
	var parts := []
	if item.get("power", 0) > 0:
		parts.append(Lang.t("+%d Kampfkraft") % item.power)
	if item.get("hp", 0) > 0:
		parts.append(Lang.t("+%d Leben") % item.hp)
	if item.get("armor", 0) > 0:
		parts.append(Lang.t("+%d Härtung") % item.armor)
	if item.get("block", 0.0) > 0.0:
		parts.append(Lang.t("%d%% Blocken") % roundi(item.block * 100.0))
	if item.has("durability"):
		parts.append(Lang.t("Haltbarkeit %d / %d") % [item.durability - worn, item.durability])
	if item.get("speed", 0.0) > 0.0:
		parts.append(Lang.t("+%d%% Tempo") % roundi(item.speed * 100.0))
	elif item.get("speed", 0.0) < 0.0:
		parts.append(Lang.t("%d%% Tempo") % roundi(item.speed * 100.0))
	if item.has("uses"):
		parts.append(Lang.t("Fertigkeit: %s") % Lang.t(Training.SKILLS[item.uses].name))
	for skill_id in item.get("skills", {}):
		parts.append(Lang.t("+%d %s") % [item.skills[skill_id], Lang.t(Training.SKILLS[skill_id].name)])
	if item.get("weight", 0.0) > 0.0:
		parts.append(Lang.t("Gewicht %s") % weight_text(item.weight))
	if item.has("effect"):
		parts.append(Lang.t(item.effect))
	return ", ".join(parts)


## Picks a random item; pricier items turn up less often.
static func random_item(rng: RandomNumberGenerator, min_price := 0) -> String:
	var ids := ALL.keys().filter(func(id): return ALL[id].price >= min_price)
	var total := 0.0
	for id in ids:
		total += 1.0 / ALL[id].price
	var roll := rng.randf() * total
	for id in ids:
		roll -= 1.0 / ALL[id].price
		if roll <= 0.0:
			return id
	return ids[-1]
