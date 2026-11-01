class_name Wanderer
extends RefCounted
## Zarek, the wandering merchant. He is not one of the village's own people:
## every few nights he rolls his covered cart into Lindenhain at nightfall,
## sets up by the market on his pitch (map tile "@", see Outdoor) and is gone
## again at dawn. He sells crafting ingredients from far away and a little
## plain gear, but buys nothing.
##
## Everything here is pure: which nights he comes and what he brings. The
## village puts him and his cart up (Outdoor), the game keeps his wares for
## the night (Game.wanderer_stock) and the trading window sells them
## (Menus._build_wanderer).

## The villager role he is built as (see Villager.ROLES).
const ROLE := "%"
## He comes every EVERY-th night, starting with night FIRST (night 0 is the
## first night of a new game): nights 1, 4, 7, ...
const EVERY := 3
const FIRST := 1
## Merchants sell only plain, basic gear and books (see Items.merchant_sells):
## nothing magic, special or top of its kind, which stays for loot and
## crafting.
## What makes Zarek worth the wait are his ingredients from far away (see
## Crafting.INGREDIENTS), with what each piece costs. The rarest finds (the
## truffle, the rare fish) are not for sale: those the hero has to find.
const INGREDIENT_PRICES := {
	"mondsilbererz": 30, "mondstein": 35, "glimmermoos": 18,
	"baerlauch": 8, "steinpilz": 10, "hoehlenpilz": 10,
}
## Each visit he brings this many kinds of ingredient, one to MAX_EACH pieces
## of each, and this many pieces of basic gear.
const INGREDIENT_KINDS := 3
const MAX_EACH := 2
const GEAR_COUNT := 2


## Nights are counted like days (see Game.day): a day begins at dawn, so the
## night after day d's evening, past midnight too, is night d.

## Whether the merchant comes on a night.
static func visits(night: int) -> bool:
	return night >= FIRST and (night - FIRST) % EVERY == 0


## Whether the merchant is in the village at a day and hour: only at night,
## and only on his nights.
static func is_here(day: int, hour: float) -> bool:
	return DayNight.is_night(hour) and visits(day)


## How many nights from `night` until his next visit (0: he comes that night).
static func nights_until(night: int) -> int:
	var n := 0
	while not visits(night + n):
		n += 1
	return n


## What he brings on a night: a few kinds of ingredient (one entry per
## piece) and some basic gear or a book. The same hero gets the same wares for the same
## night, so loading a saved game does not shuffle them.
static func stock_for(night: int, hero := "") -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [hero, night])
	var out: Array[String] = []
	var kinds: Array = INGREDIENT_PRICES.keys().filter(func(id): return Crafting.INGREDIENTS.has(id))
	for i in mini(INGREDIENT_KINDS, kinds.size()):
		var id: String = kinds.pop_at(rng.randi() % kinds.size())
		for n in rng.randi_range(1, MAX_EACH):
			out.append(id)
	var gear: Array = Items.ALL.keys().filter(is_gear_for_sale)
	for i in mini(GEAR_COUNT, gear.size()):
		out.append(gear.pop_at(rng.randi() % gear.size()))
	return out


## Whether he may bring an item: what any merchant may sell, but not the
## smith's own work (only Gorm sells that).
static func is_gear_for_sale(id: String) -> bool:
	return Items.merchant_sells(id) and not Items.ALL[id].get("smith", false)


## Whether a ware is an ingredient (it goes into the pouch, not the bag).
static func is_ingredient(id: String) -> bool:
	return INGREDIENT_PRICES.has(id)


## A ware's name, for an ingredient or an item.
static func ware_name(id: String) -> String:
	return Crafting.ingredient_name(id) if is_ingredient(id) else Items.item_name(id)


## What his goods cost: an ingredient its own price; gear a fifth more than
## the shopkeeper asks (rounded up), for the long road.
static func price(id: String) -> int:
	if is_ingredient(id):
		return INGREDIENT_PRICES[id]
	return (int(Items.ALL[id].price) * 6 + 4) / 5 if Items.ALL.has(id) else 0
