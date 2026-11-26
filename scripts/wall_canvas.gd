class_name WallCanvas
extends Control
## The template of a wall drawn and painted with the mouse (the middle of the wall workshop, see WallWorkshop).
## Every square is one metre of wall: a hold shows its malus (green easy, red hard) with arrows on the edges
## it may be left by, a surface shows as a pattern, a gap as a black crack with its area in square metres,
## and the foot and the summit are marked. Tools: HOLD (left paints, right erases), DIRS (a click near an edge
## of a hold switches that direction), GAP (drag a rectangle; right click removes the gap under the pointer),
## SURFACE (left paints, right clears) and ERASE.

signal stroke_started
signal changed
signal hovered(cell: Vector2i)

enum Tool { HOLD, DIRS, GAP, SURFACE, MARKER, ERASE }

const BG := Color(0.13, 0.115, 0.105)
const GRID := Color(1, 1, 1, 0.07)
const EASY := Color(0.35, 0.68, 0.34)
const MID := Color(0.9, 0.78, 0.3)
const HARD := Color(0.82, 0.25, 0.2)
const ARROW := Color(1, 1, 1, 0.92)
const ROUTE := Color(1.0, 0.85, 0.3, 0.9)

var map: WallMap
var tool := Tool.HOLD
## The malus a new hold gets and whether a new hold links to the holds beside it (both ways) or takes `mask`.
var malus := 2
var link := true
var mask := WallMap.ALL_DIRS
var surface := WallMap.ICE
var marker := "garden"
var route: Array[Vector2i] = []
var climber := WallClimb.NOWHERE
var show_climber := false
var hover := Vector2i(-1, -1)
var selected := Vector2i(-1, -1)

var _painting := false
var _erasing := false
var _dir_state := true
var _dir_bit := 0
var _gap_from := Vector2i(-1, -1)
var _last := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


## Size of one square on screen (they are always square), and where the wall's top left corner is.
func square_px() -> float:
	if map == null:
		return 1.0
	return minf((size.x - 8.0) / map.width, (size.y - 8.0) / map.height)


func origin() -> Vector2:
	var s := square_px()
	return Vector2((size.x - s * map.width) * 0.5, (size.y - s * map.height) * 0.5)


func cell_at(p: Vector2) -> Vector2i:
	var s := square_px()
	var q := (p - origin()) / s
	return Vector2i(int(floor(q.x)), int(floor(q.y)))


func rect_of(c: int, r: int) -> Rect2:
	var s := square_px()
	return Rect2(origin() + Vector2(c, r) * s, Vector2(s, s))


func _gui_input(event: InputEvent) -> void:
	if map == null:
		return
	if event is InputEventMouseMotion:
		var cell := cell_at((event as InputEventMouseMotion).position)
		if cell != hover:
			hover = cell
			hovered.emit(cell)
			queue_redraw()
		if _painting and cell != _last and map.inside(cell.x, cell.y):
			_apply(cell, (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		var cell := cell_at(mb.position)
		if mb.pressed:
			if not map.inside(cell.x, cell.y):
				return
			selected = cell
			_erasing = mb.button_index == MOUSE_BUTTON_RIGHT
			_painting = true
			_last = Vector2i(-1, -1)
			stroke_started.emit()
			if tool == Tool.GAP and not _erasing:
				_gap_from = cell
			elif tool == Tool.DIRS:
				_start_dirs(cell, mb.position)
			_apply(cell, mb.position)
		else:
			if _painting and tool == Tool.GAP and not _erasing and _gap_from.x >= 0:
				var rect := Rect2i(_gap_from, Vector2i.ONE).expand(Vector2i(clampi(cell.x, 0, map.width - 1), clampi(cell.y, 0, map.height - 1)) + Vector2i.ONE)
				map.add_gap(rect)
				changed.emit()
			_painting = false
			_gap_from = Vector2i(-1, -1)
		queue_redraw()


func _start_dirs(cell: Vector2i, p: Vector2) -> void:
	_dir_bit = _edge_at(cell, p)
	_dir_state = not (map.dirs_at(cell.x, cell.y) & _dir_bit != 0)


## The direction of the edge a point of a square is nearest to.
func _edge_at(cell: Vector2i, p: Vector2) -> int:
	var rect := rect_of(cell.x, cell.y)
	var q := p - rect.get_center()
	if absf(q.x) > absf(q.y):
		return WallMap.RIGHT if q.x > 0.0 else WallMap.LEFT
	return WallMap.DOWN if q.y > 0.0 else WallMap.UP


func _apply(cell: Vector2i, p: Vector2) -> void:
	_last = cell
	var c := cell.x
	var r := cell.y
	match tool:
		Tool.HOLD:
			if _erasing:
				map.clear_hold(c, r)
				_unlink_neighbours(c, r)
			else:
				_paint_hold(c, r)
		Tool.DIRS:
			if map.has_hold(c, r) and _dir_bit != 0:
				var now := map.dirs_at(c, r)
				map.set_dirs(c, r, (now | _dir_bit) if _dir_state else (now & ~_dir_bit))
		Tool.GAP:
			if _erasing:
				map.remove_gap_at(c, r)
		Tool.SURFACE:
			map.set_hazard(c, r, WallMap.NONE if _erasing else surface)
		Tool.MARKER:
			map.set_marker(c, r, "" if _erasing else marker)
		Tool.ERASE:
			map.set_marker(c, r, "")
			map.clear_hold(c, r)
			map.set_hazard(c, r, WallMap.NONE)
			map.remove_gap_at(c, r)
			_unlink_neighbours(c, r)
	changed.emit()
	queue_redraw()


func _paint_hold(c: int, r: int) -> void:
	var m := malus
	var m_dirs := mask
	if link:
		m_dirs = 0
		for d: int in WallMap.DIR_ORDER:
			var n: Vector2i = Vector2i(c, r) + WallMap.DIR_STEP[d]
			if map.has_hold(n.x, n.y):
				m_dirs |= d
				map.set_dirs(n.x, n.y, map.dirs_at(n.x, n.y) | _opposite(d))
		# Painting over a hold keeps the arrows it already has.
		m_dirs |= map.dirs_at(c, r)
	map.set_hold(c, r, m, m_dirs)


## A square lost its hold: the neighbours stop pointing at it.
func _unlink_neighbours(c: int, r: int) -> void:
	for d: int in WallMap.DIR_ORDER:
		var n: Vector2i = Vector2i(c, r) + WallMap.DIR_STEP[d]
		if map.has_hold(n.x, n.y):
			map.set_dirs(n.x, n.y, map.dirs_at(n.x, n.y) & ~_opposite(d))


static func _opposite(d: int) -> int:
	match d:
		WallMap.UP:
			return WallMap.DOWN
		WallMap.DOWN:
			return WallMap.UP
		WallMap.LEFT:
			return WallMap.RIGHT
	return WallMap.LEFT


## Colour of a hold by its malus.
static func malus_colour(m: int) -> Color:
	var t := float(m) / WallMap.MAX_MALUS
	return EASY.lerp(MID, clampf(t * 2.0, 0.0, 1.0)).lerp(HARD, clampf(t * 2.0 - 1.0, 0.0, 1.0))


func _draw() -> void:
	if map == null:
		return
	var s := square_px()
	var o := origin()
	draw_rect(Rect2(o, Vector2(s * map.width, s * map.height)), BG)
	var font := UiKit.TEXT_FONT
	var fs := maxi(8, int(s * 0.42))
	for r in map.height:
		for c in map.width:
			var rect := rect_of(c, r)
			var inner := rect.grow(-s * 0.07)
			if map.has_hold(c, r):
				draw_rect(inner, malus_colour(map.malus_at(c, r)).darkened(0.25))
				draw_rect(inner.grow(-s * 0.12), malus_colour(map.malus_at(c, r)))
			_draw_surface(rect, map.hazard_at(c, r), c, r)
			draw_rect(rect, GRID, false, 1.0)
	for g in map.gaps:
		_draw_gap(g)
	for r in map.height:
		for c in map.width:
			if map.has_hold(c, r):
				var rect := rect_of(c, r)
				draw_string(font, rect.position + Vector2(0, s * 0.68), str(map.malus_at(c, r)), HORIZONTAL_ALIGNMENT_CENTER, s, fs, Color(0.08, 0.05, 0.03))
				_draw_arrows(rect, map.dirs_at(c, r))
	for cell: Vector2i in map.markers:
		_draw_marker(cell, String(map.markers[cell]))
	# Foot and summit.
	var foot := Rect2(o + Vector2(0, s * map.height), Vector2(s * map.width, 3))
	draw_rect(foot, UiKit.GOLD)
	draw_rect(Rect2(o + Vector2(0, -3), Vector2(s * map.width, 3)), Color(0.6, 0.85, 1.0))
	if route.size() > 1:
		for i in range(1, route.size()):
			draw_line(rect_of(route[i - 1].x, route[i - 1].y).get_center(), rect_of(route[i].x, route[i].y).get_center(), ROUTE, maxf(2.0, s * 0.16))
	if show_climber:
		var at := rect_of(climber.x, climber.y).get_center() if climber != WallClimb.NOWHERE else o + Vector2(s * (map.width * 0.5), s * map.height + 8.0)
		draw_circle(at, s * 0.34, Color(1, 0.8, 0.3))
		draw_arc(at, s * 0.42, 0, TAU, 24, Color(1, 1, 1), 2.0)
	if map.inside(hover.x, hover.y):
		draw_rect(rect_of(hover.x, hover.y), Color(1, 1, 1, 0.9), false, 2.0)
	if map.inside(selected.x, selected.y):
		draw_rect(rect_of(selected.x, selected.y).grow(-1), UiKit.GOLD, false, 2.0)
	if _painting and tool == Tool.GAP and not _erasing and _gap_from.x >= 0 and map.inside(hover.x, hover.y):
		var rr := Rect2i(_gap_from, Vector2i.ONE).expand(Vector2i(clampi(hover.x, 0, map.width - 1), clampi(hover.y, 0, map.height - 1)) + Vector2i.ONE)
		draw_rect(Rect2(o + Vector2(rr.position) * s, Vector2(rr.size) * s), Color(1, 0.4, 0.3), false, 3.0)


## A marker as a diamond in its colour with the first letter of its name.
func _draw_marker(cell: Vector2i, kind: String) -> void:
	var rect := rect_of(cell.x, cell.y)
	var mid := rect.get_center()
	var h := rect.size.x * 0.5
	var col: Color = WallMap.MARKERS[kind].colour
	draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -h), mid + Vector2(h, 0), mid + Vector2(0, h), mid + Vector2(-h, 0)]), Color(col, 0.9))
	draw_polyline(PackedVector2Array([mid + Vector2(0, -h), mid + Vector2(h, 0), mid + Vector2(0, h), mid + Vector2(-h, 0), mid + Vector2(0, -h)]), Color(0, 0, 0, 0.8), 2.0)
	var letter := String(Lang.t(String(WallMap.MARKERS[kind].name))).substr(0, 1)
	draw_string(UiKit.TEXT_FONT, mid + Vector2(-h, h * 0.3), letter, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(rect.size.x * 0.5)), Color(0.05, 0.03, 0.02))


func _draw_arrows(rect: Rect2, mask_bits: int) -> void:
	var s := rect.size.x
	var mid := rect.get_center()
	var t := s * 0.11
	for d: int in WallMap.DIR_ORDER:
		if mask_bits & d == 0:
			continue
		var v := Vector2(WallMap.DIR_STEP[d])
		var tip := mid + v * s * 0.46
		var base := mid + v * s * 0.3
		var side := Vector2(-v.y, v.x) * t
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), ARROW)


func _draw_surface(rect: Rect2, kind: int, c: int, r: int) -> void:
	if kind == WallMap.NONE:
		return
	var col: Color = WallRules.SURFACES[kind].colour
	var s := rect.size.x
	match kind:
		WallMap.ICE:
			draw_rect(rect.grow(-1), Color(col, 0.38))
			draw_line(rect.position + Vector2(s * 0.15, s * 0.8), rect.position + Vector2(s * 0.8, s * 0.15), Color(1, 1, 1, 0.55), 1.5)
			draw_line(rect.position + Vector2(s * 0.4, s * 0.9), rect.position + Vector2(s * 0.9, s * 0.4), Color(1, 1, 1, 0.4), 1.0)
		WallMap.LOOSE:
			for k in 5:
				var h := WallBuild._hash(c * 7 + k, r * 3 + k * 5)
				var h2 := WallBuild._hash(c * 3 + k * 2, r * 11 + k)
				draw_circle(rect.position + Vector2(s * (0.15 + 0.7 * h), s * (0.15 + 0.7 * h2)), s * 0.07, col)
		WallMap.WET:
			draw_rect(rect.grow(-1), Color(col, 0.32))
			for k in 3:
				var h := WallBuild._hash(c * 5 + k, r * 13 + k)
				draw_line(rect.position + Vector2(s * (0.2 + 0.6 * h), s * 0.1), rect.position + Vector2(s * (0.2 + 0.6 * h), s * 0.9), Color(col, 0.8), 1.5)


## A gap as a black jagged crack over its rectangle, with its area and span written in it.
func _draw_gap(g: Rect2i) -> void:
	var s := square_px()
	var o := origin()
	var rect := Rect2(o + Vector2(g.position) * s, Vector2(g.size) * s)
	var pts := PackedVector2Array()
	var steps := maxi(4, g.size.x * 3)
	for i in range(steps + 1):
		var x := rect.position.x + rect.size.x * i / steps
		var j := (WallBuild._hash(g.position.x * 5 + i, g.position.y * 3 + 1) - 0.5) * s * 0.35
		pts.append(Vector2(x, rect.position.y + s * 0.08 + j * (0.0 if i == 0 or i == steps else 1.0)))
	for i in range(steps, -1, -1):
		var x := rect.position.x + rect.size.x * i / steps
		var j := (WallBuild._hash(g.position.x * 5 + i, g.position.y * 3 + 9) - 0.5) * s * 0.35
		pts.append(Vector2(x, rect.end.y - s * 0.08 + j * (0.0 if i == 0 or i == steps else 1.0)))
	draw_colored_polygon(pts, Color(0.02, 0.02, 0.03))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.5, 0.45), 2.0)
	var area := g.size.x * g.size.y
	var text := "%d m²" % area
	var fs := maxi(9, int(s * 0.5))
	draw_string(UiKit.TEXT_FONT, rect.get_center() + Vector2(-rect.size.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(0.95, 0.88, 0.7))
