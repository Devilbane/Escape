class_name MapView
extends Control
## Draws the hero's map of one level (see Journal): explored tiles in the
## colours of the ground, unexplored ones dark, numbered marks on the
## landmarks that have been seen, small diamonds where something was found,
## and an arrow where the hero stands when it is the level they are on.

const PAPER := Color(0.09, 0.07, 0.1)
const UNSEEN := Color(0.13, 0.11, 0.14)
const GRID_LINE := Color(0, 0, 0, 0.18)

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


func setup(owner_journal: Journal, level_file: String, font: Font) -> void:
	journal = owner_journal
	file = level_file
	_font = font
	_numbered = numbered_places()
	_view = _explored_bounds()
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


## The size of one tile on screen, so the whole map fits.
func tile_size() -> float:
	if _view.size.x <= 0 or _view.size.y <= 0:
		return 1.0
	return minf(size.x / float(_view.size.x), size.y / float(_view.size.y))


## Where tile (0, 0) of the map lands on screen.
func _origin(t: float) -> Vector2:
	return (size - Vector2(_view.size) * t) * 0.5 - Vector2(_view.position) * t


static func tile_color(ch: String, outdoor: bool) -> Color:
	if outdoor:
		match ch:
			"#": return Color(0.13, 0.25, 0.14)
			",", "P", "a": return Color(0.7, 0.58, 0.38)
			":", "F", "x", "l": return Color(0.6, 0.58, 0.55)
			"~": return Color(0.25, 0.45, 0.72)
			"q": return Color(0.45, 0.6, 0.75)
			"z": return Color(0.3, 0.27, 0.25)
			"g": return Color(0.48, 0.47, 0.45)
			"y", "p": return Color(0.62, 0.48, 0.25)
			"r": return Color(0.5, 0.5, 0.5)
			"T", "d", "t": return Color(0.25, 0.42, 0.22)
			"N", "f", "C": return Color(0.5, 0.4, 0.3)
			"I": return Color(0.45, 0.4, 0.36)
			"i", "B", "L": return Color(0.66, 0.5, 0.32)
			"R", "E": return Color(0.38, 0.37, 0.4)
			"h", "j", "n", "m", "u", "s", "k", "o", "w", "b": return Color(0.58, 0.34, 0.24)
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
	for y in range(_view.position.y, _view.end.y):
		for x in range(_view.position.x, _view.end.x):
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
			draw_rect(Rect2(o + Vector2(x, y) * t, Vector2(t, t)), color)
	if t >= 10.0:
		for y in range(_view.position.y, _view.end.y + 1):
			draw_line(o + Vector2(_view.position.x, y) * t, o + Vector2(_view.end.x, y) * t, GRID_LINE)
		for x in range(_view.position.x, _view.end.x + 1):
			draw_line(o + Vector2(x, _view.position.y) * t, o + Vector2(x, _view.end.y) * t, GRID_LINE)
	var r := clampf(t * 0.55, 6.0, 11.0)
	for s in journal.secrets.get(file, []):
		_draw_star(o + (Vector2(s[0], s[1]) + Vector2(0.5, 0.5)) * t, r, Journal.MARK_COLORS.secret)
	for f in journal.finds_on(file):
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
	if hero_at != Vector2.INF:
		var p := o + (hero_at + Vector2(0.5, 0.5)) * t
		var fwd := hero_facing.normalized() if hero_facing.length() > 0.01 else Vector2.DOWN
		var side := Vector2(-fwd.y, fwd.x)
		var k := maxf(r * 1.2, 8.0)
		var arrow := PackedVector2Array([p + fwd * k, p - fwd * k * 0.6 + side * k * 0.7, p - fwd * k * 0.25, p - fwd * k * 0.6 - side * k * 0.7])
		draw_colored_polygon(arrow, Color(1.0, 0.82, 0.4))
		arrow.append(arrow[0])
		draw_polyline(arrow, Color(0.1, 0.05, 0.0), 2.0)


func _secret_open(c: Vector2i) -> bool:
	for s in journal.secrets.get(file, []):
		if absi(s[0] - c.x) + absi(s[1] - c.y) <= 1:
			return true
	return false


func _draw_star(p: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.8), 1.5)
