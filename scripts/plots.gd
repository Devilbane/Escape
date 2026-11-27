class_name Plots
extends RefCounted
## Building plots: the land a hero marks out on the open map and registers at
## the Crown Office (see PlotOffice) before they may build a house on it.
##
## A plot is a rectangle of whole map tiles (4 x 4 m each) of bare grass. It
## has to be an even, free stretch: grass only (no path, tree, rock, building
## or water), outside the village wall and the village's own surroundings, and not
## overlapping a plot someone else has registered. The fee grows with the
## area, FEE_PER_TILE copper for every tile. A hero may hold several plots (up to
## MAX_PER_HERO); the first land plot is the one the house stands on (see plot_of and
## homes), the others stay open ground. Every plot carries the area it lies in and a
## number within that area (see area_of and PropertyRegister), so "Plot 1" and
## "Plot 2" of one hero in the same area stay apart for good.
##
## Like the bank's books and the town-house deeds (see Bank, Homes), the deeds
## are kept in Storage apart from the saved games, so a registered plot stays
## on the map for every hero who plays on this computer.

## The record in Storage.
const RECORD := "plots"
## What a deed is for: building land on the meadows, or a mining plot on the scree of the mountains.
const LAND := "land"
const MINING := "mining"
const KINDS := [LAND, MINING]
## How many plots one hero may own in all.
const MAX_PER_HERO := 12
## The ground a mining plot covers: the map letter of scree, the stony mountain ground.
const SCREE := "'"
## The eight points of the compass an area is named by, clockwise from the north (see area_of).
const COMPASS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
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
				var kind := str(d.get("kind", LAND))
				_deeds.append({"owner": str(d.owner), "x": int(d.x), "y": int(d.y), "w": int(d.w), "h": int(d.h),
						"kind": kind if KINDS.has(kind) else LAND, "area": str(d.get("area", "")), "n": maxi(0, int(d.get("n", 0)))})


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


static func _deed(d: Dictionary) -> Dictionary:
	return {"owner": d.owner, "rect": Rect2i(d.x, d.y, d.w, d.h), "kind": d.kind, "area": d.area, "n": d.n}


## Every registered deed as {owner, rect, kind, area, n}: the plot's kind (LAND or MINING), the
## key of the area it lies in and its number there (area "" and n 0 for a deed from before).
static func all() -> Array:
	_load()
	var out: Array = []
	for d in _deeds:
		out.append(_deed(d))
	return out


## The deeds that carry a house: every hero's first plot of building land (the others are open
## ground). The house sketches (see HouseSketch.of) are kept per hero, so these are the only places
## one may be read for.
static func homes() -> Array:
	_load()
	var out: Array = []
	var seen := {}
	for d in _deeds:
		if d.kind == LAND and not seen.has(d.owner):
			seen[d.owner] = true
			out.append(_deed(d))
	return out


## Every deed of a hero, in the order they were registered.
static func plots_of(hero: String) -> Array:
	_load()
	hero = Homes.deed_name(hero)
	var out: Array = []
	for d in _deeds:
		if d.owner == hero:
			out.append(_deed(d))
	return out


## The hero's first plot of building land, the one their house stands on, or an empty Rect2i (size
## zero) when they have none.
static func plot_of(hero: String) -> Rect2i:
	_load()
	hero = Homes.deed_name(hero)
	for d in _deeds:
		if d.owner == hero and d.kind == LAND:
			return Rect2i(d.x, d.y, d.w, d.h)
	return Rect2i()


static func has_plot(hero: String) -> bool:
	return plot_of(hero).size != Vector2i.ZERO


## Whether the hero holds as many plots as the Crown allows.
static func at_limit(hero: String) -> bool:
	return plots_of(hero).size() >= MAX_PER_HERO


## The key of the area a plot lies in, "<kind>:<point of the compass>": the way from the middle of
## the village to the plot's middle. On a map that is no open-air map there is no village to
## measure from, and every plot lies in the one area "<kind>:".
static func area_of(level: Level, rect: Rect2i, kind := LAND) -> String:
	if not level is Outdoor:
		return kind + ":"
	var way := Vector2(rect.position) + Vector2(rect.size) * 0.5 - (level as Outdoor).village_centre()
	if way.length() < 1.0:
		return kind + ":" + COMPASS[0]
	var step := roundi(atan2(way.x, -way.y) / (TAU / COMPASS.size()))
	return kind + ":" + COMPASS[posmod(step, COMPASS.size())]


## The number the hero's next plot of `area` gets: one after their highest there.
static func next_number(hero: String, area: String) -> int:
	var highest := 0
	for d in plots_of(hero):
		if d.area == area:
			highest = maxi(highest, d.n)
	return highest + 1


## Who owns the plot that covers tile `c`, or "".
static func owner_at(c: Vector2i) -> String:
	_load()
	for d in _deeds:
		if Rect2i(d.x, d.y, d.w, d.h).has_point(c):
			return d.owner
	return ""


## Why `rect` cannot be a plot, or "" when it can. `level` is the open map.
static func problem(level: Level, rect: Rect2i, kind := LAND) -> String:
	if rect.size.x < MIN_SIDE or rect.size.y < MIN_SIDE:
		return "small"
	if rect.size.x > MAX_SIDE or rect.size.y > MAX_SIDE:
		return "big"
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if level.cell_char(c) != (SCREE if kind == MINING else GRASS) or WoodLogs.lies_on(level, c):
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
static func register(level: Level, hero: String, rect: Rect2i, kind := LAND) -> String:
	if at_limit(hero):
		return "have"
	var why := problem(level, rect, kind)
	if why != "":
		return why
	_load()
	var area := area_of(level, rect, kind)
	_deeds.append({"owner": Homes.deed_name(hero), "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y,
			"kind": kind, "area": area, "n": next_number(hero, area)})
	_save()
	return ""


## Gives all of a hero's plots back (for tests, and for a hero who moves away).
static func release(hero: String) -> void:
	_load()
	hero = Homes.deed_name(hero)
	for i in range(_deeds.size() - 1, -1, -1):
		if _deeds[i].owner == hero:
			_deeds.remove_at(i)
	_save()
