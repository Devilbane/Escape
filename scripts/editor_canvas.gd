class_name EditorCanvas
extends Control
## The grid of the map workshop (see LevelEditor): draws a LevelMap tile by
## tile and paints on it.
##
## Left button: paint with the picked tile (brush), draw a rectangle, or
## flood-fill, as the tool says. Right button: paint wall. Middle button (or
## Space held) drags the view, the wheel zooms round the pointer.

signal painted
signal hovered(cell: Vector2i)
## A stroke began: the editor keeps the map as it was, for undo.
signal stroke_started

enum Tool { BRUSH, RECT, FILL }

const MIN_ZOOM := 10.0
const MAX_ZOOM := 56.0
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

var map: LevelMap
var letter := "."
var tool := Tool.BRUSH
var zoom := 30.0
var offset := Vector2(20, 20)
## The tile picked in the checks (see LevelEditor), outlined until the next one.
var marked := Vector2i(-1, -1)
var hover := Vector2i(-1, -1)
var _painting := 0
var _paint_letter := ""
var _rect_from := Vector2i(-1, -1)
var _panning := false
var _space := false


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_default_cursor_shape = Control.CURSOR_CROSS


## Fits the whole map in view.
func fit() -> void:
	if map == null or size.x <= 0:
		return
	var cells := Vector2(maxi(map.width(), 1), maxi(map.height(), 1))
	zoom = clampf(floorf(minf((size.x - 24) / cells.x, (size.y - 24) / cells.y)), MIN_ZOOM, MAX_ZOOM)
	offset = ((size - cells * zoom) / 2.0).round()
	queue_redraw()


func cell_at(point: Vector2) -> Vector2i:
	var p := (point - offset) / zoom
	return Vector2i(floori(p.x), floori(p.y))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.07))
	if map == null:
		return
	var made := map.creations()
	var w := map.width()
	var h := map.height()
	var font_size := int(zoom * 0.55)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch := map.cell(c)
			var r := Rect2(offset + Vector2(x, y) * zoom, Vector2(zoom, zoom))
			if not r.intersects(Rect2(Vector2.ZERO, size)):
				continue
			draw_rect(r.grow(-0.5), EditorPalette.color_of(ch))
			if EditorPalette.is_wall(ch):
				continue
			if ch != "." and font_size >= 8:
				var tint := Color(0.05, 0.03, 0.06) if EditorPalette.color_of(ch).get_luminance() > 0.45 else Color(1, 0.95, 0.85)
				var text_size := TEXT_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				draw_string(TEXT_FONT, r.position + Vector2((zoom - text_size.x) / 2.0, zoom * 0.5 + font_size * 0.36), ch,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
			if made.has(ch):
				# A creation gets a ring, so it reads apart from the game's own tiles.
				draw_rect(r.grow(-2.0), Color(0.75, 0.65, 1.0), false, 2.0)
	# The outline of the map, the rectangle being drawn, the hovered and the marked tile.
	draw_rect(Rect2(offset, Vector2(w, h) * zoom), Color(0.85, 0.66, 0.32, 0.6), false, 2.0)
	if _rect_from.x >= 0 and hover.x >= 0:
		var a := Vector2i(mini(_rect_from.x, hover.x), mini(_rect_from.y, hover.y))
		var b := Vector2i(maxi(_rect_from.x, hover.x), maxi(_rect_from.y, hover.y))
		draw_rect(Rect2(offset + Vector2(a) * zoom, Vector2(b - a + Vector2i.ONE) * zoom), Color(1, 0.82, 0.4, 0.9), false, 3.0)
	if map.in_bounds(hover):
		draw_rect(Rect2(offset + Vector2(hover) * zoom, Vector2(zoom, zoom)), Color(1, 1, 1, 0.9), false, 2.0)
	if map.in_bounds(marked):
		draw_rect(Rect2(offset + Vector2(marked) * zoom, Vector2(zoom, zoom)).grow(3.0), Color(1.0, 0.3, 0.25), false, 3.0)


func _gui_input(event: InputEvent) -> void:
	if map == null:
		return
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != hover:
			hover = c
			hovered.emit(c)
			queue_redraw()
		if _panning:
			offset += event.relative
			queue_redraw()
		elif _painting != 0 and tool == Tool.BRUSH:
			_paint(c, _paint_letter)
		accept_event()
	elif event is InputEventMouseButton:
		_mouse_button(event)
		accept_event()


func _mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_at(event.position, 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			if event.button_index == MOUSE_BUTTON_LEFT and _space:
				_panning = event.pressed
				return
			var c := cell_at(event.position)
			if event.pressed:
				grab_focus()
				_painting = event.button_index
				_paint_letter = letter if event.button_index == MOUSE_BUTTON_LEFT else "#"
				stroke_started.emit()
				match tool:
					Tool.BRUSH:
						_paint(c, _paint_letter)
					Tool.RECT:
						_rect_from = c
					Tool.FILL:
						_fill(c, _paint_letter)
			elif _painting == event.button_index:
				if tool == Tool.RECT and _rect_from.x >= 0:
					_paint_rect(_rect_from, c, _paint_letter)
				_rect_from = Vector2i(-1, -1)
				_painting = 0
				queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_SPACE:
		_space = event.pressed
		mouse_default_cursor_shape = Control.CURSOR_DRAG if _space else Control.CURSOR_CROSS


func zoom_at(point: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	offset = point - (point - offset) * (new_zoom / zoom)
	zoom = new_zoom
	queue_redraw()


func _paint(c: Vector2i, ch: String) -> void:
	if not map.in_bounds(c) or map.cell(c) == ch:
		return
	map.set_cell(c, ch)
	painted.emit()
	queue_redraw()


func _paint_rect(a: Vector2i, b: Vector2i, ch: String) -> void:
	var changed := false
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			var c := Vector2i(x, y)
			if map.in_bounds(c) and map.cell(c) != ch:
				map.set_cell(c, ch)
				changed = true
	if changed:
		painted.emit()


## Fills the patch of the same letter round c (four ways) with ch.
func _fill(c: Vector2i, ch: String) -> void:
	if not map.in_bounds(c):
		return
	var old := map.cell(c)
	if old == ch:
		return
	var todo: Array[Vector2i] = [c]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if not map.in_bounds(p) or map.cell(p) != old:
			continue
		map.set_cell(p, ch)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(p + d)
	painted.emit()
	queue_redraw()
