class_name WealthChart
extends Control
## The line chart of the hero's worth over the days (see Wealth, WealthWindow): days along the bottom, copper up the
## side, a gold line over a faint area, a round top for the scale. Pointing at the chart reads one day in the band
## above the plot (the newest day when nothing is pointed at), so the chart never grows a pop-up and nothing
## depends on hover alone: the window prints the main numbers as text. The control has one fixed size.

const SIZE := Vector2(700, 270)
const LEFT := 66.0
const RIGHT := 16.0
const TOP := 38.0
const BOTTOM := 34.0
const FONT_SIZE := 16
const GRID_LINES := 4
const MAX_LABELS := 5
const MAX_DOTS := 45
const LINE := Color(1.0, 0.8, 0.35)
const AREA := Color(1.0, 0.8, 0.35, 0.16)
const GRID := Color(0.75, 0.6, 0.4, 0.22)
const TEXT := Color(0.86, 0.8, 0.7)
const GROUND := Color(0.05, 0.035, 0.03, 0.6)
const RIM := Color(0.45, 0.3, 0.15, 0.8)

var points: Array = []
var font: Font
var empty_text := ""
var _hover := -1
var _top := 4


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_CROSS


## Gives the chart its readings ([day, copper] pairs, oldest first) and the font of its texts.
func setup(readings: Array, text_font: Font, none_text: String) -> void:
	points = readings
	font = text_font
	empty_text = none_text
	var peak := 0
	for p in points:
		peak = maxi(peak, int(p[1]))
	_top = Wealth.nice_top(peak)
	_hover = -1
	queue_redraw()


func plot() -> Rect2:
	return Rect2(LEFT, TOP, SIZE.x - LEFT - RIGHT, SIZE.y - TOP - BOTTOM)


func point_at(i: int) -> Vector2:
	var r := plot()
	var d0 := float(points[0][0])
	var span := maxf(1.0, float(points.back()[0]) - d0)
	return Vector2(r.position.x + (float(points[i][0]) - d0) / span * r.size.x,
			r.end.y - float(points[i][1]) / float(_top) * r.size.y)


## The reading nearest to a place along the chart.
func nearest(x: float) -> int:
	var best := 0
	var best_gap := INF
	for i in points.size():
		var gap := absf(point_at(i).x - x)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and points.size() >= 2:
		var i := nearest(event.position.x)
		if i != _hover:
			_hover = i
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func _text(at: Vector2, text: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, color := TEXT) -> void:
	draw_string(font, at, text, align, width, UiKit.sized(FONT_SIZE), color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), GROUND)
	draw_rect(Rect2(Vector2.ZERO, SIZE), RIM, false, 2.0)
	if font == null:
		return
	var r := plot()
	if points.size() < 2:
		_text(Vector2(0, r.position.y + r.size.y * 0.5), empty_text, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x)
		return
	# The scale: a faint line and a label per step.
	for i in GRID_LINES + 1:
		var y := r.end.y - r.size.y * i / GRID_LINES
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), GRID, 1.0)
		_text(Vector2(0, y + 6), Wealth.compact(_top * i / GRID_LINES), HORIZONTAL_ALIGNMENT_RIGHT, LEFT - 10)
	# The days: at most MAX_LABELS evenly spread labels.
	var d0 := int(points[0][0])
	var d1 := int(points.back()[0])
	var labels := mini(MAX_LABELS, d1 - d0 + 1)
	for i in labels:
		var day := d0 + roundi(float(d1 - d0) * i / maxf(1.0, labels - 1.0))
		var x := r.position.x + r.size.x * i / maxf(1.0, labels - 1.0)
		draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 5), GRID, 1.0)
		var align := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else (HORIZONTAL_ALIGNMENT_RIGHT if i == labels - 1 else HORIZONTAL_ALIGNMENT_CENTER)
		var left := x if i == 0 else (x - 120.0 if i == labels - 1 else x - 60.0)
		_text(Vector2(left, r.end.y + 26), Lang.t("Tag %d") % day, align, 120.0)
	# The line over its area.
	var line := PackedVector2Array()
	for i in points.size():
		line.append(point_at(i))
	var area := line.duplicate()
	area.append(Vector2(line[line.size() - 1].x, r.end.y))
	area.append(Vector2(line[0].x, r.end.y))
	draw_colored_polygon(area, AREA)
	draw_polyline(line, LINE, 3.0, true)
	if points.size() <= MAX_DOTS:
		for p in line:
			draw_circle(p, 4.0, LINE)
	# One reading, written above the plot: the pointed-at one, else the newest.
	var shown := _hover if _hover >= 0 else points.size() - 1
	var at := line[shown]
	if _hover >= 0:
		draw_line(Vector2(at.x, r.position.y), Vector2(at.x, r.end.y), LINE * Color(1, 1, 1, 0.5), 1.0)
	draw_circle(at, 7.0, Color(0.1, 0.07, 0.05))
	draw_circle(at, 5.0, Color.WHITE if _hover >= 0 else LINE)
	var copper := int(points[shown][1])
	_text(Vector2(LEFT, 26), Lang.t("Tag %d: %s Kupfer") % [int(points[shown][0]), Wealth.grouped(copper)], HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - LEFT - RIGHT, Color(1.0, 0.9, 0.6))
