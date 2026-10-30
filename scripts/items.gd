class_name Items
extends RefCounted
## Everything the hero can carry: weapons, shields, clothes, jewellery and specials.
## Each item adds to one of the hero's values while it is worn.

const SLOTS := ["kopf", "waffe", "schild", "umhang", "ruestung", "schuhe",
		"amulett", "ring", "armreif", "spezial_1", "spezial_2"]
const SLOT_NAMES := {"kopf": "Kopf", "waffe": "Waffe", "schild": "Schild", "umhang": "Umhang",
		"ruestung": "Rüstung", "schuhe": "Schuhe", "amulett": "Amulett", "ring": "Ring",
		"armreif": "Armreif", "spezial_1": "Spezial 1", "spezial_2": "Spezial 2"}
const BAG_SIZE := 8

## Cloaks, armour and shoes also colour the hero ("tint"; "metal" makes it shine).
## Specials ("spezial") have an effect of their own instead of plain numbers.
const ALL := {
	"schwert": {"name": "Schwert", "slot": "waffe", "power": 1, "price": 12, "model": "res://assets/weapons/sword_1handed.gltf"},
	"axt": {"name": "Axt", "slot": "waffe", "power": 2, "price": 25, "model": "res://assets/weapons/axe_1handed.gltf"},
	"rundschild": {"name": "Rundschild", "slot": "schild", "hp": 1, "price": 10, "model": "res://assets/weapons/shield_round.gltf"},
	"wappenschild": {"name": "Wappenschild", "slot": "schild", "hp": 2, "price": 22, "model": "res://assets/weapons/shield_badge.gltf"},
	"stachelschild": {"name": "Stachelschild", "slot": "schild", "hp": 2, "power": 1, "price": 35, "model": "res://assets/weapons/shield_spikes.gltf"},
	"knochenhelm": {"name": "Knochenhelm", "slot": "kopf", "power": 1, "price": 18, "hat": ["res://assets/enemies/Skeleton_Warrior.glb", "Skeleton_Warrior_Helmet"]},
	"zauberhut": {"name": "Zauberhut", "slot": "kopf", "hp": 1, "speed": 0.07, "price": 26, "hat": ["res://assets/characters/Mage.glb", "Mage_Hat"]},
	"ritterhelm": {"name": "Ritterhelm", "slot": "kopf", "hp": 2, "price": 30, "hat": ["res://assets/characters/Knight.glb", "Knight_Helmet"]},
	"baerenkappe": {"name": "Bärenkappe", "slot": "kopf", "hp": 1, "power": 1, "price": 34, "hat": ["res://assets/characters/Barbarian.glb", "Barbarian_Hat"]},
	"wollumhang": {"name": "Wollumhang", "slot": "umhang", "hp": 1, "price": 12, "tint": Color(0.55, 0.4, 0.28)},
	"schattenumhang": {"name": "Schattenumhang", "slot": "umhang", "hp": 1, "speed": 0.1, "price": 26, "tint": Color(0.16, 0.15, 0.24)},
	"koenigsumhang": {"name": "Königsumhang", "slot": "umhang", "hp": 2, "power": 1, "price": 42, "tint": Color(0.75, 0.08, 0.1)},
	"lederwams": {"name": "Lederwams", "slot": "ruestung", "hp": 1, "price": 14, "tint": Color(0.5, 0.3, 0.15)},
	"kettenhemd": {"name": "Kettenhemd", "slot": "ruestung", "hp": 2, "speed": -0.04, "price": 28, "tint": Color(0.62, 0.64, 0.68), "metal": 0.4},
	"plattenpanzer": {"name": "Plattenpanzer", "slot": "ruestung", "hp": 3, "power": 1, "speed": -0.07, "price": 48, "tint": Color(1.0, 1.02, 1.1), "metal": 0.55},
	"lederstiefel": {"name": "Lederstiefel", "slot": "schuhe", "speed": 0.05, "price": 10, "tint": Color(0.45, 0.27, 0.13)},
	"eilstiefel": {"name": "Eilstiefel", "slot": "schuhe", "speed": 0.15, "price": 26, "tint": Color(0.25, 0.45, 0.95)},
	"amulett_tempo": {"name": "Amulett der Eile", "slot": "amulett", "speed": 0.1, "price": 15},
	"amulett_kraft": {"name": "Amulett der Stärke", "slot": "amulett", "power": 1, "price": 18},
	"amulett_leben": {"name": "Amulett des Lebens", "slot": "amulett", "hp": 1, "price": 15},
	"kupferring": {"name": "Kupferring", "slot": "ring", "power": 1, "price": 16},
	"rubinring": {"name": "Rubinring", "slot": "ring", "hp": 1, "power": 1, "price": 32},
	"bronzearmreif": {"name": "Bronzearmreif", "slot": "armreif", "hp": 1, "price": 12},
	"silberarmreif": {"name": "Silberarmreif", "slot": "armreif", "power": 1, "speed": 0.05, "price": 27},
	"vampirzahn": {"name": "Vampirzahn", "slot": "spezial", "price": 40, "effect": "Jeder besiegte Gegner gibt dir 1 Leben"},
	"gluecksklee": {"name": "Glücksklee", "slot": "spezial", "price": 40, "effect": "Doppeltes Gold"},
	"dornenrune": {"name": "Dornenrune", "slot": "spezial", "price": 45, "effect": "Wer dich im Nahkampf trifft, erleidet 1 Schaden"},
	"phoenixfeder": {"name": "Phönixfeder", "slot": "spezial", "price": 60, "effect": "Rettet dich einmal vor dem Tod, dann verbrennt sie"},
}


static func item_name(id: String) -> String:
	return Lang.t(ALL[id].name) if ALL.has(id) else ""


## A short line like "+1 Kampfkraft, +2 Leben".
static func describe(id: String) -> String:
	if not ALL.has(id):
		return ""
	var item: Dictionary = ALL[id]
	var parts := []
	if item.get("power", 0) > 0:
		parts.append(Lang.t("+%d Kampfkraft") % item.power)
	if item.get("hp", 0) > 0:
		parts.append(Lang.t("+%d Leben") % item.hp)
	if item.get("speed", 0.0) > 0.0:
		parts.append(Lang.t("+%d%% Tempo") % roundi(item.speed * 100.0))
	elif item.get("speed", 0.0) < 0.0:
		# Heavy armour slows you down.
		parts.append(Lang.t("%d%% Tempo") % roundi(item.speed * 100.0))
	if item.has("effect"):
		parts.append(Lang.t(item.effect))
	return ", ".join(parts)


## Picks a random item; pricier items turn up less often.
static func random_item(rng: RandomNumberGenerator) -> String:
	var ids := ALL.keys()
	var total := 0.0
	for id in ids:
		total += 1.0 / ALL[id].price
	var roll := rng.randf() * total
	for id in ids:
		roll -= 1.0 / ALL[id].price
		if roll <= 0.0:
			return id
	return ids[-1]
