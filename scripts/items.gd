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
## A hat with "brim" has its brim narrowed to that share of its width when the
## hero wears it (GearLook.narrow_brim), so the face stays visible.
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
## Items that bundle in one bag slot, and how many fit in one bundle. The bag
## stays a plain list of ids (one entry per item), so saving, dropping and
## lighting a torch take one from a bundle; only the count of slots and the
## inventory's grid see bundles (see slots_used and stacks).
const STACK := {"fackel": 5, "donnererz": 5}
## Small things bundle by their slot too: jewellery (rings, amulets, bracelets)
## and animal food. Only identical items share a slot: an item is one id with
## fixed values, so two Kupferringe are alike, a Kupferring and a Rubinring
## are not.
const STACK_SLOTS := {"ring": 5, "amulett": 5, "armreif": 5, "futter": 5}
const WEIGHT_SLOW := 0.01
const MAX_WEIGHT_SLOW := 0.35

## Cloaks, armour and shoes also colour the hero ("tint"; "metal" makes it shine).
## Everything the hero visibly wears names its "material" (see GearLook), which
## gives it a faint grain: cloth, leather, metal, chain, fur, bone, or "mixed"
## for weapons and shields (wood, with metal where the model is grey).
## Specials ("spezial") have an effect of their own instead of plain numbers.
## Not a constant: gear made in the map workshop joins it ("custom", see
## Creations), and is never sold or found as loot.
static var ALL := {
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
	# Thunder weapons: Gorm forges them from iron, gold and the thunder ore a
	# storm leaves ("thunder": lumps of ore it takes, see Forge). A blow that
	# lands may "shock" the enemy: a lightning crack stuns it for a moment
	# (see Enemy.shock). Never found as loot or sold; "crafted" keeps them
	# from counting as the top of their kind for the shops.
	"donnerklinge": {"name": "Donnerklinge", "slot": "waffe", "uses": "klingen", "weight": 3, "power": 2, "skills": {"klingen": 1}, "shock": 0.2, "thunder": 2, "price": 65, "no_loot": true, "crafted": true, "model": "res://assets/weapons/forge/long_sword.gltf", "material": "mixed"},
	"donnerhammer": {"name": "Donnerhammer", "slot": "waffe", "uses": "aexte", "weight": 6, "power": 3, "skills": {"aexte": 1}, "shock": 0.25, "thunder": 3, "price": 80, "no_loot": true, "crafted": true, "model": "res://assets/weapons/forge/war_hammer.gltf", "material": "mixed"},
	"knochenhelm": {"name": "Knochenhelm", "slot": "kopf", "weight": 1, "power": 1, "price": 18, "hat": ["res://assets/enemies/Skeleton_Warrior.glb", "Skeleton_Warrior_Helmet"], "material": "bone"},
	"zauberhut": {"name": "Zauberhut", "slot": "kopf", "requires": {"intelligenz": 11}, "weight": 0.5, "hp": 1, "speed": 0.07, "magic": true, "price": 26, "hat": ["res://assets/characters/Mage.glb", "Mage_Hat"], "brim": 0.4, "material": "cloth"},
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
	# Made at the fine metalwork bench from the wish recipes (see Crafting).
	"klingenring": {"name": "Klingenring", "slot": "ring", "weight": 0.1, "power": 1, "skills": {"klingen": 1}, "magic": true, "price": 34, "no_loot": true, "crafted": true},
	"axtreif": {"name": "Armreif der Axt", "slot": "armreif", "weight": 0.5, "power": 1, "skills": {"aexte": 1}, "magic": true, "price": 34, "no_loot": true, "crafted": true},
	"schildamulett": {"name": "Amulett des Walls", "slot": "amulett", "weight": 0.3, "hp": 1, "skills": {"blocken": 1}, "magic": true, "price": 34, "no_loot": true, "crafted": true},
	"wurfring": {"name": "Wurfring", "slot": "ring", "weight": 0.1, "speed": 0.05, "skills": {"werfen": 1}, "magic": true, "price": 34, "no_loot": true, "crafted": true},
	"schattenamulett": {"name": "Amulett der stillen Schritte", "slot": "amulett", "weight": 0.3, "speed": 0.05, "skills": {"schleichen": 1}, "magic": true, "price": 34, "no_loot": true, "crafted": true},
	"lastreif": {"name": "Armreif der leichten Last", "slot": "armreif", "weight": 0.3, "hp": 1, "skills": {"ruestung": 1}, "magic": true, "price": 34, "no_loot": true, "crafted": true},
	# Cut from grotto crystals at the gem cutter's wheel (see Crafting, Mines).
	"kristallring": {"name": "Kristallring", "slot": "ring", "weight": 0.1, "hp": 2, "power": 1, "magic": true, "price": 48, "no_loot": true, "crafted": true},
	"kristallamulett": {"name": "Kristallamulett", "slot": "amulett", "weight": 0.3, "hp": 3, "power": 1, "magic": true, "price": 60, "no_loot": true, "crafted": true},
	"silberarmreif": {"name": "Silberarmreif", "slot": "armreif", "weight": 0.3, "power": 1, "speed": 0.05, "skills": {"werfen": 1}, "magic": true, "price": 27},
	# Unique: only the bandit chief carries it, once per game (see BanditChief).
	"rabenklinge": {"name": "Rabenklinge", "slot": "waffe", "uses": "klingen", "weight": 2.5, "power": 3, "speed": 0.05, "price": 95, "no_loot": true, "unique": true, "model": "res://assets/weapons/sword_1handed.gltf", "material": "mixed", "effect": "Einzigartig: die Klinge von Rabenherz, dem Räuberhauptmann"},
	# Unique: the Mountain King's hammer, deep in the third mine (see Mines).
	"runenhammer": {"name": "Runenhammer des Bergkönigs", "slot": "waffe", "uses": "aexte", "weight": 6, "hp": 2, "power": 4, "skills": {"aexte": 1}, "price": 160, "no_loot": true, "unique": true, "model": "res://assets/weapons/forge/war_hammer.gltf", "material": "mixed", "effect": "Einzigartig: der Hammer des Bergkönigs aus dem Herzen des Berges"},
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
	# The biggest: 20 places, found only deep down (the merchant never sells
	# the top of a kind, see merchant_sells).
	"reiserucksack": {"name": "Reiserucksack", "slot": "rucksack", "bag": 20, "weight": 2.5, "price": 95, "model": "res://assets/village/sack.gltf", "model_scale": 8.0, "material": "leather"},
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
	"wetzstein": {"name": "Wetzstein", "slot": "auftrag", "weight": 1, "price": 1, "no_loot": true, "effect": "Für Schmied Gorm an seiner Esse"},
	# Thunder ore: lightning leaves it glowing beside the rocks in a storm, and
	# it fades once the storm has passed (see Weather). Never found as loot.
	# Gorm forges it into the thunder weapons (see Forge, "thunder"), or melts
	# it down into iron bars, and the merchant pays well for it.
	"donnererz": {"name": "Donnererz", "slot": "erz", "weight": 1, "price": 32, "no_loot": true, "material": "metal", "tint": Color(0.55, 0.75, 1.0), "effect": "Nur bei Gewitter zu finden. Gorm schmiedet daraus Donnerwaffen"},
	"wassereimer": {"name": "Wassereimer", "slot": "auftrag", "weight": 2, "price": 1, "no_loot": true, "model": "res://assets/village/bucket_water.gltf", "model_scale": 1.6, "effect": "Für Priesterin Elsbeth am Tempel"},
	# Food for a fox (see Animal and Pet): the shopkeeper always has some.
	"wurst": {"name": "Wurst", "slot": "futter", "weight": 0.3, "price": 2, "no_loot": true, "effect": "Füchse lieben sie. Sie leben auf der Wiese am Waldteich westlich vom Dorf: Füttere einen Fuchs dreimal, und er wird dein Freund"},
	# Food for a doe and a stag (see Companions): the shopkeeper always has some too.
	"apfel": {"name": "Apfel", "slot": "futter", "icon": "apple", "weight": 0.2, "price": 2, "no_loot": true, "effect": "Rehe lieben ihn. Sie äsen auf den Lichtungen zwischen Friedhof und Dorf: Füttere ein Reh dreimal, und es wird dein Freund"},
	"salzleckstein": {"name": "Salzleckstein", "slot": "futter", "icon": "salt", "weight": 0.5, "price": 3, "no_loot": true, "effect": "Hirsche lieben ihn. Sie äsen auf den Lichtungen zwischen Friedhof und Dorf: Lass einen Hirsch dreimal lecken, und er wird dein Freund"},
	# A hand torch for the pitch-black places (see HandTorch): the shopkeeper
	# always has some. Carried in the bag, lit by itself in the dark.
	"fackel": {"name": "Fackel", "slot": "licht", "weight": 0.5, "price": 3, "no_loot": true, "effect": "Zünde sie an, wenn du Licht brauchst (Taste V oder die Fackel am rechten Rand), dann brennt sie drei Minuten lang. In der Finsternis siehst du ohne sie kaum die eigene Hand"},
}


## Whether an item is food for a companion (see Companions).
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


## How many of an item share one bag slot (1 for most).
static func stack_size(id: String) -> int:
	if STACK.has(id):
		return int(STACK[id])
	return int(STACK_SLOTS.get(ALL.get(id, {}).get("slot", ""), 1))


## The bag's slots, in the order the items lie in it: each a dictionary
## {"id", "count", "indices"}, where "indices" are the list positions of the
## items in that slot. A bundling item fills its first slot before the next
## one is opened, so 7 torches are one slot of 5 and one of 2.
static func stacks(items: Array) -> Array:
	var out := []
	var open := {}
	for i in items.size():
		var id: String = items[i]
		var most := stack_size(id)
		if most > 1 and open.has(id) and open[id].count < most:
			open[id].count += 1
			open[id].indices.append(i)
			continue
		var slot := {"id": id, "count": 1, "indices": [i]}
		out.append(slot)
		if most > 1:
			open[id] = slot
	return out


## How many bag slots these items take: bundled items share one.
static func slots_used(items: Array) -> int:
	var used := 0
	var counted := {}
	for id in items:
		var most := stack_size(id)
		if most <= 1:
			used += 1
		elif not counted.has(id):
			counted[id] = true
			used += ceili(items.count(id) / float(most))
	return used


## Whether one more of `id` fits in a bag of `size` slots holding `items`:
## always when a bundle of it has room, else when a slot is free.
static func fits(items: Array, size: int, id: String) -> bool:
	var most := stack_size(id)
	if most > 1 and items.count(id) % most != 0:
		return true
	return slots_used(items) < size


## How many items the bag holds with this backpack worn ("" for none).
static func bag_size(backpack: String) -> int:
	return maxi(BAG_SIZE, int(ALL.get(backpack, {}).get("bag", 0)))


## Whether an item is plain, common stuff (cheaper than an uncommon secret
## room's cheapest gear, see Level.TIERS). Only common things may turn up in
## more than one container of a level; anything finer, books included, is
## found there once at most (see Level.loot_item).
static func is_common(id: String) -> bool:
	return ALL.has(id) and ALL[id].price < int(Level.TIERS["ungewoehnlich"].min_price)


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
	if stack_size(id) > 1:
		parts.append(Lang.t("stapelbar: %d gleiche in einem Platz") % stack_size(id))
	if item.has("teaches"):
		parts.append(Lang.t("lehrt %s (beim Lernen im Bett planen)") % Lang.t(Training.SKILLS[item.teaches].name))
	if item.has("uses"):
		parts.append(Lang.t("Fertigkeit: %s") % Lang.t(Training.SKILLS[item.uses].name))
	if item.get("shock", 0.0) > 0.0:
		parts.append(Lang.t("%d%% Blitzschlag: betäubt den Gegner kurz") % roundi(item.shock * 100.0))
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


## Whether nothing of the same slot is dearer (unique items, the wandering
## merchant's wares and pieces made from recipes left aside).
static func is_top_tier(id: String) -> bool:
	var slot: String = ALL[id].slot
	for other in ALL:
		var item: Dictionary = ALL[other]
		if other != id and item.slot == slot and item.price > ALL[id].price and not item.get("unique", false) and not item.get("wanderer", false) and not item.get("crafted", false) and not item.get("custom", false):
			return false
	return true


## Something for the merchant's stock: only what merchant_sells allows (and
## not the smith's own work), cheaper things more often.
static func random_ware(rng: RandomNumberGenerator, slot := "") -> String:
	var ids := ALL.keys().filter(func(id): return merchant_sells(id) and not ALL[id].get("smith", false) and (slot == "" or ALL[id].slot == slot))
	return _weighted(rng, ids)


## The hero level each piece of gear suits (see HeroLevel): found as loot
## in places of about that level, and part of what a hero of that level is
## expected to wear. Anything not listed suits level 1.
const LEVELS := {
	"schwert": 1, "rundschild": 1, "lederwams": 1, "lederstiefel": 1, "wollumhang": 1,
	"bronzearmreif": 2, "amulett_leben": 2, "amulett_tempo": 2,
	"axt": 3, "kupferring": 3, "amulett_kraft": 3, "knochenhelm": 3, "leinenrucksack": 3,
	"eilstiefel": 4, "zauberhut": 4, "silberarmreif": 4,
	"kettenhemd": 5, "wappenschild": 5, "schattenumhang": 5,
	"fechtbuch": 5, "axtbuch": 5, "wurfbuch": 5, "schildbuch": 5, "ruestbuch": 5, "schleichbuch": 6,
	"ritterhelm": 6, "rubinring": 6, "baerenkappe": 6, "lederrucksack": 6,
	"klingenring": 6, "axtreif": 6, "schildamulett": 6, "wurfring": 6, "schattenamulett": 6, "lastreif": 6,
	"stachelschild": 7, "streitkolben": 7, "langschwert": 7,
	"koenigsumhang": 8, "krummsaebel": 8, "vampirzahn": 8, "gluecksklee": 8,
	"dornenrune": 9, "plattenpanzer": 10, "drachenschild": 10, "streitaxt": 10,
	"phoenixfeder": 11, "grosser_rucksack": 11, "rabenklinge": 12, "kriegshammer": 12,
	"kristallring": 13, "kristallamulett": 13,
	"reiserucksack": 14,
	"runenhammer": 16,
}
## Loot for a place of level L is gear of level L - LOOT_BELOW to L + LOOT_ABOVE.
const LOOT_BELOW := 4
const LOOT_ABOVE := 1


static func item_level(id: String) -> int:
	return int(LEVELS.get(id, 1))


## Picks a random item; pricier items turn up less often.
## With a slot given, only items for that slot are picked. The smith's own
## wares are never picked: only Gorm sells them. With `area` (a place's
## level, see HeroLevel.place_level) only gear that suits it is picked, so
## deeper and harder places hold better things; the best gear of all still
## turns up in the hardest places, which have nothing above them.
## Items in `exclude` (a set of ids) are left out. When they use up all the
## gear that suits the place, the gear of the nearest other level is picked
## instead (a godborn room on a shallow level may hold only one fitting
## piece); only when nothing at all is left may an excluded item turn up again.
static func random_item(rng: RandomNumberGenerator, min_price := 0, slot := "", area := 0, exclude := {}) -> String:
	var ids := ALL.keys().filter(func(id): return ALL[id].price >= min_price and (slot == "" or ALL[id].slot == slot) and not ALL[id].get("no_loot", false) and not ALL[id].get("smith", false))
	var all := ids
	var low := 0
	if area > 0:
		var top := 0
		for id in ids:
			top = maxi(top, item_level(id))
		low = mini(area - LOOT_BELOW, top - LOOT_BELOW)
		var fitting := ids.filter(func(id): return item_level(id) >= low and item_level(id) <= area + LOOT_ABOVE)
		if not fitting.is_empty():
			ids = fitting
	if not exclude.is_empty():
		var fresh := ids.filter(func(id): return not exclude.has(id))
		if fresh.is_empty():
			fresh = _nearest_level(all.filter(func(id): return not exclude.has(id)), low, area + LOOT_ABOVE)
		if not fresh.is_empty():
			ids = fresh
	return _weighted(rng, ids)


## Those of `ids` whose level lies closest to the range low..high.
static func _nearest_level(ids: Array, low: int, high: int) -> Array:
	var best := -1
	var out := []
	for id in ids:
		var lvl := item_level(id)
		var off := maxi(low - lvl, lvl - high)
		if best < 0 or off < best:
			best = off
			out = [id]
		elif off == best:
			out.append(id)
	return out


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
