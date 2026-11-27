class_name MineClaims
extends RefCounted
## The deed book of the hero's own mines (see MineWork for the rules): which mining plot (see Plots.MINING)
## carries a mine. Like the plots (see Plots) the mines are kept in Storage apart from the saved games, and only
## one mine can exist on a plot. A mine is opened over a prospecting mark (see Prospecting) that lies on the
## hero's own mining plot.

const RECORD := "mines"

static var _mines: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_mines = {}
	var parsed = Storage.read(RECORD)
	if parsed is Dictionary and parsed.get("mines", {}) is Dictionary:
		for key: String in parsed.mines:
			var m = parsed.mines[key]
			if m is Dictionary and m.has("shares") and m.has("rock"):
				_mines[key] = m


static func _save() -> void:
	Storage.write(RECORD, {"mines": _mines})


## Forgets what was read, so the next call reads the file again.
static func reload() -> void:
	_loaded = false


## The key a plot's mine is kept under: its corner tile.
static func key_of(rect: Rect2i) -> String:
	return "%d,%d" % [rect.position.x, rect.position.y]


## The mine on the plot `rect`, or an empty Dictionary.
static func on_plot(rect: Rect2i) -> Dictionary:
	_load()
	return _mines.get(key_of(rect), {})


static func has_mine(rect: Rect2i) -> bool:
	return not on_plot(rect).is_empty()


## The prospecting mark in `marks` that lies on the plot (or within the reach of its licence, see Prospecting), the best-looking one first, or an empty Dictionary.
static func mark_on(rect: Rect2i, marks: Array) -> Dictionary:
	var best := {}
	for m: Dictionary in marks:
		if not rect.grow(Prospecting.LICENCE_REACH).has_point(Vector2i(int(m.cell[0]), int(m.cell[1]))):
			continue
		if best.is_empty() or _rank(m) > _rank(best):
			best = m
	return best


static func _rank(m: Dictionary) -> int:
	var r: Dictionary = m.report
	if str(r.ore) == "":
		return 0
	return 1 + ["arm", "mittel", "reich"].find(str(r.richness)) + 1


## Why the hero cannot open a mine on `rect` with `marks`, or "": it has to be their own mining plot, free of a
## mine, with a prospecting mark on it that promises ore.
static func problem(hero: String, rect: Rect2i, marks: Array) -> String:
	var deed := _deed(hero, rect)
	if deed.is_empty():
		return "plot"
	if has_mine(rect):
		return "have"
	var m := mark_on(rect, marks)
	if m.is_empty():
		return "mark"
	if str(m.report.ore) == "":
		return "barren"
	return ""


static func _deed(hero: String, rect: Rect2i) -> Dictionary:
	for d: Dictionary in Plots.plots_of(hero):
		if d.kind == Plots.MINING and d.rect == rect:
			return d
	return {}


## Opens the mine and returns "" or the reason it is refused (see problem). `now` is the time of the founding.
static func open(hero: String, rect: Rect2i, marks: Array, now := 0.0) -> String:
	var why := problem(hero, rect, marks)
	if why != "":
		return why
	var mine := MineWork.found(key_of(rect), mark_on(rect, marks))
	mine["owner"] = Homes.deed_name(hero)
	mine["seen"] = now
	_mines[key_of(rect)] = mine
	_save()
	return ""


## Stores a mine after the hero worked on it.
static func update(rect: Rect2i, mine: Dictionary) -> void:
	_load()
	if _mines.has(key_of(rect)):
		_mines[key_of(rect)] = mine
		_save()


## Lets the hammer work while the hero was away: applies MineWork.catch_up for the hours since the mine was last
## seen. Returns the advances made.
static func catch_up(rect: Rect2i, now: float, rng: RandomNumberGenerator) -> int:
	var mine := on_plot(rect)
	if mine.is_empty():
		return 0
	var hours := maxf(0.0, now - float(mine.get("seen", now))) / 3600.0
	var made := MineWork.catch_up(mine, hours, rng)
	if made > 0:
		mine["seen"] = float(mine.get("seen", now)) + made * MineWork.OFFLINE_HOURS * 3600.0
		update(rect, mine)
	return made


## Closes the mines of a hero (for tests, and for a hero who gives up their plots).
static func release(hero: String) -> void:
	_load()
	hero = Homes.deed_name(hero)
	for key: String in _mines.keys():
		if str(_mines[key].get("owner", "")) == hero:
			_mines.erase(key)
	_save()


## One line about the mine for the property register.
static func summary(mine: Dictionary) -> String:
	return Lang.t("Stollen: %d Vortriebe, %d Stützen, Halde %d") % [int(mine.advances), int(mine.supports), roundi(float(mine.stock_mass))]
