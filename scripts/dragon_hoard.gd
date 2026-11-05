class_name DragonHoard
extends RefCounted
## The hoard of Glutschlund, the old dragon of the mountain. Every night its
## little helpers (see DragonHelpers) swarm out of the lair's stone arch and
## carry off everything that lies about on the ground, all of it: gear the
## hero dropped, loot left by the fallen, spilt coins of every metal, in the
## open air, in buildings and below ground alike. Back in the lair the dragon
## melts the gear down into bars of iron, bronze, silver or gold, by the
## piece's kind and rarity (and magic leaves moon silver); coins of gold,
## silver and iron melt into their metal; books and everything else that
## burns go up in its fire. The hoard waits in the lair beside the hoard
## chest, and is the hero's once the dragon has fallen (see Level, "hoard"):
## the iron goes to the smith's iron bars, the moon silver into the pouch,
## the fine bars to the hero for Gorm to buy, the coins into the purse.
##
## While the hero is out in the open at night the helpers can be watched at
## work. Whatever is still lying about when the morning comes, the helpers
## took unseen: the dawn sweep (see sweep) does the same bookkeeping in one
## go, on every map and in every building. Only what lies right beside the
## hero, awake, stays where it is. Things carried for a villager's task and
## the unique pieces are never melted: they go whole to the Great Old One
## (see KEPT_WHOLE_SLOTS), so the hero can fetch them back and no task and
## no trophy is lost for good.
##
## Most of it does not stay with Glutschlund, though: of every ELDER_TURN
## things the helpers carry home (coins and gear that would melt), all but
## the first go further down, into the hoard of the Great Old One below the
## high valley (see ElderLair). There the gear is not melted but heaped up
## whole, so a hero who sneaks in can take it back as it was.
##
## Kept in the saved game: the coins and bars in the hoard, the Great Old
## One's share, and what tonight brought (for the line at dawn).

## Slots of things that burn in the dragon's fire, and gear materials that do.
const BURNS_SLOTS := ["buch", "kiste", "futter", "licht"]
const BURNS_MATERIALS := ["cloth", "leather", "fur"]
## Slots of things the dragon does not melt or burn: things carried for a
## villager's task go whole to the Great Old One (like the unique pieces),
## where the hero can fetch them back.
const KEPT_WHOLE_SLOTS := ["auftrag"]
## The compendium's word on the helpers, learned the first time they take
## something.
const LORE := "Die Helfer des Drachen: Jede Nacht schwärmen kleine Drachlinge aus dem Steinbogen am Berg und sammeln ein, was im Freien am Boden liegt. Glutschlund schmilzt die Ausrüstung ein: Waffen und Rüstungen zu Eisen, feine Stücke und Schmuck zu Bronze, Silber oder Gold, je seltener, desto edler, und Zauberdinge lassen Mondsilber zurück. Bücher und alles, was brennt, gehen in seinem Feuer auf. Wer den Drachen besiegt, nimmt sich seinen Hort: das Eisen für den Schmied, das Mondsilber für Rezepte, die edlen Barren für Gorm, der sie dir abkauft. Lass also nachts nichts draußen liegen, was du behalten willst."
## The compendium's word on how far the helpers go, learned the first
## morning they took something from a building or from below ground.
const EVERYWHERE_LORE := "Die Helfer des Drachen lassen nichts liegen: Sie holen jede Nacht alles, was am Boden liegt, nicht nur im Freien, sondern auch aus Häusern, Höhlen und Verliesen. Münzen aus Gold, Silber und Eisen schmilzt Glutschlund zu Metall. Aufträge und einzigartige Stücke verbrennt und schmilzt er nie: Die bringen die Helfer ganz hinab zum Großen Alten. Was du behalten willst, gehört in die Tasche oder in eine Truhe."
const COLOR := Color(1.0, 0.62, 0.25)
## Of every ELDER_TURN things carried home, the first stays with Glutschlund
## and the rest go to the Great Old One.
const ELDER_TURN := 3
## The most pieces of gear the Great Old One's hoard holds; more is melted
## in Glutschlund's lair as before.
const ELDER_ITEMS_MAX := 40
## The compendium's word on where the helpers take the most of it.
const ELDER_LORE := "Die Helfer des Drachen behalten nicht alles: Den größten Teil ihrer Beute, Münzen und ganze Ausrüstung, schleppen sie tief hinab zum Großen Alten, einem uralten Drachen unter dem Hochtal. Dort liegt sie unversehrt in seinem Hort. Wer leise genug ist, kann sie sich zurückholen."

## The coins heaped up in the lair.
var gold := 0
## The bars (and lumps of moon silver) heaped up beside them, by metal
## (see Forge.METALS).
var metals := {}
## What the helpers took since the last morning: how many things, how many
## burnt, the coins, and the metal it all melted into.
var tonight := {}
## The Great Old One's share: coins and whole pieces of gear (item ids).
var elder_gold := 0
var elder_items: Array[String] = []
## How many things the helpers carried home so far (see ELDER_TURN).
var carried := 0


func _init() -> void:
	clear()


func clear() -> void:
	gold = 0
	metals = {}
	elder_gold = 0
	elder_items = []
	carried = 0
	tonight = _empty_tally()


static func _empty_tally() -> Dictionary:
	return {"things": 0, "burnt": 0, "coins": 0, "metals": {}, "elder": 0}


## What becomes of a thing the helpers find lying about: "coin" (the
## money), "melt", "burn", "keep" (to the Great Old One whole), or "" for
## what is no thing to carry (an unknown id).
static func fate(kind: String, id: String) -> String:
	if kind == "coin":
		# The money is heaped up as it is; the other metals melt.
		return "coin" if CoinPile.metal_of(id) == CoinPile.MONEY else "melt"
	if kind != "item" or not Items.ALL.has(id):
		return ""
	var item: Dictionary = Items.ALL[id]
	if item.get("unique", false) or str(item.get("slot", "")) in KEPT_WHOLE_SLOTS:
		return "keep"
	if Items.is_book(id) or str(item.get("slot", "")) in BURNS_SLOTS or str(item.get("material", "")) in BURNS_MATERIALS:
		return "burn"
	return "melt"


## Whether the helpers take a floor entry ([kind, id, x, z], see
## Level.floor_items).
static func takes(entry) -> bool:
	return entry is Array and entry.size() >= 2 and fate(str(entry[0]), str(entry[1])) != ""


## What a piece melts down into in the dragon's fire, metal -> count: the
## same table as at Gorm's forge (see Forge.melt_into), but whatever does not
## burn melts. Empty for what does not.
static func melt(id: String) -> Dictionary:
	return Forge.melt_into(id, true) if fate("item", id) == "melt" else {}


## What `count` coins of a metal other than the money melt into: their
## grams (Ore.COIN_GRAMS a coin), as at Gorm's forge.
static func melt_coins(id: String, count: int) -> Dictionary:
	var metal := CoinPile.metal_of(id)
	if metal == CoinPile.MONEY or not Loot.COINS.has(metal) or count <= 0:
		return {}
	return {Forge.GRAMS + str(Loot.COINS[metal]): count * Ore.COIN_GRAMS}


## What coins and fine bars are worth in gold coins (the iron and the moon
## silver are kept as they are).
static func coin_worth(coins: int, bars: Dictionary) -> int:
	var total := coins
	for metal in bars:
		if str(metal).begins_with(Forge.GRAMS):
			total += roundi(int(bars[metal]) * float(Forge.GRAM_VALUE.get(str(metal).substr(Forge.GRAMS.length()), 0.0)))
		else:
			total += int(bars[metal]) * int(Forge.METALS.get(metal, {}).get("worth", 0))
	return total


## The helpers brought this home: into the hoard it goes, melted or burnt.
## Returns what it added, metal -> count ("coins" for coins). `count`: how
## many coins a pile held.
func gather(kind: String, id: String, count := 1) -> Dictionary:
	var f := fate(kind, id)
	if f == "":
		return {}
	tonight.things = int(tonight.things) + 1
	if f == "burn":
		tonight.burnt = int(tonight.burnt) + 1
		return {}
	if f == "keep":
		# Never melted: whole to the Great Old One, past its limit too.
		tonight.elder = int(tonight.get("elder", 0)) + 1
		elder_items.append(id)
		return {"elder": 1}
	var to_elder := carried % ELDER_TURN != 0 and (f == "coin" or (kind == "item" and elder_items.size() < ELDER_ITEMS_MAX))
	carried += 1
	if f == "coin":
		tonight.coins = int(tonight.coins) + count
	if to_elder:
		tonight.elder = int(tonight.get("elder", 0)) + 1
		if f == "coin":
			elder_gold += count
		else:
			elder_items.append(id)
		return {"elder": 1}
	if f == "coin":
		gold += count
		return {"coins": count}
	var bars := melt(id) if kind == "item" else melt_coins(id, count)
	for metal in bars:
		metals[metal] = int(metals.get(metal, 0)) + int(bars[metal])
		tonight.metals[metal] = int(tonight.metals.get(metal, 0)) + int(bars[metal])
	return bars


## The dawn sweep: takes everything the helpers would from a floor list
## (see Level.floor_items), changed in place. Returns the ids of the items
## that went (coins not), so the map can count them as taken.
func sweep(list: Array) -> Array[String]:
	var went: Array[String] = []
	for entry in list.duplicate():
		if takes(entry):
			list.erase(entry)
			gather(str(entry[0]), str(entry[1]), CoinPile.count_of(entry))
			if str(entry[0]) == "item":
				went.append(str(entry[1]))
	return went


## The line for the event log about what tonight brought, "" when nothing.
## Clears tonight's tally.
func morning_report() -> String:
	var things := int(tonight.things)
	if things == 0:
		return ""
	var text := Lang.t("In der Nacht trugen die Helfer des Drachen ein Ding vom Boden in seine Höhle.") if things == 1 \
			else Lang.t("In der Nacht trugen die Helfer des Drachen %d Dinge vom Boden in seine Höhle.") % things
	var bars := Forge.metals_text(tonight.metals)
	if bars != "":
		text += " " + Lang.t("Eingeschmolzen zu: %s.") % bars
	if int(tonight.coins) > 0:
		text += " " + Lang.t("Münzen: %d.") % int(tonight.coins)
	if int(tonight.burnt) > 0:
		text += " " + Lang.t("Verbrannt: %d.") % int(tonight.burnt)
	if int(tonight.get("elder", 0)) > 0:
		text += " " + Lang.t("Den größten Teil (%d) schleppten sie hinab in den Hort des Großen Alten.") % int(tonight.elder)
	tonight = _empty_tally()
	return text


## Whether anything lies in the hoard.
func is_empty() -> bool:
	return gold <= 0 and metals.values().all(func(n): return int(n) <= 0)


## The whole hoard as the lair shows it: "coins" and each metal.
func contents() -> Dictionary:
	var out := metals.duplicate()
	out["coins"] = gold
	return out


## The hoard is the hero's: returns it (see contents) and empties it.
func take_all() -> Dictionary:
	var had := contents()
	gold = 0
	metals = {}
	return had


## The Great Old One's share as its lair shows it: "coins" and "items".
func elder_contents() -> Dictionary:
	return {"coins": elder_gold, "items": elder_items.duplicate()}


## The hero took the Great Old One's hoard: returns its share and empties it.
func take_elder() -> Dictionary:
	var had := elder_contents()
	elder_gold = 0
	elder_items = []
	return had


func for_save() -> Dictionary:
	return {"gold": gold, "metals": metals, "tonight": tonight,
		"elder_gold": elder_gold, "elder_items": elder_items, "carried": carried}


## Saved games from before the hoard have none: an empty hoard.
func load_from(data) -> void:
	clear()
	if not data is Dictionary:
		return
	gold = maxi(0, int(data.get("gold", 0)))
	elder_gold = maxi(0, int(data.get("elder_gold", 0)))
	carried = maxi(0, int(data.get("carried", 0)))
	var kept = data.get("elder_items", [])
	if kept is Array:
		for id in kept:
			# No limit here: task items and unique pieces go past it.
			if Items.ALL.has(str(id)):
				elder_items.append(str(id))
	var m = data.get("metals", {})
	if m is Dictionary:
		for metal in m:
			if Forge.is_metal_key(str(metal)) and int(m[metal]) > 0:
				metals[str(metal)] = int(m[metal])
	var t = data.get("tonight", {})
	if t is Dictionary:
		for key in ["things", "burnt", "coins", "elder"]:
			tonight[key] = maxi(0, int(t.get(key, 0)))
		var tm = t.get("metals", {})
		if tm is Dictionary:
			for metal in tm:
				if Forge.is_metal_key(str(metal)):
					tonight.metals[str(metal)] = maxi(0, int(tm[metal]))
