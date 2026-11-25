class_name Plots
extends RefCounted
## Building plots: the land a hero marks out on the open map and registers at
## the Crown Office (see PlotOffice) before they may build a house on it.
##
## A plot is a rectangle of whole map tiles (4 x 4 m each) of bare grass. It
## has to be an even, free stretch: grass only (no path, tree, rock, building
## or water), outside the village wall and the village's own surroundings, and not
## overlapping a plot someone else has registered. The fee grows with the
## area, FEE_PER_TILE copper for every tile. A hero holds one plot.
##
## Like the bank's books and the town-house deeds (see Bank, Homes), the deeds
## are kept in Storage apart from the saved games, so a registered plot stays
## on the map for every hero who plays on this computer.

## The record in Storage.
const RECORD := "plots"
const MIN_SIDE := 2
const MAX_SIDE := 8
## Copper for every tile of the plot.
const FEE_PER_TILE := 30
## The ground a plot may cover: the map letter of bare grass.
const GRASS := "."

static var _deeds: Array = []
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_deeds = []
	var parsed = Storage.read(RECORD)
	if parsed is Dictionary and parsed.get("deeds", []) is Array:
		for d in parsed.deeds:
			if d is Dictionary and d.has("owner") and d.has("x") and d.has("y") and d.has("w") and d.has("h"):
				_deeds.append({"owner": str(d.owner), "x": int(d.x), "y": int(d.y), "w": int(d.w), "h": int(d.h)})


static func _save() -> void:
	Storage.write(RECORD, {"deeds": _deeds})


## Forgets what was read, so the next call reads the file again.
static func reload() -> void:
	_loaded = false


## The rectangle of tiles between two corner tiles, both included.
static func rect_between(a: Vector2i, b: Vector2i) -> Rect2i:
	var first := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var last := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(first, last - first + Vector2i.ONE)


static func fee(rect: Rect2i) -> int:
	return rect.size.x * rect.size.y * FEE_PER_TILE


## Every registered deed as {owner, rect}.
static func all() -> Array:
	_load()
	var out: Array = []
	for d in _deeds:
		out.append({"owner": d.owner, "rect": Rect2i(d.x, d.y, d.w, d.h)})
	return out


## The hero's plot, or an empty Rect2i (size zero) when they have none.
static func plot_of(hero: String) -> Rect2i:
	_load()
	hero = Homes.deed_name(hero)
	for d in _deeds:
		if d.owner == hero:
			return Rect2i(d.x, d.y, d.w, d.h)
	return Rect2i()


static func has_plot(hero: String) -> bool:
	return plot_of(hero).size != Vector2i.ZERO


## Who owns the plot that covers tile `c`, or "".
static func owner_at(c: Vector2i) -> String:
	_load()
	for d in _deeds:
		if Rect2i(d.x, d.y, d.w, d.h).has_point(c):
			return d.owner
	return ""


## Why `rect` cannot be a plot, or "" when it can. `level` is the open map.
static func problem(level: Level, rect: Rect2i) -> String:
	if rect.size.x < MIN_SIDE or rect.size.y < MIN_SIDE:
		return "small"
	if rect.size.x > MAX_SIDE or rect.size.y > MAX_SIDE:
		return "big"
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if level.cell_char(c) != GRASS or WoodLogs.lies_on(level, c):
				return "ground"
			if level is Outdoor and (level as Outdoor).near_village(c):
				return "village"
			if level is Outdoor and (level as Outdoor).has_leaf_tree(c):
				return "taken"
			if owner_at(c) != "" or LostMine.covers_tile(c) or BankVault.covers_tile(c) or Sewers.covers_tile(c):
				return "taken"
	return ""


## Registers `rect` for a hero and returns "" or the reason it was refused. The
## fee is the caller's business (see PlotOffice), so a refused deed costs nothing.
static func register(level: Level, hero: String, rect: Rect2i) -> String:
	if has_plot(hero):
		return "have"
	var why := problem(level, rect)
	if why != "":
		return why
	_load()
	_deeds.append({"owner": Homes.deed_name(hero), "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y})
	_save()
	return ""


## Gives a plot back (for tests, and for a hero who moves away).
static func release(hero: String) -> void:
	_load()
	hero = Homes.deed_name(hero)
	for i in range(_deeds.size() - 1, -1, -1):
		if _deeds[i].owner == hero:
			_deeds.remove_at(i)
	_save()
