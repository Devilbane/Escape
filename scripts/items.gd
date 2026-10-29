class_name Items
extends RefCounted
## Everything the hero can carry: weapons, shields and amulets.
## Each item adds to one of the hero's values while it is worn.

const SLOTS := ["waffe", "schild", "amulett"]
const SLOT_NAMES := {"waffe": "Waffe", "schild": "Schild", "amulett": "Amulett"}
const BAG_SIZE := 8

const ALL := {
	"schwert": {"name": "Schwert", "slot": "waffe", "power": 1, "price": 12, "model": "res://assets/weapons/sword_1handed.gltf"},
	"axt": {"name": "Axt", "slot": "waffe", "power": 2, "price": 25, "model": "res://assets/weapons/axe_1handed.gltf"},
	"rundschild": {"name": "Rundschild", "slot": "schild", "hp": 1, "price": 10, "model": "res://assets/weapons/shield_round.gltf"},
	"wappenschild": {"name": "Wappenschild", "slot": "schild", "hp": 2, "price": 22, "model": "res://assets/weapons/shield_badge.gltf"},
	"stachelschild": {"name": "Stachelschild", "slot": "schild", "hp": 2, "power": 1, "price": 35, "model": "res://assets/weapons/shield_spikes.gltf"},
	"amulett_tempo": {"name": "Amulett der Eile", "slot": "amulett", "speed": 0.1, "price": 15},
	"amulett_kraft": {"name": "Amulett der Stärke", "slot": "amulett", "power": 1, "price": 18},
	"amulett_leben": {"name": "Amulett des Lebens", "slot": "amulett", "hp": 1, "price": 15},
}


static func item_name(id: String) -> String:
	return ALL[id].name if ALL.has(id) else ""


## A short line like "+1 Kampfkraft, +2 Leben".
static func describe(id: String) -> String:
	if not ALL.has(id):
		return ""
	var item: Dictionary = ALL[id]
	var parts := []
	if item.get("power", 0) > 0:
		parts.append("+%d Kampfkraft" % item.power)
	if item.get("hp", 0) > 0:
		parts.append("+%d Leben" % item.hp)
	if item.get("speed", 0.0) > 0.0:
		parts.append("+%d%% Tempo" % roundi(item.speed * 100.0))
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
