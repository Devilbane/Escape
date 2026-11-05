class_name HomeStores
extends RefCounted
## The two special stores in every town house on Weavers' Lane (see Homes),
## beside the plain storage chest:
##   metall   a steel-banded chest ("m" on the home's map) for what is made of
##            metal or dug from the rock: gold coins, iron bars, the fine bars
##            from Gorm's forge (Forge.FINE), ore and raw gems (moon silver,
##            moonstone, grotto crystals, thunder ore).
##   zutaten  an ingredient board ("h"): shelves on the wall with phials,
##            flasks, bundles of herbs and a filled bucket, for everything
##            else of the ingredient pouch (herbs, mushrooms, fish, the parts
##            of the dragon) and the animal food from the bag.
## Both count what they hold, like the pouch: kind -> how many. Coins, bars
## and ingredients are counted on the hero too (game.coins, game.iron,
## game.bars, the pouch); the bag's items (thunder ore, food) leave the bag
## one by one and need a free place in it to come back. Nothing is lost from
## either store, and neither has a limit. Kept in the saved game
## (Game.home_stores).
##
## Item types added later join by themselves: an item with "store": "metall"
## or "store": "zutaten" in Items.ALL goes to that store, as does an ingredient
## with the same key in Crafting.INGREDIENTS. Without the key, ore ("erz"
## slot) goes in the chest and food ("futter") on the board.

const METAL := "metall"
const PANTRY := "zutaten"
## The station kinds of the two (see Level and Menus).
const STATIONS := {METAL: "metalltruhe", PANTRY: "zutatenbord"}
## The coins in the chest, by this id (no item or ingredient has it).
const COINS := "muenzen"
## Coins move ten at a time with the small button, everything else one.
const COIN_STEP := 10
## Ingredients of the pouch that are ore or gems: they go in the chest, the
## rest on the board.
const MINERALS := ["mondsilbererz", "mondstein", "grottenkristall"]

## What the compendium says about the two, once the hero has opened one.
const LEARN := "In deinem Haus in der Weberzeile stehen neben der Lagertruhe zwei besondere Vorräte: eine stahlbeschlagene Truhe für Münzen, Barren, Erz und rohe Edelsteine, und ein Zutatenbord für Kräuter, Pilze, Fische, Phiolen und Tierfutter. Beide fassen beliebig viel."


## The store a kind belongs in, or "" for neither.
static func store_of(id: String) -> String:
	if id == COINS or id == "eisen" or id in Forge.FINE:
		return METAL
	if Items.ALL.has(id):
		var item: Dictionary = Items.ALL[id]
		if item.has("store"):
			return str(item.store) if str(item.store) in STATIONS else ""
		if Items.is_quest(id) or item.get("custom", false):
			return ""
		if item.slot == "erz":
			return METAL
		if item.slot == "futter":
			return PANTRY
		return ""
	if Crafting.INGREDIENTS.has(id):
		var given := str(Crafting.INGREDIENTS[id].get("store", ""))
		if given in STATIONS:
			return given
		return METAL if id in MINERALS else PANTRY
	return ""


## Every kind that may go into a store, in the order its window lists them:
## coins and bars first, then the pouch's (in the order of the ingredient
## book), then the bag's.
static func kinds(store: String) -> Array:
	var out := []
	for id in [COINS, "eisen"] + Forge.FINE:
		if store_of(id) == store:
			out.append(id)
	for id in Crafting.INGREDIENTS:
		if store_of(id) == store:
			out.append(id)
	for id in Items.ALL:
		if store_of(id) == store:
			out.append(id)
	return out


## Whether a kind is an item carried in the bag (and not counted elsewhere).
static func in_bag(id: String) -> bool:
	return Items.ALL.has(id)


## How many of a kind the hero carries.
static func carried(game: Node, id: String) -> int:
	if id == COINS:
		return game.coins
	if in_bag(id):
		return game.player.bag.count(id)
	return game.crafting.have(id)


## How many of a kind lie in the store at home.
static func stored(game: Node, id: String) -> int:
	return int(game.home_stores.get(store_of(id), {}).get(id, 0))


## The kinds the window shows: those the hero carries or has stored. A kind
## of neither stays hidden, so the board does not name what was never found.
static func shown(game: Node, store: String) -> Array:
	return kinds(store).filter(func(id): return carried(game, id) > 0 or stored(game, id) > 0)


## How many one click of the small button moves.
static func step(id: String) -> int:
	return COIN_STEP if id == COINS else 1


## Puts up to `count` of a kind from the hero into its store. Returns how
## many went in.
static func put(game: Node, id: String, count: int) -> int:
	var store := store_of(id)
	var n := mini(count, carried(game, id))
	if store == "" or n <= 0:
		return 0
	_change_carried(game, id, -n)
	var box: Dictionary = game.home_stores.get(store, {})
	box[id] = int(box.get(id, 0)) + n
	game.home_stores[store] = box
	return n


## Takes up to `count` of a kind out of its store to the hero: things for the
## bag only while it has room. Returns how many came out.
static func take(game: Node, id: String, count: int) -> int:
	var store := store_of(id)
	var n := mini(count, stored(game, id))
	if store == "" or n <= 0:
		return 0
	if in_bag(id):
		var fit := 0
		var bag: Array = game.player.bag.duplicate()
		while fit < n and Items.fits(bag, game.player.bag_size(), id):
			bag.append(id)
			fit += 1
		n = fit
		if n <= 0:
			return 0
	_change_carried(game, id, n)
	var box: Dictionary = game.home_stores[store]
	box[id] = int(box[id]) - n
	if box[id] <= 0:
		box.erase(id)
	return n


## Puts everything of the store's kinds the hero carries into it. Returns
## how many things went in.
static func put_all(game: Node, store: String) -> int:
	var moved := 0
	for id in kinds(store):
		moved += put(game, id, carried(game, id))
	return moved


## Takes everything out of a store that the hero can carry. Returns how
## many things came out.
static func take_all(game: Node, store: String) -> int:
	var moved := 0
	for id in kinds(store):
		moved += take(game, id, stored(game, id))
	return moved


static func _change_carried(game: Node, id: String, n: int) -> void:
	if id == COINS:
		game.coins += n
	elif id == "eisen":
		game.iron += n
	elif id in Forge.FINE:
		var left := int(game.bars.get(id, 0)) + n
		if left > 0:
			game.bars[id] = left
		else:
			game.bars.erase(id)
	elif in_bag(id):
		for i in absi(n):
			if n > 0:
				game.player.bag.append(id)
			else:
				game.player.bag.erase(id)
	else:
		var left: int = game.crafting.have(id) + n
		if left > 0:
			game.crafting.pouch[id] = left
		else:
			game.crafting.pouch.erase(id)


## The empty stores of a new game.
static func empty() -> Dictionary:
	return {METAL: {}, PANTRY: {}}


## What is kept in the saved game: only plain values.
static func for_save(stores: Dictionary) -> Dictionary:
	return stores.duplicate(true)


## Back from the saved game: unknown kinds, kinds kept in the wrong store
## and counts below one are left out; older saved games start empty.
static func load_from(saved) -> Dictionary:
	var out := empty()
	if not (saved is Dictionary):
		return out
	for store in out:
		var box = saved.get(store, {})
		if not (box is Dictionary):
			continue
		for id in box:
			var count := int(box[id])
			if count > 0 and store_of(str(id)) == store:
				out[store][str(id)] = count
	return out
