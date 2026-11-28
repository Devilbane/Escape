class_name Wealth
extends RefCounted
## What the hero is worth, as one sum in copper, and the log of it kept in the saved game.
##
## Worth = the coins (copper, silver and gold at their rate, see Loot.COIN_VALUE) + what a merchant would pay for
## every sellable item the hero owns (Menus.sell_price): worn and carried, in the storage chest and the house's
## crates, chests, racks and shelves, and in the bank (the account and the vault). Quest items, which no merchant
## buys, count for nothing, and so do ingredients, bars and ore pieces, which are not sold in the shops.
## One point per day is kept (the last reading of that day wins), so the chart (see WealthWindow) shows how the
## hero's fortune grew from day to day. A point is written each new morning, when the game is saved and when the
## chart is opened.

## The most days the log keeps; the oldest fall off first.
const KEEP := 730

## The parts of the total, in the order the window lists them.
const PARTS := ["purse", "carried", "home", "bank"]


## What one item fetches from a merchant, in copper (0 for a thing nobody buys).
static func item_worth(id: String) -> int:
	if not Items.ALL.has(id) or Items.is_quest(id):
		return 0
	return Menus.sell_price(id)


## The worth of a list of item ids.
static func items_worth(ids: Array) -> int:
	var sum := 0
	for id in ids:
		sum += item_worth(str(id))
	return sum


## The worth of coins by id ("kupfermuenze", "silbermuenze", "goldmuenze"): kind -> how many.
static func coins_worth(counts: Dictionary) -> int:
	var sum := 0
	for id in counts:
		sum += int(Loot.COIN_VALUE.get(id, 0)) * maxi(0, int(counts[id]))
	return sum


## What the house's stores hold: the copper in the chest, the pouch's other coins and the items counted by kind.
static func home_stores_worth(stores: Dictionary) -> int:
	var sum := 0
	for store in stores:
		var box = stores[store]
		if store == HomeStores.PIECES or not (box is Dictionary):
			continue
		for id in box:
			var n := maxi(0, int(box[id]))
			if id == HomeStores.COINS:
				sum += n
			elif Loot.COIN_VALUE.has(id):
				sum += n * int(Loot.COIN_VALUE[id])
			else:
				sum += n * item_worth(str(id))
	return sum


## The worth of everything the hero owns, by part, and "total".
static func compute(game: Node) -> Dictionary:
	var held := {}
	for metal in Loot.COIN_VALUE:
		held[metal] = game.coins_held(metal)
	var purse := coins_worth(held)
	var carried := items_worth(game.player.bag)
	for slot in game.player.equipped:
		carried += item_worth(str(game.player.equipped[slot]))
	var home := items_worth(game.storage) + home_stores_worth(game.home_stores)
	for key in game.piece_stores:
		home += items_worth(game.piece_stores[key])
	var hero: String = game.hero_name
	var bank := 0
	if hero != "":
		bank = Bank.gold(hero) + items_worth(Bank.vault_items(hero))
	return {"purse": purse, "carried": carried, "home": home, "bank": bank, "total": purse + carried + home + bank}


## Writes today's reading into the log: a reading of the same day is replaced, an earlier day is left alone.
## `log` is an array of [day, copper] pairs, oldest first.
static func record(log: Array, day: int, total: int) -> void:
	if not log.is_empty() and int(log.back()[0]) == day:
		log[log.size() - 1] = [day, total]
	elif log.is_empty() or int(log.back()[0]) < day:
		log.append([day, total])
	while log.size() > KEEP:
		log.remove_at(0)


## The log as the saved game keeps it: plain pairs of whole numbers.
static func for_save(log: Array) -> Array:
	return log.duplicate(true)


## The log from the saved game: pairs of numbers only, days in rising order, the worst of a damaged file left out.
static func load_from(saved) -> Array:
	var out := []
	if not (saved is Array):
		return out
	for entry in saved:
		if entry is Array and entry.size() == 2 and (entry[0] is float or entry[0] is int) and (entry[1] is float or entry[1] is int):
			var day := int(entry[0])
			if day >= 0 and (out.is_empty() or day > int(out.back()[0])):
				out.append([day, maxi(0, int(entry[1]))])
	while out.size() > KEEP:
		out.remove_at(0)
	return out


## The part of the log the chart shows: the last `days` days (0: all of it).
static func window(log: Array, days: int) -> Array:
	if days <= 0 or log.is_empty():
		return log.duplicate()
	var from := int(log.back()[0]) - days + 1
	return log.filter(func(p): return int(p[0]) >= from)


## A round number at or above `value`, for the top of the chart's scale: 1, 2, 2.5, 5 or 10 times a power of ten.
static func nice_top(value: int) -> int:
	if value <= 4:
		return 4
	var power := pow(10.0, floorf(log(float(value)) / log(10.0)))
	for step in [1.0, 2.0, 2.5, 4.0, 5.0, 10.0]:
		if power * step >= value:
			return int(power * step)
	return int(power * 10.0)


## A number short enough for an axis: 950, 1.2k, 3M.
static func compact(value: int) -> String:
	if value >= 1000000:
		return _trim(value / 1000000.0) + "M"
	if value >= 1000:
		return _trim(value / 1000.0) + "k"
	return str(value)


static func _trim(x: float) -> String:
	var s := "%.1f" % x
	return s.substr(0, s.length() - 2) if s.ends_with(".0") else s


## A number with a space between the thousands: 12 345.
static func grouped(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if value < 0 else "") + out
