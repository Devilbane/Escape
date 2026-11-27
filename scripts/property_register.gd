class_name PropertyRegister
extends RefCounted
## Everything a hero owns or rents, as the Crown clerk reads it out (see PlotOffice, PropertyWindow).
##
## The register is a list of sections (SECTIONS), each filled by one row builder (rows). A row is
## {"title", "detail", "tag"}: a short name, the line that describes it and a word for its kind.
## To add a new kind of property (a mine, a ship, a shop ...) give it
##  1. an entry in SECTIONS (key, German title, German text for "nothing yet"),
##  2. a row builder `_<key>_rows(hero, level)`, and an arm for it in `rows`,
##  3. its English texts in scripts/lang/property.gd.
## Plots of land and of mining ground already come from the deeds (see Plots.KINDS): a new deed
## kind needs only a section of its own.
##
## Rented property: the town house the village elder lends a newcomer on Weavers' Lane (see
## Homes) is given back once the hero has a home of their own: a plot, with a bed and a storage
## piece standing on it (see settled, leave_rental).

const SECTIONS := [
	{"key": "land", "title": "Grundstücke", "empty": "Noch kein Grundstück eingetragen."},
	{"key": "house", "title": "Häuser", "empty": "Noch kein Haus gebaut."},
	{"key": Plots.MINING, "title": "Schürfgründe", "empty": "Noch kein Schürfgrund in den Bergen."},
	{"key": "rented", "title": "Gemietet", "empty": "Nichts gemietet."},
]
## A map tile is 4 x 4 m, a cell of a house's grid 2 x 2 m.
const SQM_PER_TILE := 16
const SQM_PER_CELL := 4
## The German names of the compass points of Plots.COMPASS, for the names of areas.
const POINTS := {"n": "Norden", "ne": "Nordosten", "e": "Osten", "se": "Südosten", "s": "Süden", "sw": "Südwesten", "w": "Westen", "nw": "Nordwesten"}


## The rows of a section for a hero. `level` is the open-air map (it names areas that an old deed
## has no name for).
static func rows(section: String, hero: String, level: Level) -> Array:
	match section:
		"land":
			return _land_rows(hero, level, Plots.LAND)
		"house":
			return _house_rows(hero)
		Plots.MINING:
			return _land_rows(hero, level, Plots.MINING)
		"rented":
			return _rented_rows(hero)
	return []


## How many properties the hero has on record, over all sections.
static func count(hero: String, level: Level) -> int:
	var n := 0
	for section in SECTIONS:
		n += rows(section.key, hero, level).size()
	return n


## The name of an area, from its key (see Plots.area_of): "Meadows in the north".
static func area_name(area: String) -> String:
	var parts := area.split(":")
	var point: String = POINTS.get(parts[1] if parts.size() > 1 else "", "")
	if point == "":
		return Lang.t("Wiesen") if parts[0] != Plots.MINING else Lang.t("Berge")
	if parts[0] == Plots.MINING:
		return Lang.t("Berge im %s") % Lang.t(point)
	return Lang.t("Wiesen im %s") % Lang.t(point)


## Every deed of a kind with its area and number: a deed from before the numbers (area "", n 0) is
## named and numbered here by the order of the deeds.
static func numbered(hero: String, level: Level, kind: String) -> Array:
	var out: Array = []
	var taken := {}
	for d in Plots.plots_of(hero):
		if d.kind != kind:
			continue
		var area: String = d.area if d.area != "" else Plots.area_of(level, d.rect, kind)
		var n: int = d.n if d.n > 0 else int(taken.get(area, 0)) + 1
		taken[area] = maxi(int(taken.get(area, 0)), n)
		out.append({"rect": d.rect, "area": area, "n": n})
	return out


static func _land_rows(hero: String, level: Level, kind: String) -> Array:
	var out: Array = []
	var home := Plots.plot_of(hero)
	for d in numbered(hero, level, kind):
		var rect: Rect2i = d.rect
		var title := Lang.t("Grundstück %d") % d.n if kind == Plots.LAND else Lang.t("Schürfgrund %d") % d.n
		var tag := Lang.t("Freiland")
		if kind == Plots.LAND and rect == home:
			tag = Lang.t("Mit Haus")
		var detail := Lang.t("%s: %d x %d Felder, %d m²") % [area_name(d.area), rect.size.x, rect.size.y, rect.size.x * rect.size.y * SQM_PER_TILE]
		if kind == Plots.MINING and MineClaims.has_mine(rect):
			tag = Lang.t("Mit Mine")
			detail += ". " + MineClaims.summary(MineClaims.on_plot(rect))
		out.append({"title": title, "tag": tag, "detail": detail})
	return out


## The floor areas of a house, in square metres, as {"ground", "cellar", "roof"}: the built floor
## of the ground floor, the dug cellar and the flat roofs that can be walked on (a slab with no
## other roof built over it; a pitched roof is no ground to stand on). Only what is built counts.
static func house_areas(house: HouseSketch) -> Dictionary:
	var ground := 0
	var cellar := 0
	var roof := 0
	for key in house.pieces:
		var p: Dictionary = house.pieces[key]
		if p.state == HouseSketch.SKETCH:
			continue
		var parts := HouseSketch.parts_of(key)
		match p.kind:
			HouseSketch.COVER:
				ground += 1
			HouseSketch.DIG:
				cellar += 1
			HouseSketch.SLAB:
				var above: Dictionary = house.pieces.get(house.roof_key(parts[1], parts[2], parts[0] + 1), {})
				if above.is_empty() or above.state == HouseSketch.SKETCH:
					roof += 1
	return {"ground": ground * SQM_PER_CELL, "cellar": cellar * SQM_PER_CELL, "roof": roof * SQM_PER_CELL}


## Whether anything of the house is built.
static func has_house(house: HouseSketch) -> bool:
	for key in house.pieces:
		var p: Dictionary = house.pieces[key]
		if p.state != HouseSketch.SKETCH and p.kind in HouseSketch.HOUSE_WALLS + [HouseSketch.COVER, HouseSketch.DIG, HouseSketch.SLAB, HouseSketch.SADDLE, HouseSketch.STAIRS, HouseSketch.UPSTAIRS]:
			return true
	return false


static func _house_rows(hero: String) -> Array:
	var plot := Plots.plot_of(hero)
	if plot.size == Vector2i.ZERO:
		return []
	var house := HouseSketch.of(hero, plot)
	if not has_house(house):
		return []
	var areas := house_areas(house)
	return [{"title": Lang.t("Haus"), "tag": Lang.t("Überdacht"),
			"detail": Lang.t("Erdgeschoss %d m², Keller %d m², begehbares Dach %d m²") % [areas.ground, areas.cellar, areas.roof]}]


static func _rented_rows(hero: String) -> Array:
	var number := Homes.house_of(hero)
	if number <= 0:
		return []
	var lacking := missing(hero)
	var detail := Lang.t("Weberzeile. Du gibst es zurück, sobald du zu Hause bist.")
	if not lacking.is_empty():
		detail = Lang.t("Weberzeile. Du gibst es zurück, sobald du hast: %s.") % ", ".join(lacking)
	return [{"title": Lang.t("Haus Nr. %d") % number, "tag": Lang.t("Gemietet"), "detail": detail}]


# --- Giving up the rented house ---------------------------------------------------

## What a hero still lacks for a home of their own, in words: a plot, a bed and a storage piece standing on it.
static func missing(hero: String) -> Array:
	var lacking := []
	if not Plots.has_plot(hero):
		lacking.append(Lang.t("ein eigenes Grundstück"))
	var bed := false
	var store := false
	for p in HouseFurniture.of(hero).placed:
		var station: String = HouseFurniture.KINDS[p.kind].station
		bed = bed or station == "bett"
		store = store or station == "lager"
	if not bed:
		lacking.append(Lang.t("ein Bett"))
	if not store:
		lacking.append(Lang.t("ein Lagermöbel"))
	return lacking


## Whether the hero has a home of their own: their plot, with a bed and a storage piece set up.
static func settled(hero: String) -> bool:
	return missing(hero).is_empty()


## Gives the rented house back when the hero has a home of their own (see settled). Returns the
## number of the house given up, or 0. The hero's things stay theirs: the storage chest and the
## furniture belong to the hero, not to the house.
static func leave_rental(hero: String) -> int:
	var number := Homes.house_of(hero)
	if number <= 0 or not settled(hero):
		return 0
	Homes.release(number)
	Events.tell(Lang.t("Du hast ein eigenes Zuhause mit Bett und Lager. Haus Nr. %d in der Weberzeile gibst du zurück.") % number, Color(1.0, 0.8, 0.4), 6.0)
	return number
