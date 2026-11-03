class_name DragonHoard
extends RefCounted
## The hoard of Glutschlund, the old dragon of the mountain. Every night its
## little helpers (see DragonHelpers) swarm out of the lair's stone arch and
## carry off what lies about on the open ground of the world: gear the hero
## dropped, loot left by the fallen, spilt coins. Back in the lair the dragon
## melts the gear down into bars of iron, bronze, silver or gold, by the
## piece's kind and rarity (and magic leaves moon silver); books and
## everything else that burns go up in its fire. The hoard waits in the lair
## beside the hoard chest, and is the hero's once the dragon has fallen (see
## Level, "hoard"): the iron goes to the smith's iron bars, the moon silver
## into the pouch, the fine bars to the hero for Gorm to buy, the coins
## into the purse.
##
## While the hero is out in the open at night the helpers can be watched at
## work. Whatever is still lying about when the morning comes while the hero
## was elsewhere (in a building, asleep, below ground) the helpers took
## unseen: the dawn sweep (see sweep) does the same bookkeeping in one go.
## Only the open air is swept; inside buildings and below ground nothing is
## touched. Things carried for a villager's task and the unique blades are
## left where they lie, so no task and no trophy is ever lost.
##
## Kept in the saved game: the coins and bars in the hoard, and what tonight brought
## (for the line at dawn).

## Slots of things that burn in the dragon's fire, and gear materials that do.
const BURNS_SLOTS := ["buch", "kiste", "futter", "licht"]
const BURNS_MATERIALS := ["cloth", "leather", "fur"]
## Slots the helpers leave alone: things carried for a villager's task.
const LEFT_ALONE_SLOTS := ["auftrag"]
## The compendium's word on the helpers, learned the first time they take
## something.
const LORE := "Die Helfer des Drachen: Jede Nacht schwärmen kleine Drachlinge aus dem Steinbogen am Berg und sammeln ein, was im Freien am Boden liegt. Glutschlund schmilzt die Ausrüstung ein: Waffen und Rüstungen zu Eisen, feine Stücke und Schmuck zu Bronze, Silber oder Gold, je seltener, desto edler, und Zauberdinge lassen Mondsilber zurück. Bücher und alles, was brennt, gehen in seinem Feuer auf. Wer den Drachen besiegt, nimmt sich seinen Hort: das Eisen für den Schmied, das Mondsilber für Rezepte, die edlen Barren für Gorm, der sie dir abkauft. Lass also nachts nichts draußen liegen, was du behalten willst."
const COLOR := Color(1.0, 0.62, 0.25)

## The coins heaped up in the lair.
var gold := 0
## The bars (and lumps of moon silver) heaped up beside them, by metal
## (see Forge.METALS).
var metals := {}
## What the helpers took since the last morning: how many things, how many
## burnt, the coins, and the metal it all melted into.
var tonight := {}


func _init() -> void:
	clear()


func clear() -> void:
	gold = 0
	metals = {}
	tonight = _empty_tally()


static func _empty_tally() -> Dictionary:
	return {"things": 0, "burnt": 0, "coins": 0, "metals": {}}


## What becomes of a thing the helpers find lying about: "coin", "melt",
## "burn", or "" when they leave it where it lies.
static func fate(kind: String, id: String) -> String:
	if kind == "coin":
		return "coin"
	if kind != "item" or not Items.ALL.has(id):
		return ""
	var item: Dictionary = Items.ALL[id]
	if item.get("unique", false) or str(item.get("slot", "")) in LEFT_ALONE_SLOTS:
		return ""
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


## What coins and fine bars are worth in gold coins (the iron and the moon
## silver are kept as they are).
static func coin_worth(coins: int, bars: Dictionary) -> int:
	var total := coins
	for metal in bars:
		total += int(bars[metal]) * int(Forge.METALS.get(metal, {}).get("worth", 0))
	return total


## The helpers brought this home: into the hoard it goes, melted or burnt.
## Returns what it added, metal -> count ("coins" for a coin).
func gather(kind: String, id: String) -> Dictionary:
	var f := fate(kind, id)
	if f == "":
		return {}
	tonight.things = int(tonight.things) + 1
	match f:
		"coin":
			gold += 1
			tonight.coins = int(tonight.coins) + 1
			return {"coins": 1}
		"burn":
			tonight.burnt = int(tonight.burnt) + 1
			return {}
	var bars := melt(id)
	for metal in bars:
		metals[metal] = int(metals.get(metal, 0)) + int(bars[metal])
		tonight.metals[metal] = int(tonight.metals.get(metal, 0)) + int(bars[metal])
	return bars


## The dawn sweep: takes everything the helpers would from a floor list of
## the open air (see Level.floor_items), changed in place. Returns how many
## things went.
func sweep(list: Array) -> int:
	var count := 0
	for entry in list.duplicate():
		if takes(entry):
			list.erase(entry)
			gather(str(entry[0]), str(entry[1]))
			count += 1
	return count


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


func for_save() -> Dictionary:
	return {"gold": gold, "metals": metals, "tonight": tonight}


## Saved games from before the hoard have none: an empty hoard.
func load_from(data) -> void:
	clear()
	if not data is Dictionary:
		return
	gold = maxi(0, int(data.get("gold", 0)))
	var m = data.get("metals", {})
	if m is Dictionary:
		for metal in m:
			if Forge.METALS.has(str(metal)) and int(m[metal]) > 0:
				metals[str(metal)] = int(m[metal])
	var t = data.get("tonight", {})
	if t is Dictionary:
		for key in ["things", "burnt", "coins"]:
			tonight[key] = maxi(0, int(t.get(key, 0)))
		var tm = t.get("metals", {})
		if tm is Dictionary:
			for metal in tm:
				if Forge.METALS.has(str(metal)):
					tonight.metals[str(metal)] = maxi(0, int(tm[metal]))
