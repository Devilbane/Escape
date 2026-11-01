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
## "requires" names attributes the hero needs to use an item, e.g. the wizard's
## hat asks for some Intelligenz.
## Books ("teaches") are carried, not worn: they are read while the player is
## away (see Offline).
## A worn backpack ("bag") holds more than the plain bag's BAG_SIZE items.

const SLOTS := ["kopf", "waffe", "schild", "umhang", "ruestung", "schuhe",
		"amulett", "ring", "armreif", "spezial_1", "spezial_2", "rucksack"]
const SLOT_NAMES := {"kopf": "Kopf", "waffe": "Waffe", "schild": "Schild", "umhang": "Umhang",
		"ruestung": "Rüstung", "schuhe": "Schuhe", "amulett": "Amulett", "ring": "Ring",
		"armreif": "Armreif", "spezial_1": "Spezial 1", "spezial_2": "Spezial 2",
		"rucksack": "Rucksack"}
const BAG_SIZE := 8
const WEIGHT_SLOW := 0.01
const MAX_WEIGHT_SLOW := 0.35

## Cloaks, armour and shoes also colour the hero ("tint"; "metal" makes it shine).
## Everything the hero visibly wears names its "material" (see GearLook), which
## gives it a faint grain: cloth, leather, metal, chain, fur, bone, or "mixed"
## for weapons and shields (wood, with metal where the model is grey).
## Specials ("spezial") have an effect of their own instead of plain numbers.
const ALL := {
	"schwert": {"name": "Schwert", "slot": "waffe", "uses": "klingen", "weight": 3, "power": 1, "price": 12, "model": "res://assets/weapons/sword_1handed.gltf", "material": "mixed"},
	"axt": {"name": "Axt", "slot": "waffe", "uses": "aexte", "weight": 4, "power": 2, "price": 25, "model": "res://assets/weapons/axe_1handed.gltf", "material": "mixed"},
	"rundschild": {"name": "Rundschild", "slot": "schild", "weight": 3, "hp": 1, "block": 0.2, "durability": 5, "price": 10, "model": "res://assets/weapons/shield_round.gltf", "material": "mixed"},
	"wappenschild": {"name": "Wappenschild", "slot": "schild", "weight": 5, "hp": 2, "armor": 1, "block": 0.25, "durability": 6, "skills": {"blocken": 1}, "price": 22, "model": "res://assets/weapons/shield_badge.gltf", "material": "mixed"},
	"stachelschild": {"name": "Stachelschild", "slot": "schild", "weight": 6, "hp": 2, "power": 1, "block": 0.3, "durability": 7, "price": 35, "model": "res://assets/weapons/shield_spikes.gltf", "material": "mixed"},
	# Gorm's own fine work ("smith"): only the smith sells and forges these,
	# they are never found as loot or sold by the merchant (see Forge).
	# Models from the Medieval Weapon Pack by Omie's Assets (CC0).
	# Maces and hammers are swung like axes, so they train Äxte.
	"langschwert": {"name": "Langschwert", "slot": "waffe", "uses": "klingen", "weight": 3.5, "power": 2, "skills": {"klingen": 1}, "price": 45, "smith": true, "model": "res://assets/weapons/forge/long_sword.gltf", "material": "mixed"},
	"krummsaebel": {"name": "Krummsäbel", "slot": "waffe", "uses": "klingen", "weight": 2, "power": 2, "speed": 0.08, "price": 50, "smith": true, "model": "res://assets/weapons/forge/scimitar.gltf", "material": "mixed"},
	"streitkolben": {"name": "Streitkolben", "slot": "waffe", "uses": "aexte", "weight": 4.5, "hp": 1, "power": 2, "price": 40, "smith": true, "model": "res://assets/weapons/forge/mace.gltf", "material": "mixed"},
	"streitaxt": {"name": "Streitaxt", "slot": "waffe", "uses": "aexte", "weight": 5, "power": 3, "price": 60, "smith": true, "model": "res://assets/weapons/forge/battle_axe.gltf", "material": "mixed"},
	"kriegshammer": {"name": "Kriegshammer", "slot": "waffe", "uses": "aexte", "weight": 6, "power": 3, "skills": {"aexte": 1}, "price": 70, "smith": true, "model": "res://assets/weapons/forge/war_hammer.gltf", "material": "mixed"},
	"drachenschild": {"name": "Drachenschild", "slot": "schild", "weight": 6, "hp": 3, "armor": 1, "block": 0.3, "durability": 9, "skills": {"blocken": 1}, "price": 55, "smith": true, "model": "res://assets/weapons/forge/kite_shield.gltf", "material": "mixed"},
	"knochenhelm": {"name": "Knochenhelm", "slot": "kopf", "weight": 1, "power": 1, "price": 18, "hat": ["res://assets/enemies/Skeleton_Warrior.glb", "Skeleton_Warrior_Helmet"], "material": "bone"},
	"zauberhut": {"name": "Zauberhut", "slot": "kopf", "requires": {"intelligenz": 11}, "weight": 0.5, "hp": 1, "speed": 0.07, "magic": true, "price": 26, "hat": ["res://assets/characters/Mage.glb", "Mage_Hat"], "material": "cloth"},
	"ritterhelm": {"name": "Ritterhelm", "slot": "kopf", "weight": 3, "hp": 2, "armor": 1, "durability": 4, "price": 30, "hat": ["res://assets/characters/Knight.glb", "Knight_Helmet"], "material": "metal"},
	"baerenkappe": {"name": "Bärenkappe", "slot": "kopf", "weight": 1, "hp": 1, "power": 1, "price": 34, "hat": ["res://assets/characters/Barbarian.glb", "Barbarian_Hat"], "material": "fur"},
	"wollumhang": {"name": "Wollumhang", "slot": "umhang", "weight": 1, "hp": 1, "price": 12, "tint": Color(0.55, 0.4, 0.28), "material": "cloth"},
	"schattenumhang": {"name": "Schattenumhang", "slot": "umhang", "weight": 1, "hp": 1, "speed": 0.1, "skills": {"schleichen": 2}, "magic": true, "price": 26, "tint": Color(0.16, 0.15, 0.24), "material": "cloth"},
	"koenigsumhang": {"name": "Königsumhang", "slot": "umhang", "weight": 2, "hp": 2, "power": 1, "price": 42, "tint": Color(0.75, 0.08, 0.1), "material": "cloth"},
	"lederwams": {"name": "Lederwams", "slot": "ruestung", "weight": 2, "hp": 1, "price": 14, "tint": Color(0.5, 0.3, 0.15), "material": "leather"},
	"kettenhemd": {"name": "Kettenhemd", "slot": "ruestung", "weight": 5, "hp": 2, "armor": 1, "durability": 5, "skills": {"ruestung": 1}, "price": 28, "tint": Color(0.62, 0.64, 0.68), "metal": 0.4, "material": "chain"},
	"plattenpanzer": {"name": "Plattenpanzer", "slot": "ruestung", "weight": 8, "hp": 3, "armor": 2, "durability": 6, "power": 1, "price": 48, "tint": Color(1.0, 1.02, 1.1), "metal": 0.55, "material": "metal"},
	"lederstiefel": {"name": "Lederstiefel", "slot": "schuhe", "weight": 1, "speed": 0.05, "price": 10, "tint": Color(0.45, 0.27, 0.13), "material": "leather"},
	"eilstiefel": {"name": "Eilstiefel", "slot": "schuhe", "weight": 1, "speed": 0.15, "price": 26, "tint": Color(0.25, 0.45, 0.95), "material": "leather"},
	"amulett_tempo": {"name": "Amulett der Eile", "slot": "amulett", "weight": 0.3, "speed": 0.1, "magic": true, "price": 15},
	"amulett_kraft": {"name": "Amulett der Stärke", "slot": "amulett", "weight": 0.3, "power": 1, "magic": true, "price": 18},
	"amulett_leben": {"name": "Amulett des Lebens", "slot": "amulett", "weight": 0.3, "hp": 1, "magic": true, "price": 15},
	"kupferring": {"name": "Kupferring", "slot": "ring", "weight": 0.1, "power": 1, "price": 16},
	"rubinring": {"name": "Rubinring", "slot": "ring", "weight": 0.1, "hp": 1, "power": 1, "price": 32},
	"bronzearmreif": {"name": "Bronzearmreif", "slot": "armreif", "weight": 0.4, "hp": 1, "price": 12},
	"silberarmreif": {"name": "Silberarmreif", "slot": "armreif", "weight": 0.3, "power": 1, "speed": 0.05, "skills": {"werfen": 1}, "magic": true, "price": 27},
	# Unique: only the bandit chief carries it, once per game (see BanditChief).
	"rabenklinge": {"name": "Rabenklinge", "slot": "waffe", "uses": "klingen", "weight": 2.5, "power": 3, "speed": 0.05, "price": 95, "no_loot": true, "unique": true, "model": "res://assets/weapons/sword_1handed.gltf", "material": "mixed", "effect": "Einzigartig: die Klinge von Rabenherz, dem Räuberhauptmann"},
	"vampirzahn": {"name": "Vampirzahn", "slot": "spezial", "weight": 0.1, "price": 40, "effect": "Jeder dritte besiegte Gegner gibt dir 1 Leben"},
	"gluecksklee": {"name": "Glücksklee", "slot": "spezial", "weight": 0.1, "price": 40, "effect": "Doppeltes Gold"},
	"dornenrune": {"name": "Dornenrune", "slot": "spezial", "weight": 0.5, "price": 45, "effect": "Wer dich im Nahkampf trifft, erleidet 1 Schaden, wenn er nicht gehärtet ist"},
	"phoenixfeder": {"name": "Phönixfeder", "slot": "spezial", "weight": 0.1, "price": 60, "effect": "Rettet dich einmal vor dem Tod, dann verbrennt sie"},
	# Backpacks: "bag" is how many items the hero can carry while wearing one.
	# Bigger ones are pricier, so they turn up more rarely. Lying about, they
	# show as a sack ("model_scale" sizes it).
	"leinenrucksack": {"name": "Leinenrucksack", "slot": "rucksack", "bag": 10, "weight": 1, "price": 22, "model": "res://assets/village/sack.gltf", "model_scale": 5.0, "material": "cloth"},
	"lederrucksack": {"name": "Lederrucksack", "slot": "rucksack", "bag": 11, "weight": 1.5, "price": 36, "model": "res://assets/village/sack.gltf", "model_scale": 6.0, "material": "leather"},
	"grosser_rucksack": {"name": "Großer Rucksack", "slot": "rucksack", "bag": 12, "weight": 2, "price": 60, "model": "res://assets/village/sack.gltf", "model_scale": 7.0, "material": "leather"},
	# Books are not worn. The hero reads them while the player is away
	# (Offline, "study"): each "teaches" one skill.
	"fechtbuch": {"name": "Buch der Klingen", "slot": "buch", "weight": 1, "teaches": "klingen", "price": 40},
	"axtbuch": {"name": "Handbuch der Axt", "slot": "buch", "weight": 1, "teaches": "aexte", "price": 40},
	"wurfbuch": {"name": "Fibel des Messerwurfs", "slot": "buch", "weight": 1, "teaches": "werfen", "price": 40},
	"schildbuch": {"name": "Lehre vom Schild", "slot": "buch", "weight": 1, "teaches": "blocken", "price": 40},
	"ruestbuch": {"name": "Vom Tragen der Rüstung", "slot": "buch", "weight": 1, "teaches": "ruestung", "price": 40},
	"schleichbuch": {"name": "Die leisen Sohlen", "slot": "buch", "weight": 1, "teaches": "schleichen", "price": 45},
	# A wooden crate (see Crate): carried in the bag, set down on the floor
	# again, stacked and climbed. Never found as loot or sold in shops.
	"kiste": {"name": "Holzkiste", "slot": "kiste", "weight": 3, "price": 2, "no_loot": true, "effect": "Abstellen (Taste Q), stapeln und daraufklettern"},
	# A block of carved stone to build with (see StoneBlock): sold by the
	# stonemason in the village, set down from the bag, moved by dragging.
	"steinblock": {"name": "Steinblock", "slot": "stein", "weight": 4, "price": 3, "no_loot": true, "effect": "Zum Bauen: abstellen (Taste B), mit der Maus ziehen und stapeln"},
	# Things carried for a villager's task (see Quests): never found as loot,
	# never worn, worth next to nothing to the merchant.
	"banditendolch": {"name": "Banditendolch", "slot": "auftrag", "weight": 0.5, "price": 2, "no_loot": true, "model": "res://assets/weapons/dagger.gltf", "material": "mixed", "effect": "Für Krämerin Miras Auftrag"},
	"brief": {"name": "Brief aus der Hauptstadt", "slot": "auftrag", "weight": 0.1, "price": 1, "no_loot": true, "effect": "Für Dorfvorsteher Aldo"},
	"kuerbis": {"name": "Kürbis", "slot": "auftrag", "weight": 3, "price": 1, "no_loot": true, "effect": "Für Zecher Fritz im Wirtshaus"},
	# Thunder ore: lightning leaves it glowing beside the rocks in a storm, and
	# it fades once the storm has passed (see Weather). Never found as loot;
	# Gorm melts it down into iron bars (see Forge) and the merchant pays well.
	"donnererz": {"name": "Donnererz", "slot": "erz", "weight": 1, "price": 32, "no_loot": true, "material": "metal", "tint": Color(0.55, 0.75, 1.0), "effect": "Nur bei Gewitter zu finden. Gorm schmilzt es zu Eisenbarren"},
	"wassereimer": {"name": "Wassereimer", "slot": "auftrag", "weight": 2, "price": 1, "no_loot": true, "model": "res://assets/village/bucket_water.gltf", "model_scale": 1.6, "effect": "Für Priesterin Elsbeth am Tempel"},
	# Food for a fox (see Animal and Pet): the shopkeeper always has some.
	"wurst": {"name": "Wurst", "slot": "futter", "weight": 0.3, "price": 2, "no_loot": true, "effect": "Füchse lieben sie: Füttere einen Fuchs auf den Wiesen dreimal, und er wird dein Freund"},
	# A hand torch for the pitch-black places (see HandTorch): the shopkeeper
	# always has some. Carried in the bag, lit by itself in the dark.
	"fackel": {"name": "Fackel", "slot": "licht", "weight": 0.5, "price": 3, "no_loot": true, "effect": "Brennt in der Finsternis von selbst, drei Minuten lang. Ohne sie siehst du dort kaum die eigene Hand"},
}


## Whether an item is food for a fox (see Pet).
static func is_food(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "futter"


## Whether an item is a hand torch (see HandTorch): carried, never worn.
static func is_light(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "licht"


## Whether an item is carried for a villager's task (see Quests).
static func is_quest(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "auftrag"


static func weight(id: String) -> float:
	return float(ALL[id].get("weight", 0.0)) if ALL.has(id) else 0.0


## How much of its speed a body keeps under this load (1.0 = unburdened).
static func load_factor(total_weight: float) -> float:
	return 1.0 - minf(MAX_WEIGHT_SLOW, total_weight * WEIGHT_SLOW)


## A weight like "3 kg" or "0,5 kg".
static func weight_text(kg: float) -> String:
	var text := ("%d" % roundi(kg)) if is_equal_approx(kg, roundf(kg)) else ("%.1f" % kg)
	return (text if Lang.language == "en" else text.replace(".", ",")) + " kg"


## How many items the bag holds with this backpack worn ("" for none).
static func bag_size(backpack: String) -> int:
	return maxi(BAG_SIZE, int(ALL.get(backpack, {}).get("bag", 0)))


static func is_book(id: String) -> bool:
	return ALL.has(id) and ALL[id].has("teaches")


## Whether an item is a raw material such as ore: carried, sold or melted
## down, never worn.
static func is_material(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "erz"


## Whether an item is a crate that can be set down again (see Crate).
static func is_crate(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "kiste"


## Whether an item is a stone block to build with (see StoneBlock).
static func is_stone(id: String) -> bool:
	return ALL.has(id) and ALL[id].slot == "stein"


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
	for attr in item.get("requires", {}):
		parts.append(Lang.t("braucht %s %d") % [Lang.t(Training.ATTRIBUTES[attr].name), item.requires[attr]])
	if item.has("bag"):
		parts.append(Lang.t("Platz für %d Dinge") % item.bag)
	if item.has("teaches"):
		parts.append(Lang.t("lehrt %s (beim Lernen im Bett planen)") % Lang.t(Training.SKILLS[item.teaches].name))
	if item.has("uses"):
		parts.append(Lang.t("Fertigkeit: %s") % Lang.t(Training.SKILLS[item.uses].name))
	for skill_id in item.get("skills", {}):
		parts.append(Lang.t("+%d %s") % [item.skills[skill_id], Lang.t(Training.SKILLS[skill_id].name)])
	if item.get("weight", 0.0) > 0.0:
		parts.append(Lang.t("Gewicht %s") % weight_text(item.weight))
	if item.has("effect"):
		parts.append(Lang.t(item.effect))
	return ", ".join(parts)


## Merchants sell only plain, basic gear. Specials, unique and magic items
## ("magic": the wizard's hat, the shadow cloak, the amulets, the silver
## bracelet), the wandering merchant's own wares and the top tier of each
## kind (the dearest of its slot) come only from loot and the hero's own
## crafting. Books are not tiers of anything and stay on sale.
static func merchant_sells(id: String) -> bool:
	if not ALL.has(id):
		return false
	var item: Dictionary = ALL[id]
	if item.get("no_loot", false) or item.get("unique", false) or item.get("magic", false) or item.get("wanderer", false) or item.slot == "spezial" or item.has("effect"):
		return false
	return is_book(id) or not is_top_tier(id)


## Whether nothing of the same slot is dearer (unique items and the
## wandering merchant's wares left aside).
static func is_top_tier(id: String) -> bool:
	var slot: String = ALL[id].slot
	for other in ALL:
		var item: Dictionary = ALL[other]
		if other != id and item.slot == slot and item.price > ALL[id].price and not item.get("unique", false) and not item.get("wanderer", false):
			return false
	return true


## Something for the merchant's stock: only what merchant_sells allows (and
## not the smith's own work), cheaper things more often.
static func random_ware(rng: RandomNumberGenerator, slot := "") -> String:
	var ids := ALL.keys().filter(func(id): return merchant_sells(id) and not ALL[id].get("smith", false) and (slot == "" or ALL[id].slot == slot))
	return _weighted(rng, ids)


## Picks a random item; pricier items turn up less often.
## With a slot given, only items for that slot are picked. The smith's own
## wares are never picked: only Gorm sells them.
static func random_item(rng: RandomNumberGenerator, min_price := 0, slot := "") -> String:
	var ids := ALL.keys().filter(func(id): return ALL[id].price >= min_price and (slot == "" or ALL[id].slot == slot) and not ALL[id].get("no_loot", false) and not ALL[id].get("smith", false))
	return _weighted(rng, ids)


## One of `ids` at random, weighted by 1 / price.
static func _weighted(rng: RandomNumberGenerator, ids: Array) -> String:
	var total := 0.0
	for id in ids:
		total += 1.0 / ALL[id].price
	var roll := rng.randf() * total
	for id in ids:
		roll -= 1.0 / ALL[id].price
		if roll <= 0.0:
			return id
	return ids[-1]
