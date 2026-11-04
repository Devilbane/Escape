class_name Forge
extends RefCounted
## The blacksmith's forge in the village (Gorm the smith):
## - melting down: metal gear (weapons, shields, metal helmets, mail, plate,
##   rings, bracelets and amulets) becomes metal by its kind and rarity (see
##   melt_into; the dragon's hoard melts by the same table, see DragonHoard):
##   weapons and armour iron bars, more for pricier pieces, fine ones a bar
##   of bronze, silver or gold besides; jewellery bars of bronze, silver or
##   gold; magic pieces from rare on a lump of moon silver as well;
## - Gorm buys the bronze, silver and gold bars back for gold;
## - forging: iron bars and some gold become a new piece of metal gear; the
##   thunder weapons also take lumps of thunder ore from the bag (see Items,
##   "thunder"), and their blows may stun (see Enemy.shock);
## - mending: worn armour and shields get their durability back for gold;
## - iron bars can also be bought from the smith;
## - buying: Gorm sells his own fine weapons and a kite shield ("smith" in
##   Items.ALL), which are found nowhere else.
## Iron bars are counted like gold (game.iron), the fine bars beside them
## (game.bars), the moon silver goes into the pouch (see Crafting); none of
## it is carried in the bag, and all of it is kept in the saved game.
## Gold prices drop when Gorm thinks well of the hero (see Reputation): the
## functions that take `game` give the price at the smith's window right now.
## Forging from bought iron costs about what the merchant asks for the piece;
## iron from melted loot makes it cheaper, and you choose what you get.

## What the compendium says about the forge, once the hero has been there.
const LEARN := "Schmied Gorm im Dorf arbeitet an seiner Esse: Er verkauft seine eigenen, besseren Waffen, die es sonst nirgends gibt, schmilzt Waffen, Schilde, Metallrüstungen und Schmuck zu Eisenbarren ein, schmiedet aus Eisen und etwas Gold neue Waffen, Schilde und Rüstungen, aus Donnererz vom Gewitter auch Donnerwaffen, deren Treffer Gegner kurz betäuben können, und bessert abgenutzte Rüstungen und Schilde gegen Gold aus. Eisenbarren verkauft er auch."
## What one iron bar costs at the smith.
const IRON_PRICE := 4
## Materials of gear that melts down into iron (see Items, "material").
const MELTS := ["metal", "chain", "mixed"]
## Slots whose pieces are all metal (jewellery), whatever their material says.
const METAL_SLOTS := ["ring", "armreif", "amulett"]
## Gold per point of durability mended, at the least.
const MIN_MEND_PRICE := 2
## The metals gear melts into, in the order they are told: the German name of
## a bar (or lump), a short word for a price line, the colour of the bars,
## and what Gorm pays for one bar ("worth"). Iron and moon silver are not
## bought back: they are worth more forged (see forge) and in recipes.
const METALS := {
	"eisen": {"name": "Eisenbarren", "short": "Eisen", "color": Color(0.55, 0.57, 0.6)},
	"bronze": {"name": "Bronzebarren", "short": "Bronze", "color": Color(0.8, 0.5, 0.25), "worth": 3},
	"silber": {"name": "Silberbarren", "short": "Silber", "color": Color(0.85, 0.87, 0.92), "worth": 7},
	"gold": {"name": "Goldbarren", "short": "Goldbarren", "color": Color(1.0, 0.8, 0.3), "worth": 15},
	"mondsilbererz": {"name": "Mondsilbererz", "short": "Mondsilber", "color": Color(0.6, 0.75, 1.0)},
}
## The fine bars Gorm buys back.
const FINE := ["bronze", "silber", "gold"]
## The fine metal of a piece by its rarity (see rarity, common to god-born):
## jewellery is made of it, and fine weapons and armour have fittings of it
## besides their iron.
const PRECIOUS := ["bronze", "bronze", "silber", "gold", "gold"]
const FITTINGS := ["", "", "bronze", "silber", "gold"]
## Magic pieces from this rarity on leave a lump of moon silver.
const MOON_FROM := 2


## Whether the smith can melt an item down.
static func can_melt(id: String) -> bool:
	if not Items.ALL.has(id):
		return false
	var item: Dictionary = Items.ALL[id]
	return item.get("material", "") in MELTS or item.slot in METAL_SLOTS


## Iron bars an item melts down into.
static func melt_yield(id: String) -> int:
	return int(melt_into(id).get("eisen", 0))


## How rare a piece is, 0 (common) to 4 (god-born) (see Items.RARITY).
static func rarity(id: String) -> int:
	return Level.rank_of(id)


## Whether a piece is jewellery or a charm rather than a weapon or armour.
static func _is_trinket(id: String) -> bool:
	return str(Items.ALL[id].slot) in METAL_SLOTS or str(Items.ALL[id].slot) == "spezial"


## The one melting table, for the smith and the dragon alike: what a piece
## melts into, metal (see METALS) -> count. Empty for what does not melt.
## - weapons, shields and metal armour: iron bars, one for every 8 gold of
##   price, and from rare on one bar of the fine metal of their fittings;
## - jewellery: bars of the fine metal of its rarity, as many as its worth
##   at the merchant buys (one at the least);
## - magic pieces from rare on: a lump of moon silver as well.
## `any`: the dragon's fire melts more than Gorm's forge; a piece that is no
## metal (a bone helmet, a charm) gives fine bars like jewellery.
static func melt_into(id: String, any := false) -> Dictionary:
	var out := {}
	if not Items.ALL.has(id) or not (can_melt(id) or any):
		return out
	var item: Dictionary = Items.ALL[id]
	var r := rarity(id)
	if can_melt(id) and not _is_trinket(id):
		out["eisen"] = maxi(1, roundi(int(item.price) / 8.0))
		if FITTINGS[r] != "" and str(item.slot) in Items.SLOTS:
			out[FITTINGS[r]] = 1
	else:
		var metal: String = PRECIOUS[r]
		out[metal] = maxi(1, roundi(maxi(1, int(item.price) / 2) / float(METALS[metal].worth)))
	if item.get("magic", false) and r >= MOON_FROM:
		out["mondsilbererz"] = 1
	return out


## Metals in METALS order as a list of words: "2× Eisenbarren, 1×
## Silberbarren" (translated), or short for a price line: "+2 Eisen, +1
## Silber".
static func metals_text(bars: Dictionary, short := false) -> String:
	var parts := []
	for metal in METALS:
		var n := int(bars.get(metal, 0))
		if n > 0:
			parts.append(("+%d %s" if short else "%d× %s") % [n, Lang.t(METALS[metal].short if short else METALS[metal].name)])
	return ", ".join(parts)


## Puts metal into the hero's stores: iron bars, fine bars, moon silver into
## the pouch.
static func store(game: Node, bars: Dictionary) -> void:
	for metal in bars:
		var n := int(bars[metal])
		if n <= 0:
			continue
		match metal:
			"eisen":
				game.iron += n
			"mondsilbererz":
				game.crafting.add("mondsilbererz", n, false)
			_:
				if metal in FINE:
					game.bars[metal] = int(game.bars.get(metal, 0)) + n


## Sells the hero's fine bars of one metal to Gorm (`count` of them, all
## when -1). Returns "" on success, else why not.
static func sell_bars(game: Node, metal: String, count := -1) -> String:
	var have := int(game.bars.get(metal, 0))
	if not metal in FINE or have <= 0:
		return Lang.t("Davon hast du keine Barren.")
	var n := have if count < 0 else mini(count, have)
	game.bars[metal] = have - n
	if int(game.bars[metal]) <= 0:
		game.bars.erase(metal)
	game.coins += n * int(METALS[metal].worth)
	return ""


## What the thunder weapons are forged from besides iron and gold.
const THUNDER_ORE := "donnererz"


## Every piece the smith can forge: the metal weapons, shields and armour,
## and the thunder weapons.
static func recipes() -> Array:
	var ids := []
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.get("material", "") in MELTS and (not item.get("no_loot", false) or item.has("thunder")):
			ids.append(id)
	ids.sort_custom(func(a, b): return Items.ALL[a].price < Items.ALL[b].price)
	return ids


## Gorm's own wares, cheapest first: only the smith sells them. The top tier
## of each kind (the war hammer, the kite shield) he only forges, from the
## hero's iron (see Items.merchant_sells).
static func wares() -> Array:
	var ids := Items.ALL.keys().filter(func(id): return Items.ALL[id].get("smith", false) and Items.merchant_sells(id))
	ids.sort_custom(func(a, b): return Items.ALL[a].price < Items.ALL[b].price)
	return ids


## A gold price after the discount at the smith's window (unchanged without
## a game, or when the window was not opened at Gorm).
static func _discounted(game: Node, gold: int) -> int:
	return game.trader_price(gold) if game else gold


## What one of Gorm's wares costs the hero.
static func ware_price(game: Node, id: String) -> int:
	return _discounted(game, Items.ALL[id].price)


## What one iron bar costs the hero.
static func iron_price(game: Node = null) -> int:
	return _discounted(game, IRON_PRICE)


## Buys one of Gorm's wares into the bag. Returns "" on success, else why not.
static func buy(game: Node, id: String) -> String:
	var p: Player = game.player
	if not wares().has(id):
		return Lang.t("Das verkauft Gorm nicht.")
	var price := ware_price(game, id)
	if game.coins < price:
		return Lang.t("Dafür reicht dein Gold nicht.")
	if p.bag_used() >= p.bag_size():
		return Lang.t("Deine Tasche ist voll.")
	game.coins -= price
	p.bag.append(id)
	return ""


## What forging a piece costs: {"iron": bars, "gold": coins, "ore": lumps of
## thunder ore from the bag (0 but for the thunder weapons)}.
static func forge_cost(id: String, game: Node = null) -> Dictionary:
	var price: int = Items.ALL[id].price
	return {"iron": ceili(price / 6.0), "gold": _discounted(game, price / 3), "ore": int(Items.ALL[id].get("thunder", 0))}


## Whether the hero has everything forging a piece takes (room in the bag
## aside).
static func can_afford(game: Node, id: String) -> bool:
	var cost := forge_cost(id, game)
	return game.iron >= cost.iron and game.coins >= cost.gold and game.player.bag.count(THUNDER_ORE) >= cost.ore



## Gold for mending one point of durability of a piece.
static func mend_price(id: String, game: Node = null) -> int:
	return _discounted(game, maxi(MIN_MEND_PRICE, int(Items.ALL[id].price) / 10))


## Every worn-down piece the hero has, worn first, then in the bag, each once.
static func worn_down(p: Player) -> Array:
	var ids := []
	var order: Array = p.equipped.values()
	order.append_array(p.bag)
	for id in order:
		if int(p.wear.get(id, 0)) > 0 and not ids.has(id):
			ids.append(id)
	return ids


## Gold to mend a piece completely.
static func mend_cost(p: Player, id: String, game: Node = null) -> int:
	return int(p.wear.get(id, 0)) * mend_price(id, game)


## Melts the bag item at `index` down. Returns "" on success, else why not.
static func melt(game: Node, index: int) -> String:
	var p: Player = game.player
	if index < 0 or index >= p.bag.size():
		return Lang.t("Da ist nichts.")
	var id: String = p.bag[index]
	if not can_melt(id):
		return Lang.t("%s lässt sich nicht einschmelzen.") % Items.item_name(id)
	p.bag.remove_at(index)
	if not p.bag.has(id) and not p.equipped.values().has(id):
		p.wear.erase(id)
	store(game, melt_into(id))
	return ""


## Forges a new piece into the bag. Returns "" on success, else why not.
static func forge(game: Node, id: String) -> String:
	var p: Player = game.player
	var cost := forge_cost(id, game)
	if game.iron < cost.iron:
		return Lang.t("Dafür hast du zu wenig Eisen.")
	if game.coins < cost.gold:
		return Lang.t("Dafür reicht dein Gold nicht.")
	if p.bag.count(THUNDER_ORE) < cost.ore:
		return Lang.t("Dafür hast du zu wenig Donnererz. Es glimmt nur bei Gewitter neben den Felsen.")
	for _i in cost.ore:
		p.bag.erase(THUNDER_ORE)
	if not p.bag_fits(id):
		# The ore went in vain: put it back.
		for _i in cost.ore:
			p.bag.append(THUNDER_ORE)
		return Lang.t("Deine Tasche ist voll.")
	game.iron -= cost.iron
	game.coins -= cost.gold
	p.bag.append(id)
	return ""


## Mends a piece as far as the gold goes. Returns "" on success, else why not.
static func mend(game: Node, id: String) -> String:
	var p: Player = game.player
	if int(p.wear.get(id, 0)) <= 0:
		return Lang.t("%s ist wie neu.") % Items.item_name(id)
	var price := mend_price(id, game)
	if game.coins < price:
		return Lang.t("Dafür reicht dein Gold nicht.")
	while int(p.wear.get(id, 0)) > 0 and game.coins >= price:
		p.wear[id] = int(p.wear[id]) - 1
		game.coins -= price
	if int(p.wear[id]) <= 0:
		p.wear.erase(id)
	return ""


## Buys iron bars. Returns "" on success, else why not.
static func buy_iron(game: Node, count: int) -> String:
	var price := iron_price(game)
	if count <= 0 or game.coins < price * count:
		return Lang.t("Dafür reicht dein Gold nicht.")
	game.coins -= price * count
	game.iron += count
	return ""
