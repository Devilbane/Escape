class_name MapView
extends Control
## Draws the hero's map of one level (see Journal): explored tiles in the
## colours of the ground, unexplored ones dark, numbered marks on the
## landmarks that have been seen, small diamonds where something was found,
## a backpack mark where the hero's bag or a backpack lies on the floor, the
## houses built on plots of the open map (see houses), and an arrow where the
## hero stands when it is the level they are on.
##
## The map zooms (see zoom_at): the mouse wheel zooms round the pointer, a drag
## moves the zoomed map, and the window's buttons and the + and - keys zoom round
## the middle. At the closest zoom one tile is MAX_TILE pixels wide.

const PAPER := Color(0.09, 0.07, 0.1)
const UNSEEN := Color(0.13, 0.11, 0.14)
const GRID_LINE := Color(0, 0, 0, 0.18)
## The colour of the backpack mark (also its dot in the map window's legend).
const PACK_COLOR := Color(0.95, 0.55, 0.15)

var journal: Journal
var file := ""
## Where the hero stands, in tiles (fractions allowed), and which way they
## look; no arrow when hero_at is Vector2.INF.
var hero_at := Vector2.INF
var hero_facing := Vector2.DOWN
## Landmarks drawn, in the order of their numbers (see numbered_places).
var _numbered: Array = []
var _font: Font
## The part of the map shown, in tiles: what has been explored, with a margin,
## so a small explored corner of a large map is not drawn tiny.
var _view := Rect2i()
## Tiles of margin around the explored part, and the smallest part shown.
const MARGIN := 2
const MIN_VIEW := Vector2i(16, 10)
## Zoom: 1.0 shows the explored part whole; every step in makes the tiles
## ZOOM_STEP times bigger, up to MAX_TILE pixels a tile (see max_zoom).
const ZOOM_STEP := 1.5
const MAX_TILE := 40.0
## Below this tile size a house shows as a mark; from it on, as its footprint.
const FOOTPRINT_TILE := 14.0
## The colours of houses: the hero's own, and other heroes' (see houses).
const HOUSE_COLOR := Color(1.0, 0.86, 0.45)
const OTHER_HOUSE_COLOR := Color(0.78, 0.8, 0.88)
const ROOF_COLOR := Color(0.66, 0.32, 0.24)
const FLOOR_COLOR := Color(0.62, 0.55, 0.45)
const WALL_COLOR := Color(0.2, 0.17, 0.17)
const DOOR_COLOR := Color(0.55, 0.36, 0.2)
const WINDOW_COLOR := Color(0.55, 0.75, 0.95)
const FENCE_COLOR := Color(0.42, 0.4, 0.38)
## A planned (not yet built) piece shows this faint.
const SKETCH_ALPHA := 0.35

## The floors of a map: GROUND, and on the open air DEEP, the forgotten mine under the woods
## (see LostMine), once the hero has been down there.
const GROUND := 0
const DEEP := -1
## The village's sewers (see Sewers), the lowest floor of the open air's map.
const SEWER := -2
## The colours of the sewers' cells by their letter (see Sewers).
const SEWER_COLORS := {"c": Color(0.2, 0.34, 0.3), "w": Color(0.5, 0.36, 0.28), "r": Color(0.46, 0.38, 0.32), "s": Color(0.66, 0.64, 0.6)}
## Which floor shows. On DEEP the ground above is drawn dim under the mine's tunnels, and
## only the mine's own marks show (see deep_places).
var storey := GROUND
## How much of its colour the ground keeps under the mine (see storey).
const GROUND_UNDER := 0.22
## The colours of the mine's cells by their letter (see LostMine.LAYOUT), and of their walls.
const DEEP_COLORS := {".": Color(0.6, 0.45, 0.28), "L": Color(0.6, 0.45, 0.28), "r": Color(0.52, 0.5, 0.48),
	"s": Color(0.66, 0.64, 0.6), "D": Color(0.66, 0.64, 0.6), "x": Color(0.3, 0.25, 0.21)}
const DEEP_WALL := Color(0.05, 0.04, 0.04)

## Emitted when the zoom or the part shown changes (see zoom_at, pan_by).
signal view_changed
## How far in the map is zoomed (1.0 = whole explored part), and the tile
## (fractions allowed) in the middle of the view; Vector2.INF is the middle
## of the explored part.
var zoom := 1.0
var center := Vector2.INF
var _dragging := false
## The houses on this map (see houses), worked out in setup.
var _houses: Array = []


## The floors of `level_file`'s map the hero knows, from the top down (see storey).
static func storeys(owner_journal: Journal, level_file: String) -> Array[int]:
	var out: Array[int] = [GROUND]
	if owner_journal.map_of(level_file).get("outdoor", false) and owner_journal.has_deep():
		out.append(DEEP)
	if owner_journal.map_of(level_file).get("outdoor", false) and owner_journal.has_sewer():
		out.append(SEWER)
	return out


## The German name of a floor (see storey).
static func storey_name(which: int) -> String:
	if which == SEWER:
		return "Kanalisation"
	return "Silbergrube" if which == DEEP else "Oberfläche"


## The floor the hero stands on (see storey).
static func hero_storey(hero: Vector3) -> int:
	if Sewers.holds(hero):
		return SEWER
	return DEEP if LostMine.holds(hero) else GROUND


func setup(owner_journal: Journal, level_file: String, font: Font) -> void:
	journal = owner_journal
	file = level_file
	_font = font
	_numbered = numbered_places()
	_view = _explored_bounds()
	_houses = houses()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_zoom(zoom)
	queue_redraw()


func _explored_bounds() -> Rect2i:
	var info := journal.map_of(file)
	if info.is_empty():
		return Rect2i()
	var lo := Vector2i(info.width, info.height)
	var hi := Vector2i(-1, -1)
	for y in info.height:
		for x in info.width:
			if journal.is_explored(file, Vector2i(x, y)):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var full := Rect2i(0, 0, info.width, info.height)
	if hi.x < 0:
		return full
	var r := Rect2i(lo, hi - lo + Vector2i.ONE).grow(MARGIN)
	# Not smaller than MIN_VIEW, growing round the middle.
	var extra := (MIN_VIEW - r.size).max(Vector2i.ZERO)
	r = r.grow_individual(extra.x / 2, extra.y / 2, extra.x - extra.x / 2, extra.y - extra.y / 2)
	return r.intersection(full)


## The landmarks seen on this map, numbered from 1 in reading order.
func numbered_places() -> Array:
	var out: Array = []
	for place in journal.places_on(file):
		if journal.is_seen(file, place):
			out.append(place)
	out.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## The size of one tile on screen when the whole explored part fits.
func fit_tile() -> float:
	if _view.size.x <= 0 or _view.size.y <= 0 or size.x <= 0 or size.y <= 0:
		return 1.0
	return minf(size.x / float(_view.size.x), size.y / float(_view.size.y))


## The size of one tile on screen at the current zoom.
func tile_size() -> float:
	return fit_tile() * zoom


## The closest zoom: one tile MAX_TILE pixels wide (never less than 1.0).
func max_zoom() -> float:
	return maxf(1.0, MAX_TILE / fit_tile())


func can_zoom_in() -> bool:
	return zoom < max_zoom() - 0.001


func can_zoom_out() -> bool:
	return zoom > 1.001


## The tile in the middle of the view, kept so the view never leaves the
## explored part (and centred on it along a side that fits whole).
func view_center() -> Vector2:
	var mid := Vector2(_view.position) + Vector2(_view.size) * 0.5
	var c := mid if center == Vector2.INF else center
	var t := tile_size()
	if t <= 0.0:
		return mid
	var half := size / t * 0.5
	for i in 2:
		var lo: float = _view.position[i] + half[i]
		var hi: float = _view.end[i] - half[i]
		c[i] = mid[i] if lo >= hi else clampf(c[i], lo, hi)
	return c


## Where tile (0, 0) of the map lands on screen.
func _origin(t: float) -> Vector2:
	return size * 0.5 - view_center() * t


## The map point (in tiles) under a point on screen, and back.
func tile_at(screen: Vector2) -> Vector2:
	var t := tile_size()
	return (screen - _origin(t)) / t


func screen_at(tile: Vector2) -> Vector2:
	var t := tile_size()
	return _origin(t) + tile * t


## Zooms `steps` steps in (negative: out), keeping the map point under
## `screen` where it is (the middle of the view when `screen` is INF).
func zoom_at(steps: float, screen := Vector2.INF) -> void:
	if screen == Vector2.INF:
		screen = size * 0.5
	var held := tile_at(screen)
	_set_zoom(zoom * pow(ZOOM_STEP, steps))
	# Put the held point back under the pointer.
	var t := tile_size()
	center = held - (screen - size * 0.5) / t
	center = view_center()
	view_changed.emit()
	queue_redraw()


## Back to the whole explored part.
func zoom_fit() -> void:
	_set_zoom(1.0)
	center = Vector2.INF
	view_changed.emit()
	queue_redraw()


## Moves the zoomed map by `screen` pixels (a drag).
func pan_by(screen: Vector2) -> void:
	center = view_center() - screen / tile_size()
	center = view_center()
	view_changed.emit()
	queue_redraw()


func _set_zoom(z: float) -> void:
	zoom = clampf(z, 1.0, max_zoom())
	# Close enough to an end counts as the end, so the buttons switch off.
	if zoom < 1.01:
		zoom = 1.0
	elif zoom > max_zoom() * 0.99:
		zoom = max_zoom()
	mouse_default_cursor_shape = Control.CURSOR_MOVE if zoom > 1.0 else Control.CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# The closest zoom depends on the size (see max_zoom).
		_set_zoom(zoom)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# The wheel zooms the map instead of scrolling the window.
			if b.pressed:
				var f := b.factor if b.factor > 0.0 else 1.0
				zoom_at(f if b.button_index == MOUSE_BUTTON_WHEEL_UP else -f, b.position)
			accept_event()
		elif b.button_index == MOUSE_BUTTON_LEFT:
			_dragging = b.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan_by((event as InputEventMouseMotion).relative)
		accept_event()


static func tile_color(ch: String, outdoor: bool) -> Color:
	if outdoor:
		match ch:
			"#": return Color(0.13, 0.25, 0.14)
			",", "P", "a", "Ξ", "Θ": return Color(0.7, 0.58, 0.38)
			"Ω", "Ψ": return Color(0.45, 0.45, 0.47)
			":", "F", "x", "l", "π": return Color(0.6, 0.58, 0.55)
			"~", ";", "≈": return Color(0.25, 0.45, 0.72)
			"‖": return Color(0.5, 0.36, 0.2)
			"q": return Color(0.45, 0.6, 0.75)
			"z": return Color(0.3, 0.27, 0.25)
			"g": return Color(0.48, 0.47, 0.45)
			"y", "p": return Color(0.62, 0.48, 0.25)
			"r", ">": return Color(0.5, 0.5, 0.5)
			"T", "d", "t": return Color(0.25, 0.42, 0.22)
			"N", "f", "C": return Color(0.5, 0.4, 0.3)
			"I": return Color(0.45, 0.4, 0.36)
			"i", "B", "L": return Color(0.66, 0.5, 0.32)
			"R", "E", "]", ")": return Color(0.38, 0.37, 0.4)
			"=": return Color(0.42, 0.41, 0.4)
			"'", "{", "}", "-", "/": return Color(0.58, 0.57, 0.53)
			"h", "^", "j", "n", "m", "u", "s", "k", "o", "w", "b", "[": return Color(0.58, 0.34, 0.24)
			_: return Color(0.4, 0.56, 0.3)
	match ch:
		"#", "?", "|": return Color(0.3, 0.27, 0.3)
		"S": return Color(0.66, 0.36, 0.3)
		",": return Color(0.6, 0.5, 0.38)
		"=": return Color(0.5, 0.5, 0.55)
		"F": return Color(0.45, 0.6, 0.75)
		"E": return Color(0.85, 0.7, 0.4)
		"D": return Color(0.6, 0.42, 0.25)
		"_": return Color(0.62, 0.6, 0.5)
		_: return Color(0.74, 0.68, 0.56)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var info := journal.map_of(file)
	if info.is_empty():
		return
	var t := tile_size()
	var o := _origin(t)
	var outdoor: bool = info.outdoor
	draw_rect(Rect2(o + Vector2(_view.position) * t, Vector2(_view.size) * t), UNSEEN)
	# Only the tiles on screen (most of a zoomed map is outside).
	var lo := Vector2i((-o / t).floor()).max(_view.position)
	var hi := Vector2i(((size - o) / t).ceil()).min(_view.end)
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var c := Vector2i(x, y)
			var ch := Journal.char_at(info, c)
			var known := journal.is_explored(file, c)
			if not known and ch == "#" and not outdoor:
				# A wall shows as soon as the floor beside it has been seen.
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					if Journal.char_at(info, c + d) != "#" and journal.is_explored(file, c + d):
						known = true
						break
			if not known:
				continue
			var color := tile_color(ch, outdoor)
			if ch == "?" and _secret_open(c):
				color = tile_color(".", false)
			if storey != GROUND:
				color = UNSEEN.lerp(color, GROUND_UNDER)
			draw_rect(Rect2(o + Vector2(x, y) * t, Vector2(t, t)), color)
	if t >= 10.0:
		for y in range(lo.y, hi.y + 1):
			draw_line(o + Vector2(lo.x, y) * t, o + Vector2(hi.x, y) * t, GRID_LINE)
		for x in range(lo.x, hi.x + 1):
			draw_line(o + Vector2(x, lo.y) * t, o + Vector2(x, hi.y) * t, GRID_LINE)
	var r := clampf(t * 0.55, 6.0, 11.0)
	if storey != GROUND:
		_draw_deep(o, t, r)
		_draw_hero(o, t, r)
		return
	_draw_houses(o, t, r)
	for s in journal.secrets.get(file, []):
		_draw_star(o + (Vector2(s[0], s[1]) + Vector2(0.5, 0.5)) * t, r, Journal.MARK_COLORS.secret)
	for f in journal.map_finds_on(file):
		var p := o + (Vector2(f.x, f.y) + Vector2(0.5, 0.5)) * t
		var k := r * 0.75
		var diamond := PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, 0), p + Vector2(0, k), p + Vector2(-k, 0)])
		draw_colored_polygon(diamond, Journal.find_color(f.kind))
		diamond.append(diamond[0])
		draw_polyline(diamond, Color(0, 0, 0, 0.8), 1.5)
	for i in _numbered.size():
		var place: Dictionary = _numbered[i]
		var p := o + (Vector2(place.x, place.y) + Vector2(0.5, 0.5)) * t
		draw_circle(p, r, Color(0, 0, 0, 0.75))
		draw_circle(p, r - 1.5, Journal.MARK_COLORS.get(place.kind, Color.WHITE))
		if _font:
			var label := str(i + 1)
			var fs := int(r * 1.2)
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(_font, p + Vector2(-w * 0.5, fs * 0.38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.03, 0.05))
	for c in journal.treasure_spots(file):
		_draw_cross(o + (Vector2(c) + Vector2(0.5, 0.5)) * t, r)
	var marks := journal.prospect_marks(file)
	for i in marks.size():
		var m: Dictionary = marks[i]
		_draw_prospect(o + (Vector2(int(m.cell[0]), int(m.cell[1])) + Vector2(0.5, 0.5)) * t, r,
				ProspectGeology.ORE_COLORS.get(str(m.report.ore), Color.GRAY), Prospecting.letter(i))
	for c in lost_packs():
		_draw_pack(o + (c + Vector2(0.5, 0.5)) * t, r)
	_draw_hero(o, t, r)


## The hero's arrow, where they stand on the floor shown.
func _draw_hero(o: Vector2, t: float, r: float) -> void:
	if hero_at != Vector2.INF:
		var p := o + (hero_at + Vector2(0.5, 0.5)) * t
		var fwd := hero_facing.normalized() if hero_facing.length() > 0.01 else Vector2.DOWN
		var side := Vector2(-fwd.y, fwd.x)
		var k := maxf(r * 1.2, 8.0)
		var arrow := PackedVector2Array([p + fwd * k, p - fwd * k * 0.6 + side * k * 0.7, p - fwd * k * 0.25, p - fwd * k * 0.6 - side * k * 0.7])
		draw_colored_polygon(arrow, Color(1.0, 0.82, 0.4))
		arrow.append(arrow[0])
		draw_polyline(arrow, Color(0.1, 0.05, 0.0), 2.0)


## Where a point of the world lies on the map, in tiles (as hero_at and the tiles are drawn).
static func _map_point(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z) / Level.TILE + Vector2(0.5, 0.5)


## The forgotten mine's floor: every cell the hero has seen, a dark line where it meets rock,
## and its marks (see deep_places).
func _draw_deep(o: Vector2, t: float, r: float) -> void:
	var cell := HouseSketch.CELL / Level.TILE * t
	var half := Vector3(HouseSketch.CELL, 0, HouseSketch.CELL) * 0.5
	var sewers := storey == SEWER
	var mine: Dictionary = Sewers.cells() if sewers else LostMine.cells()
	var colors: Dictionary = SEWER_COLORS if sewers else DEEP_COLORS
	var seen: Array[Vector2i] = []
	for c: Vector2i in mine:
		if (journal.is_sewer_seen(c) if sewers else journal.is_deep_seen(c)):
			seen.append(c)
	for c in seen:
		var at := o + _map_point(_floor_of(c) - half) * t
		draw_rect(Rect2(at, Vector2(cell, cell)), colors.get(mine[c], colors.get("w", DEEP_COLORS["."])) if sewers else colors.get(mine[c], colors["."]))
	var line := clampf(t * 0.08, 1.0, 3.0)
	for c in seen:
		var at := o + _map_point(_floor_of(c) - half) * t
		var corners := [at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)]
		for i in 4:
			var d: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][i]
			if not mine.has(c + d):
				draw_line(corners[i], corners[(i + 1) % 4], DEEP_WALL, line)
	var places := deep_places()
	for i in places.size():
		var p: Vector2 = o + places[i].at * t
		draw_circle(p, r, Color(0, 0, 0, 0.75))
		draw_circle(p, r - 1.5, places[i].color)
		if _font:
			var label := str(i + 1)
			var fs := int(r * 1.2)
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(_font, p + Vector2(-w * 0.5, fs * 0.38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.03, 0.05))


## The middle of a cell's floor on the floor shown (see storey).
func _floor_of(c: Vector2i) -> Vector3:
	return Sewers.floor_at(c) if storey == SEWER else LostMine.floor_at(c)


## The marks of the forgotten mine the hero has seen, numbered in this order: the ladder up to
## the hut, the sealed gate and the ore veins. Each {"kind", "name" (German), "at" (map tiles), "color"}.
func deep_places() -> Array:
	var out: Array = []
	if storey == SEWER:
		return _sewer_places()
	var marks: Array = [["stairs", "Leiter zur Steigerhütte", LostMine.SHAFT], ["lair", "Versiegeltes Tor", LostMine.GATE_CELL]]
	for v: Array in LostMine.VEINS:
		marks.append(["ore", "Erzader im Fels", v[0]])
	for m: Array in marks:
		if journal.is_deep_seen(m[2]):
			out.append({"kind": m[0], "name": m[1], "at": _map_point(LostMine.floor_at(m[2])),
				"color": Journal.MARK_COLORS.get(m[0], Journal.FIND_COLORS.get(m[0], Color.WHITE))})
	return out


## The marks of the sewers the hero has seen, numbered in this order: the ladders up to the street, the
## grating the stream comes in by, the outfall and (once found) Spooknortz' den. Each {"kind", "name"
## (German), "at" (map tiles), "color"}.
func _sewer_places() -> Array:
	var out: Array = []
	var marks: Array = []
	for h: Dictionary in Sewers.HATCHES:
		marks.append(["stairs", "Leiter zur Kanalluke", h.cell])
	marks.append(["sewer", "Gitter des Baches", Sewers.ROUTE[0]])
	marks.append(["sewer", "Auslauf der Kanalisation", Sewers.ROUTE[Sewers.ROUTE.size() - 1]])
	if Spooknortz.opened:
		marks.append(["lair", "Spooknortz' Höhle", Spooknortz.SPOT])
	for m: Array in marks:
		if journal.is_sewer_seen(m[2]):
			out.append({"kind": m[0], "name": m[1], "at": _map_point(Sewers.floor_at(m[2])),
				"color": Journal.MARK_COLORS.get(m[0], Color.WHITE)})
	return out


## Where a backpack lies on this level's floor, in tiles: the hero's bag
## dropped after a rescue (see Rescue) and a backpack set down on the floor
## (see FloorPack). The list is the game's saved floor list, so a pack that is
## picked up, emptied or swept away is gone from here at once.
func lost_packs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if journal == null or journal.game == null:
		return out
	for e in journal.game.floors.get(file, []):
		if FloorPack.is_pack(e) or (Rescue.is_bundle(e) and not Rescue.is_pouch(e)):
			out.append(Vector2(float(e[2]), float(e[3])) / Level.TILE)
	return out


## A small backpack: body, flap and straps, in a bright colour with a dark
## edge so it shows on every ground.
func _draw_pack(p: Vector2, r: float) -> void:
	if not Rect2(Vector2.ZERO, size).has_point(p):
		return
	var k := r * 1.15
	var body := Rect2(p + Vector2(-k * 0.8, -k * 0.55), Vector2(k * 1.6, k * 1.5))
	draw_rect(body.grow(1.5), Color(0, 0, 0, 0.85))
	draw_rect(body, PACK_COLOR)
	var flap := Rect2(p + Vector2(-k * 0.8, -k * 0.55), Vector2(k * 1.6, k * 0.55))
	draw_rect(flap, PACK_COLOR.darkened(0.3))
	var pocket := Rect2(p + Vector2(-k * 0.4, k * 0.25), Vector2(k * 0.8, k * 0.45))
	draw_rect(pocket, PACK_COLOR.darkened(0.2))
	draw_arc(p + Vector2(0, -k * 0.55), k * 0.4, PI, TAU, 10, Color(0, 0, 0, 0.85), 2.5)


func _secret_open(c: Vector2i) -> bool:
	for s in journal.secrets.get(file, []):
		if absi(s[0] - c.x) + absi(s[1] - c.y) <= 1:
			return true
	return false


## The red cross of a treasure map (see Journal.treasure_spots), with a dark
## edge so it shows on grass and forest alike.
func _draw_cross(p: Vector2, r: float) -> void:
	if not Rect2(Vector2.ZERO, size).has_point(p):
		return
	var k := r * 1.1
	for arm in [[Vector2(-k, -k), Vector2(k, k)], [Vector2(-k, k), Vector2(k, -k)]]:
		draw_line(p + arm[0], p + arm[1], Color(0, 0, 0, 0.85), 6.0)
	for arm in [[Vector2(-k, -k), Vector2(k, k)], [Vector2(-k, k), Vector2(k, -k)]]:
		draw_line(p + arm[0], p + arm[1], TreasureMaps.MAP_RED, 3.5)


## A prospector's mark: a stake with a pennant in the colour of the ore found, and its letter beside it
## (see Prospecting.letter, the legend names what it means).
func _draw_prospect(p: Vector2, r: float, color: Color, letter: String) -> void:
	if not Rect2(Vector2.ZERO, size).grow(r).has_point(p):
		return
	var k := r * 1.25
	var foot := p + Vector2(0, k * 0.8)
	var top := p + Vector2(0, -k * 1.1)
	draw_line(foot, top, Color(0, 0, 0, 0.9), 4.0)
	draw_line(foot, top, Color(0.78, 0.6, 0.36), 2.0)
	var flag := PackedVector2Array([top, top + Vector2(k * 1.1, k * 0.4), top + Vector2(0, k * 0.85)])
	draw_colored_polygon(flag, color)
	flag.append(flag[0])
	draw_polyline(flag, Color(0, 0, 0, 0.9), 1.6)
	if _font:
		var fs := int(maxf(r * 1.1, 11.0))
		var at := p + Vector2(k * 0.35, k * 1.25)
		draw_string_outline(_font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(_font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.8))


func _draw_star(p: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.8), 1.5)


# --- Houses ---------------------------------------------------------------------

## The plots and houses on this map (only the open map has plots, see Plots):
## one entry per plot, {"owner", "plot": Rect2i, "mine": bool, "built": bool,
## "cells": [[Rect2, kind, built]], "edges": [[from, to, kind, built]]}, with
## positions in map tiles. The hero's own plot always shows; another hero's
## once a tile of it has been explored. Read from the books each time the map
## is set up, so a house shows every piece built so far.
func houses() -> Array:
	var out: Array = []
	var info := journal.map_of(file)
	if info.is_empty() or not info.outdoor or info.building != "":
		return out
	var me := ""
	if journal.game != null:
		me = Homes.deed_name(str(journal.game.get("hero_name")))
	for deed in Plots.homes():
		var plot: Rect2i = deed.rect
		var mine: bool = deed.owner == me
		if not mine and not _any_explored(plot):
			continue
		var house := HouseSketch.of(deed.owner, plot)
		var entry := {"owner": deed.owner, "plot": plot, "mine": mine, "built": false, "cells": [], "edges": []}
		var per := float(HouseSketch.CELLS_PER_TILE)
		var corner := Vector2(plot.position)
		for key in house.pieces:
			var p: Dictionary = house.pieces[key]
			var parts := HouseSketch.parts_of(key)
			var built: bool = p.state != HouseSketch.SKETCH
			var at := corner + Vector2(parts[1], parts[2]) / per
			if p.kind in [HouseSketch.COVER, HouseSketch.SLAB, HouseSketch.SADDLE]:
				entry.cells.append([Rect2(at, Vector2.ONE / per), p.kind, built])
			elif parts[0] == 0 and (HouseSketch.HOUSE_WALLS.has(p.kind) or HouseSketch.FENCE_KINDS.has(p.kind)):
				var step := Vector2(1, 0) if parts[3] == HouseSketch.ORIENT_X else Vector2(0, 1)
				entry.edges.append([at, at + step / per, p.kind, built])
			else:
				continue
			if built:
				entry.built = true
		# Roofs over floors: a lower piece never covers a higher one.
		entry.cells.sort_custom(func(a, b): return _cell_rank(a[1]) < _cell_rank(b[1]))
		out.append(entry)
	return out


static func _cell_rank(kind: String) -> int:
	return [HouseSketch.COVER, HouseSketch.SLAB, HouseSketch.SADDLE].find(kind)


func _any_explored(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if journal.is_explored(file, Vector2i(x, y)):
				return true
	return false


## The hero's own house on this map (see houses), or {}.
func own_house() -> Dictionary:
	for h in _houses:
		if h.mine:
			return h
	return {}


## Whether another hero's house shows on this map.
func has_other_houses() -> bool:
	return _houses.any(func(h): return not h.mine and h.built)


## Every plot as a dashed outline; zoomed out, a built house is a house mark
## in the middle of what stands, zoomed in its footprint: roofs and floors,
## walls, doors and windows, garden walls; planned pieces faint.
func _draw_houses(o: Vector2, t: float, r: float) -> void:
	for h in _houses:
		var color: Color = HOUSE_COLOR if h.mine else OTHER_HOUSE_COLOR
		var plot: Rect2i = h.plot
		var a := o + Vector2(plot.position) * t
		var b := o + Vector2(plot.end) * t
		var dash := maxf(3.0, t * 0.25)
		for side in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
			draw_dashed_line(side[0], side[1], Color(0, 0, 0, 0.7), 3.5, dash)
			draw_dashed_line(side[0], side[1], color, 1.5, dash)
		if t >= FOOTPRINT_TILE:
			for c in h.cells:
				var fill: Color = ROOF_COLOR if c[1] == HouseSketch.SADDLE else FLOOR_COLOR
				if not c[2]:
					fill.a = SKETCH_ALPHA
				var rect := Rect2(o + c[0].position * t, c[0].size * t)
				draw_rect(rect, fill)
			var width := maxf(2.0, t * 0.1)
			for e in h.edges:
				var line: Color = _edge_color(e[2])
				var w := width * (0.6 if HouseSketch.FENCE_KINDS.has(e[2]) else 1.0)
				if not e[3]:
					line.a = SKETCH_ALPHA
				draw_line(o + e[0] * t, o + e[1] * t, line, w)
		elif h.built:
			_draw_house_mark(o + _house_middle(h) * t, r, color)


## The middle of what is built of a house, in map tiles.
func _house_middle(h: Dictionary) -> Vector2:
	var box := Rect2()
	var first := true
	for c in h.cells:
		if c[2]:
			box = c[0] if first else box.merge(c[0])
			first = false
	for e in h.edges:
		if e[3]:
			var seg := Rect2(e[0], Vector2.ZERO).expand(e[1])
			box = seg if first else box.merge(seg)
			first = false
	return box.get_center() if not first else Vector2(h.plot.get_center())


func _edge_color(kind: String) -> Color:
	match kind:
		HouseSketch.DOOR, HouseSketch.GATE:
			return DOOR_COLOR
		HouseSketch.WINDOW:
			return WINDOW_COLOR
		HouseSketch.STONE_FENCE, HouseSketch.WOOD_FENCE:
			return FENCE_COLOR
	return WALL_COLOR


## A small house: a roof on a body, with a dark edge so it shows on every
## ground (also the house's dot in the legend has its colour).
func _draw_house_mark(p: Vector2, r: float, color: Color) -> void:
	var k := r * 1.2
	var shape := PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, -k * 0.1), p + Vector2(k * 0.7, -k * 0.1),
			p + Vector2(k * 0.7, k * 0.8), p + Vector2(-k * 0.7, k * 0.8), p + Vector2(-k * 0.7, -k * 0.1), p + Vector2(-k, -k * 0.1)])
	draw_colored_polygon(shape, color)
	shape.append(shape[0])
	draw_polyline(shape, Color(0, 0, 0, 0.85), 2.0)
	draw_rect(Rect2(p + Vector2(-k * 0.2, k * 0.25), Vector2(k * 0.4, k * 0.55)), Color(0.2, 0.12, 0.08))
