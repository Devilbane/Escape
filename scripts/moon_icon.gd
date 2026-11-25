class_name MoonIcon
extends Control
## The moon's phase as a little drawn moon in front of the HUD's location name (see Game._update_moon_icon), so
## the phase reads without words: a cratered grey disc with dark seas, lit from the right while it
## waxes and from the left while it wanes, the unlit part left as a faint earthshine. A bronze
## tile frames it, like the status icons. It has a fixed size, so the top line never shifts.

const SIZE := 30.0
const TILE := Color(0.05, 0.06, 0.12, 0.92)
const RIM := Color(0.72, 0.62, 0.38)
const DISC := Color(0.86, 0.86, 0.8)
const SEA := Color(0.62, 0.63, 0.64)
const CRATER := Color(0.7, 0.7, 0.68)
const SHADE := Color(0.03, 0.04, 0.1, 0.86)
const STEPS := 28
## Dark seas and craters on the disc as (x, y, radius), in shares of the moon's radius.
const SEAS := [[-0.32, -0.28, 0.34], [0.12, -0.5, 0.22], [0.3, 0.05, 0.3], [-0.1, 0.22, 0.24], [-0.45, 0.2, 0.15]]
const CRATERS := [[0.5, -0.42, 0.11], [-0.55, -0.05, 0.09], [0.05, 0.55, 0.12], [0.55, 0.5, 0.08], [-0.2, -0.65, 0.07]]

## The phase, 0 (new) to Moon.CYCLE - 1, as Moon.phase gives it.
var phase := 0


static func make(which: int, tip := "") -> MoonIcon:
	var icon := MoonIcon.new()
	icon.custom_minimum_size = Vector2(SIZE, SIZE)
	icon.size = icon.custom_minimum_size
	icon.set_phase(which, tip)
	return icon


func set_phase(which: int, tip: String) -> void:
	phase = posmod(which, Moon.CYCLE)
	tooltip_text = tip
	mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## The dark part of the disc as a polygon about the origin, radius 1: the limb of the side that is
## away from the light, closed by the terminator, an ellipse as wide as the phase says.
static func shadow_polygon(which: int) -> PackedVector2Array:
	var p := posmod(which, Moon.CYCLE)
	var angle := TAU * p / Moon.CYCLE
	var waxing := p <= Moon.CYCLE / 2
	# Light from the right while waxing: the dark limb is the left half.
	var side := -1.0 if waxing else 1.0
	var width := cos(angle)  # 1 at new moon, 0 at the quarters, -1 at full moon
	var pts := PackedVector2Array()
	for i in STEPS + 1:
		var t := PI * i / STEPS
		pts.append(Vector2(side * sin(t), -cos(t)))
	for i in STEPS + 1:
		var t := PI - PI * i / STEPS
		pts.append(Vector2(-side * width * sin(t), -cos(t)))
	return pts


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	UiKit.frame_style(TILE, RIM, 2, 4).draw(get_canvas_item(), r)
	var c := size / 2.0
	var rad := size.x / 2.0 - 5.0
	# A faint halo, then the disc with its seas and craters.
	draw_circle(c, rad + 2.5, Color(0.75, 0.82, 1.0, 0.12))
	draw_circle(c, rad, DISC)
	for s in SEAS:
		draw_circle(c + Vector2(s[0], s[1]) * rad, s[2] * rad, SEA)
	for k in CRATERS:
		var at: Vector2 = c + Vector2(k[0], k[1]) * rad
		draw_circle(at, k[2] * rad, CRATER)
		draw_arc(at, k[2] * rad, PI * 1.1, PI * 1.9, 8, Color(0.97, 0.97, 0.93), 1.0, true)
	draw_arc(c, rad - 0.5, 0.0, TAU, 32, Color(1.0, 1.0, 0.95, 0.5), 1.0, true)
	# The unlit part on top, so only the lit part keeps its colours.
	var shade := shadow_polygon(phase)
	for i in shade.size():
		shade[i] = c + shade[i] * rad
	if phase != Moon.FULL:
		draw_colored_polygon(shade, SHADE)
