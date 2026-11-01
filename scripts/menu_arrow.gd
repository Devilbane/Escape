class_name MenuArrow
extends Control
## The little arrow on the handle of the pull-out menu: a short, wide
## triangle with softly rounded corners, so it reads as a gentle nudge to
## the side rather than a sharp spike. Points left while the menu is closed
## (pull it out) and right while it is open (push it back).

## How far the rounded corners reach, in pixels.
const ROUND := 3.0

var color := Color(1.0, 0.82, 0.4)
## Which way the arrow points.
var pointing_left := true:
	set(value):
		pointing_left = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(18, 20)


func _draw() -> void:
	# The triangle inside the rounding, so the rounded shape fills the box.
	var w := size.x - ROUND * 2.0
	var h := size.y - ROUND * 2.0
	var tip := ROUND if pointing_left else ROUND + w
	var back := ROUND + w if pointing_left else ROUND
	var core := PackedVector2Array([
		Vector2(tip, ROUND + h * 0.5),
		Vector2(back, ROUND),
		Vector2(back, ROUND + h),
	])
	if not pointing_left:
		core.reverse()
	var shapes := Geometry2D.offset_polygon(core, ROUND, Geometry2D.JOIN_ROUND)
	if shapes.is_empty():
		return
	var outline: PackedVector2Array = shapes[0]
	draw_colored_polygon(outline, color)
	# A thin antialiased rim smooths the polygon's jagged edge.
	outline.append(outline[0])
	draw_polyline(outline, color, 1.0, true)
