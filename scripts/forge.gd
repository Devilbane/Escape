class_name Forge
extends RefCounted
## The blacksmith's forge in the village (Gorm the smith):
## - melting down: metal gear (weapons, shields, metal helmets, mail, plate,
##   rings, bracelets and amulets) becomes iron bars, more for pricier pieces;
## - forging: iron bars and some gold become a new piece of metal gear;
## - mending: worn armour and shields get their durability back for gold;
## - iron bars can also be bought from the smith;
## - buying: Gorm sells his own fine weapons and a kite shield ("smith" in
##   Items.ALL), which are found nowhere else.
## Iron bars are counted like gold (game.iron), not carried in the bag, and
## are kept in the saved game.
## Gold prices drop when Gorm thinks well of the hero (see Reputation): the
## functions that take `game` give the price at the smith's window right now.
## Forging from bought iron costs about what the merchant asks for the piece;
## iron from melted loot makes it cheaper, and you choose what you get.

## What the compendium says about the forge, once the hero has been there.
const LEARN := "Schmied Gorm im Dorf arbeitet an seiner Esse: Er verkauft seine eigenen, besseren Waffen, die es sonst nirgends gibt, schmilzt Waffen, Schilde, Metallrüstungen und Schmuck zu Eisenbarren ein, schmiedet aus Eisen und etwas Gold neue Waffen, Schilde und Rüstungen, und bessert abgenutzte Rüstungen und Schilde gegen Gold aus. Eisenbarren verkauft er auch."
## What one iron bar costs at the smith.
const IRON_PRICE := 4
## Materials of gear that melts down into iron (see Items, "material").
const MELTS := ["metal", "chain", "mixed"]
## Slots whose pieces are all metal (jewellery), whatever their material says.
const METAL_SLOTS := ["ring", "armreif", "amulett"]
## Gold per point of durability mended, at the least.
const MIN_MEND_PRICE := 2


## Whether the smith can melt an item down.
static func can_melt(id: String) -> bool:
	if not Items.ALL.has(id):
		return false
	var item: Dictionary = Items.ALL[id]
	return item.get("material", "") in MELTS or item.slot in METAL_SLOTS


## Iron bars an item melts down into.
static func melt_yield(id: String) -> int:
	return maxi(1, roundi(Items.ALL[id].price / 8.0)) if can_melt(id) else 0


## Every piece the smith can forge: the metal weapons, shields and armour.
static func recipes() -> Array:
	var ids := []
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.get("material", "") in MELTS and not item.get("no_loot", false):
			ids.append(id)
	ids.sort_custom(func(a, b): return Items.ALL[a].price < Items.ALL[b].price)
	return ids


## Gorm's own wares, cheapest first: only the smith sells them.
static func wares() -> Array:
	var ids := Items.ALL.keys().filter(func(id): return Items.ALL[id].get("smith", false))
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
	if not Items.ALL.has(id) or not Items.ALL[id].get("smith", false):
		return Lang.t("Das verkauft Gorm nicht.")
	var price := ware_price(game, id)
	if game.coins < price:
		return Lang.t("Dafür reicht dein Gold nicht.")
	if p.bag.size() >= p.bag_size():
		return Lang.t("Deine Tasche ist voll.")
	game.coins -= price
	p.bag.append(id)
	return ""


## What forging a piece costs: {"iron": bars, "gold": coins}.
static func forge_cost(id: String, game: Node = null) -> Dictionary:
	var price: int = Items.ALL[id].price
	return {"iron": ceili(price / 6.0), "gold": _discounted(game, price / 3)}


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
	game.iron += melt_yield(id)
	return ""


## Forges a new piece into the bag. Returns "" on success, else why not.
static func forge(game: Node, id: String) -> String:
	var p: Player = game.player
	var cost := forge_cost(id, game)
	if game.iron < cost.iron:
		return Lang.t("Dafür hast du zu wenig Eisen.")
	if game.coins < cost.gold:
		return Lang.t("Dafür reicht dein Gold nicht.")
	if p.bag.size() >= p.bag_size():
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
