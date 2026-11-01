class_name Wanderer
extends RefCounted
## Zarek, the wandering merchant. He is not one of the village's own people:
## every few nights he rolls his covered cart into Lindenhain at nightfall,
## sets up by the market on his pitch (map tile "@", see Outdoor) and is gone
## again at dawn. He sells rare things found nowhere else, and a few of the
## rarest finds of the dungeon, but buys nothing.
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
## His own wares: only he sells them (Items "wanderer"). Each visit he brings
## EXCLUSIVE_COUNT of them, picked at random.
const EXCLUSIVE := ["mondsteinamulett", "sternenring", "mitternachtsumhang", "siebenmeilenstiefel", "irrlichtarmreif"]
const EXCLUSIVE_COUNT := 2
## The rarest finds of the dungeon: one of them each visit.
const RARE_SPECIALS := ["vampirzahn", "gluecksklee", "dornenrune", "phoenixfeder"]
## Plus one book and one more piece of good gear, at least this pricey.
const GEAR_MIN_PRICE := 30


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


## What he brings on a night: his own wares, a rare special, a book and a
## piece of good gear. The same hero gets the same wares for the same night,
## so loading a saved game does not shuffle them.
static func stock_for(night: int, hero := "") -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [hero, night])
	var own: Array = EXCLUSIVE.duplicate()
	var out: Array[String] = []
	for i in mini(EXCLUSIVE_COUNT, own.size()):
		out.append(own.pop_at(rng.randi() % own.size()))
	out.append(RARE_SPECIALS[rng.randi() % RARE_SPECIALS.size()])
	out.append(Items.random_item(rng, 0, "buch"))
	var gear := Items.random_item(rng, GEAR_MIN_PRICE)
	for i in 8:
		if not gear in out and not Items.is_book(gear):
			break
		gear = Items.random_item(rng, GEAR_MIN_PRICE)
	out.append(gear)
	return out


## What his goods cost: a fifth more than the shopkeeper asks
## (rounded up).
static func price(id: String) -> int:
	return (int(Items.ALL[id].price) * 6 + 4) / 5 if Items.ALL.has(id) else 0
