class_name Journal
extends RefCounted
## The hero's map and exploration journal. The map of every level fills in
## as the hero explores it: in the dungeon whatever the fog of war has shown
## (see Fog), in the open air everything within REVEAL_RADIUS tiles of the
## hero. Landmarks (stairs, shrines, fountains, the village buildings, the
## dragon's lair...) are marked on the map once they have been seen, and
## every spot where the hero found something (see note_find) gets a mark of
## its own. The journal keeps a dated line for every new place, landmark and
## find. Everything is kept in the hero's saved game (see Game).
##
## Other features record their finds with Game.note_find(kind, id, name,
## pos), e.g. note_find("ingredient", "mondsilbererz", "Mondsilbererz", pos) when an
## ingredient is picked or note_find("fish", ...) when a fish is caught. The
## spots of one thing are listed by spots_of(id), so a recipe or ingredient
## book can show where it was found without keeping its own list.

## How far the hero sees in the open air, in tiles (4 m each).
const REVEAL_RADIUS := 6
## How often the map is brought up to date, in seconds.
const UPDATE_EVERY := 0.25
## The journal keeps this many lines; the oldest go first.
const MAX_LOG := 300
## Two finds of the same thing closer than this (tiles) share one spot.
const SAME_SPOT := 1.5
## A map counts as fully explored once this share of the tiles that count
## (see Level.explore_cells) has been seen. A few dark corners may stay.
const FULL_SHARE := 0.95
## How many map updates pass between two checks of how much has been seen.
const FULL_CHECK_EVERY := 8

## Landmarks in the dungeon and on the floors of buildings, by map character:
## [kind, German name].
const DUNGEON_MARKS := {
	"E": ["stairs", "Treppe"], "D": ["door", "Tür"], "H": ["shrine", "Schrein"],
	"F": ["fountain", "Brunnen"], "V": ["merchant", "Händler"], "B": ["bed", "Bett"],
	"L": ["storage", "Vorratstruhe"],
}
## Landmarks in the open air. A building or a pond covering several tiles is
## one landmark, marked in its middle.
const OUTDOOR_MARKS := {
	"R": ["crypt", "Gruft"], "E": ["lair", "Drachenhöhle"],
	"j": ["building", "Schmiede"], "n": ["building", "Wirtshaus"], "m": ["building", "Kramladen"],
	"u": ["building", "Windmühle"], "s": ["building", "Tempel"], "k": ["building", "Amt der Krone"],
	"o": ["building", "Post"], "w": ["building", "Abenteurergilde"], "b": ["building", "Bank der Krone"],
	"^": ["home", "Weberzeile"], ";": ["water", "Teich"], "F": ["fountain", "Marktbrunnen"], "q": ["fountain", "Ziehbrunnen"],
	"~": ["water", "Teich"], "f": ["camp", "Räuberlager"], "v": ["food", "Futterkorb"],
	"S": ["building", "Steinmetz"], "[": ["building", "Bergschenke"], "]": ["lair", "Mine"],
	")": ["lair", "Hort des Großen Alten"],
}
## Whole areas of the open air, marked in the middle of all their tiles:
## [characters, German name].
const OUTDOOR_AREAS := [["g", "Friedhof"], ["WHJU", "Wolfssenke"], ["cAX", "Räuberpass"], ["{}-/", "Schartenpass"]]
## Colours of the marks by kind of landmark, and of the finds by kind.
const MARK_COLORS := {
	"stairs": Color(1.0, 0.82, 0.4), "door": Color(0.75, 0.55, 0.35), "shrine": Color(0.75, 0.6, 1.0),
	"fountain": Color(0.45, 0.75, 1.0), "water": Color(0.45, 0.75, 1.0), "merchant": Color(1.0, 0.7, 0.3),
	"bed": Color(0.55, 0.9, 0.55), "home": Color(0.55, 0.9, 0.55), "storage": Color(0.85, 0.7, 0.45),
	"crypt": Color(0.7, 0.7, 0.75), "lair": Color(1.0, 0.4, 0.3), "building": Color(0.95, 0.85, 0.6),
	"camp": Color(1.0, 0.45, 0.35), "food": Color(0.95, 0.75, 0.35), "area": Color(0.85, 0.85, 0.85),
	"secret": Color(1.0, 0.82, 0.4),
}
const FIND_COLORS := {
	"ingredient": Color(0.45, 0.95, 0.45), "fish": Color(0.45, 0.8, 1.0), "ore": Color(0.8, 0.8, 0.85),
}
const FIND_COLOR := Color(0.95, 0.6, 0.95)

var game: Node
## The explored tiles per level file: one byte per tile, 1 = seen.
var explored := {}
## The landmarks seen per level file: place id -> true.
var seen := {}
## Spots where something was found: {"kind", "id", "name", "file", "x", "y",
## "count"}, in the order they were first found.
var finds: Array = []
## Journal lines, oldest first: {"day", "hour", "file", "t" (German text with
## %s), "a" (its arguments, German, translated when shown)}.
var entries: Array = []
## Secret rooms opened per level file: list of [x, y].
var secrets := {}
## The level files the hero has explored fully: file -> true. Each one
## trains the Erkunden skill once (see note_full_map).
var full := {}
var _timer := 0.0
var _full_check := 0
## Map data read from the level files: file -> {"grid", "width", "height",
## "name", "outdoor", "building", "path"}.
var _maps := {}
## Landmarks per level file, worked out from its map (see places_on).
var _places := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	explored.clear()
	seen.clear()
	finds.clear()
	entries.clear()
	secrets.clear()
	full.clear()


# --- Reading the maps ---------------------------------------------------------

## The map of a level file (its name, e.g. "03_das_labyrinth.txt"), read
## once: the furniture is moved out of the passages the same way the level
## does it when it is built (see Level._clear_passages), so the marks sit
## where the things really stand.
func map_of(file: String) -> Dictionary:
	if _maps.has(file):
		return _maps[file]
	var path := _path_of(file)
	if path == "":
		return {}
	var l := Level.new()
	l.load_from_file(path)
	if not l.outdoor:
		l._clear_passages()
	var info := {"grid": l.grid.duplicate(), "width": l.width, "height": l.height, "name": l.level_name,
		"outdoor": l.outdoor, "building": l.building, "path": path, "cells": l.explore_cells()}
	l._walls_body.free()
	l.free()
	_maps[file] = info
	return info


func _path_of(file: String) -> String:
	if game == null:
		return ""
	for path in game.level_files:
		if path.get_file() == file:
			return path
	return ""


## The name of a level as the player knows it: "Level 3: The Labyrinth" for a
## level of the dungeon, just the name in the open air and in buildings.
func level_title(file: String) -> String:
	var info := map_of(file)
	if info.is_empty():
		return file
	if info.outdoor or info.building != "":
		return Lang.t(info.name)
	return Lang.t("Ebene %d: %s") % [game.level_files.find(info.path) + 1, Lang.t(info.name)]


static func char_at(info: Dictionary, c: Vector2i) -> String:
	var grid: Array = info.grid
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= (grid[c.y] as String).length():
		return "#"
	var ch: String = grid[c.y][c.x]
	return "#" if ch == " " else ch


## Every landmark of a level file: {"id", "kind", "name", "cells", "x", "y"}
## where x and y is the tile the mark sits on.
func places_on(file: String) -> Array:
	if _places.has(file):
		return _places[file]
	var info := map_of(file)
	var out: Array = []
	if info.is_empty():
		return out
	var marks: Dictionary = OUTDOOR_MARKS if info.outdoor else DUNGEON_MARKS
	var taken := {}
	for y in info.height:
		for x in info.width:
			var c := Vector2i(x, y)
			var ch := char_at(info, c)
			if not marks.has(ch) or taken.has(c):
				continue
			# A building or a pond: all tiles of the same character together.
			var cells: Array[Vector2i] = [c]
			taken[c] = true
			var i := 0
			while i < cells.size():
				for d in Level.DIRS:
					var n: Vector2i = cells[i] + d
					if not taken.has(n) and char_at(info, n) == ch:
						taken[n] = true
						cells.append(n)
				i += 1
			out.append(_place("%s:%d:%d" % [ch, c.x, c.y], marks[ch][0], marks[ch][1], cells))
	if info.outdoor:
		for area in OUTDOOR_AREAS:
			var cells: Array[Vector2i] = []
			for y in info.height:
				for x in info.width:
					if (area[0] as String).contains(char_at(info, Vector2i(x, y))):
						cells.append(Vector2i(x, y))
			if not cells.is_empty():
				# An area counts as seen once its middle has been seen.
				var place := _place("area:" + area[0], "area", area[1], cells)
				place.cells = [Vector2i(place.x, place.y)]
				out.append(place)
	_places[file] = out
	return out


func _place(id: String, kind: String, name: String, cells: Array[Vector2i]) -> Dictionary:
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	var mid := Vector2i((sum / cells.size()).round())
	return {"id": id, "kind": kind, "name": name, "cells": cells, "x": mid.x, "y": mid.y}


## The name of a landmark in the chosen language.
func place_name(place: Dictionary) -> String:
	return Lang.t(place.name)


# --- Exploring ------------------------------------------------------------------

func is_explored(file: String, c: Vector2i) -> bool:
	var info := map_of(file)
	if not explored.has(file) or info.is_empty():
		return false
	if c.x < 0 or c.y < 0 or c.x >= info.width or c.y >= info.height:
		return false
	return (explored[file] as PackedByteArray)[c.y * info.width + c.x] != 0


func has_map(file: String) -> bool:
	return explored.has(file)


## The level files the hero has a map of, in the order of the game.
func mapped_files() -> Array[String]:
	var out: Array[String] = []
	if game == null:
		return out
	for path in game.level_files:
		if explored.has(path.get_file()):
			out.append(path.get_file())
	return out


func _cells_of(file: String) -> PackedByteArray:
	var info := map_of(file)
	var n: int = info.width * info.height
	if not explored.has(file) or (explored[file] as PackedByteArray).size() != n:
		var bytes := PackedByteArray()
		bytes.resize(n)
		explored[file] = bytes
	return explored[file]


## Brings the map of the level the hero is on up to date. Called every frame
## by the game; does its work a few times a second.
func update(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_EVERY
	var level: Level = game.level
	if level == null or game.player == null:
		return
	var file := current_file()
	if map_of(file).is_empty():
		return
	if not explored.has(file):
		write("Betreten: %s", ["@" + file], file)
	reveal(file, level)
	_discover(file)
	_full_check += 1
	if _full_check >= FULL_CHECK_EVERY:
		_full_check = 0
		note_full_map(file)


func current_file() -> String:
	return game.level_files[game.level_index].get_file()


## Brings the map of the current level up to date at once, e.g. just before
## the game is saved, so nothing seen in the last moment is lost.
func catch_up() -> void:
	if game == null or game.level == null or game.player == null:
		return
	var file := current_file()
	if not map_of(file).is_empty():
		reveal(file, game.level)


## Gives the fog of war of a freshly built level what the hero has already
## seen of it (on an earlier visit or in the saved game), so explored tiles
## stay grey instead of turning black again.
func restore_fog(level: Level) -> void:
	if level == null or level.fog == null:
		return
	var file := current_file()
	if map_of(file).is_empty() or not explored.has(file):
		return
	level.fog.remember(_cells_of(file))


## Marks what the hero sees now as explored.
func reveal(file: String, level: Level) -> void:
	var info := map_of(file)
	var bytes := _cells_of(file)
	var w: int = info.width
	var h: int = info.height
	if level.fog != null:
		var seen_now: PackedFloat32Array = level.fog.explored_cells()
		for i in mini(seen_now.size(), bytes.size()):
			if seen_now[i] > 0.5:
				bytes[i] = 1
	else:
		var here := level.world_to_cell(game.player.global_position)
		for y in range(maxi(0, here.y - REVEAL_RADIUS), mini(h, here.y + REVEAL_RADIUS + 1)):
			for x in range(maxi(0, here.x - REVEAL_RADIUS), mini(w, here.x + REVEAL_RADIUS + 1)):
				if Vector2(x - here.x, y - here.y).length() <= REVEAL_RADIUS + 0.5:
					bytes[y * w + x] = 1
	explored[file] = bytes


## Landmarks that have just come into view go on the map and into the journal.
func _discover(file: String) -> void:
	if not seen.has(file):
		seen[file] = {}
	var known: Dictionary = seen[file]
	var fresh: Array[String] = []
	for place in places_on(file):
		if known.has(place.id):
			continue
		var spotted := false
		for c in place.cells:
			if is_explored(file, c):
				spotted = true
				break
			for d in Level.DIRS:
				if is_explored(file, c + d) and place.kind != "area":
					spotted = true
					break
			if spotted:
				break
		if spotted:
			known[place.id] = true
			# Doors are many and plain: on the map, not in the journal.
			if place.kind != "door":
				write("Entdeckt: %s", [place.name], file)
				fresh.append(place_name(place))
	if not fresh.is_empty():
		Events.bus().map_grew.emit(fresh)


func is_seen(file: String, place: Dictionary) -> bool:
	return seen.has(file) and (seen[file] as Dictionary).has(place.id)


## How much of a level the hero has seen, 0..1: the share of the tiles that
## count (see Level.explore_cells), the ground one can stand on.
func explored_share(file: String) -> float:
	var info := map_of(file)
	if info.is_empty() or info.cells.is_empty():
		return 0.0
	var cells: Array = info.cells
	var bytes := _cells_of(file)
	var w: int = info.width
	var seen_count := 0
	for c in cells:
		if bytes[c.y * w + c.x] != 0:
			seen_count += 1
	return float(seen_count) / cells.size()


## Once the hero has seen (nearly) all of a map, it goes into the journal and
## the game hears of it on the bus (map_explored), once per map.
func note_full_map(file: String) -> void:
	if full.has(file) or explored_share(file) < FULL_SHARE:
		return
	full[file] = true
	write("Vollständig erkundet", [], file)
	Events.bus().map_explored.emit(file)


func is_full(file: String) -> bool:
	return full.has(file)


## A secret room was opened: marked on the map behind its wall.
func note_secret(file: String, cell: Vector2i) -> void:
	if not secrets.has(file):
		secrets[file] = []
	for s in secrets[file]:
		if s[0] == cell.x and s[1] == cell.y:
			return
	secrets[file].append([cell.x, cell.y])
	write("Geheimraum entdeckt", [], file)


# --- Finds ----------------------------------------------------------------------

## Records that the hero found something at tile `cell` of a level file:
## kind is e.g. "ingredient" or "fish", id the item id, name its German name.
## A find close to an earlier one of the same thing counts on that spot.
## Returns true when the spot is new (it then also goes into the journal).
func note_find(kind: String, id: String, name: String, file: String, cell: Vector2i) -> bool:
	for f in finds:
		if f.id == id and f.kind == kind and f.file == file and Vector2(f.x - cell.x, f.y - cell.y).length() < SAME_SPOT:
			f.count = int(f.count) + 1
			return false
	finds.append({"kind": kind, "id": id, "name": name, "file": file, "x": cell.x, "y": cell.y, "count": 1})
	write("Gefunden: %s", [name], file)
	return true


## Every spot on every map where the thing with this id was found.
func spots_of(id: String) -> Array:
	return finds.filter(func(f): return f.id == id)


func finds_on(file: String) -> Array:
	return finds.filter(func(f): return f.file == file)


static func find_color(kind: String) -> Color:
	return FIND_COLORS.get(kind, FIND_COLOR)


# --- The journal ----------------------------------------------------------------

func write(text: String, args: Array, file: String) -> void:
	var hour: float = game.day_hour if game != null else 8.0
	entries.append({"day": day(), "hour": hour, "file": file, "t": text, "a": args})
	while entries.size() > MAX_LOG:
		entries.pop_front()


## A journal line as it is shown: "Day 2, 14:00 · Level 3: The Labyrinth" and
## what happened.
func entry_text(e: Dictionary) -> Array[String]:
	var args := []
	for a in e.a:
		var s := str(a)
		args.append(level_title(s.substr(1)) if s.begins_with("@") else Lang.t(s))
	var what: String = Lang.t(e.t)
	if not args.is_empty():
		what = what % args
	var when: String = Lang.t("Tag %d, %s") % [int(e.day), DayNight.clock_text(float(e.hour))]
	return [when + "  ·  " + level_title(str(e.file)), what]


## The day of the journey, counted from 1: the game's own day, which turns at
## dawn (see Game.day).
func day() -> int:
	return (int(game.day) if game != null else 0) + 1


# --- Saved game -----------------------------------------------------------------

func for_save() -> Dictionary:
	var maps := {}
	for file in explored:
		maps[file] = _pack(explored[file])
	var known := {}
	for file in seen:
		known[file] = (seen[file] as Dictionary).keys()
	return {"maps": maps, "seen": known, "finds": finds, "log": entries, "secrets": secrets, "full": full.keys()}


func load_from(data) -> void:
	clear()
	if not data is Dictionary:
		return
	var maps = data.get("maps", {})
	if maps is Dictionary:
		for file in maps:
			var info := map_of(str(file))
			if info.is_empty():
				continue
			var bytes := _unpack(str(maps[file]), info.width * info.height)
			if not bytes.is_empty():
				explored[str(file)] = bytes
	var known = data.get("seen", {})
	if known is Dictionary:
		for file in known:
			var ids := {}
			if known[file] is Array:
				for id in known[file]:
					ids[str(id)] = true
			seen[str(file)] = ids
	var saved_finds = data.get("finds", [])
	if saved_finds is Array:
		for f in saved_finds:
			if f is Dictionary and f.has("id") and f.has("file"):
				finds.append({"kind": str(f.get("kind", "")), "id": str(f.id), "name": str(f.get("name", f.id)),
					"file": str(f.file), "x": int(f.get("x", 0)), "y": int(f.get("y", 0)), "count": int(f.get("count", 1))})
	var saved_log = data.get("log", [])
	if saved_log is Array:
		for e in saved_log:
			if e is Dictionary and e.has("t"):
				entries.append({"day": int(e.get("day", 1)), "hour": float(e.get("hour", 8.0)), "file": str(e.get("file", "")),
					"t": str(e.t), "a": e.get("a", []) if e.get("a", []) is Array else []})
	var saved_secrets = data.get("secrets", {})
	if saved_secrets is Dictionary:
		for file in saved_secrets:
			if saved_secrets[file] is Array:
				secrets[str(file)] = (saved_secrets[file] as Array).filter(func(s): return s is Array and s.size() == 2)
	var saved_full = data.get("full", [])
	if saved_full is Array:
		for file in saved_full:
			full[str(file)] = true


## Eight tiles to a byte, as text.
static func _pack(bytes: PackedByteArray) -> String:
	var bits := PackedByteArray()
	bits.resize((bytes.size() + 7) / 8)
	for i in bytes.size():
		if bytes[i] != 0:
			bits[i / 8] |= 1 << (i % 8)
	return Marshalls.raw_to_base64(bits)


static func _unpack(text: String, n: int) -> PackedByteArray:
	var bits := Marshalls.base64_to_raw(text)
	var bytes := PackedByteArray()
	if bits.size() != (n + 7) / 8:
		return bytes
	bytes.resize(n)
	for i in n:
		if bits[i / 8] & (1 << (i % 8)):
			bytes[i] = 1
	return bytes
