class_name StatusIcon
extends Control
## A little icon for a condition the hero is in, shown in a row under the
## life bar (see Game._update_status_icons): a dark tile with a red frame and
## a drawn picture, with a number in its corner where the condition has one.
##   "gift"     poisoned: a green drop
##   "fluch"    cursed: a violet eye
##   "brand"    burning: a flame
##   "power"    stronger blows: a sword, with the fighting power
##   "fast"     faster: boots with an arrow up
##   "slow"     slower: boots with an arrow down
##   "hardening" hardened: a shield, with the hardening

## The tile's side, in pixels; every icon has the same size.
const SIZE := 26.0
const FRAME := Color(0.9, 0.22, 0.2)
const TILE := Color(0.07, 0.05, 0.07, 0.9)
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

var kind := ""
var value := ""


static func make(what: String, number := "") -> StatusIcon:
	var icon := StatusIcon.new()
	icon.kind = what
	icon.value = number
	icon.custom_minimum_size = Vector2(SIZE, SIZE)
	icon.size = icon.custom_minimum_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := ""
	match what:
		"brand": picture = "kind:flame"
		"power": picture = "kind:sword"
		"fast", "slow": picture = "kind:boots"
		"hardening": picture = "kind:shield"
	if picture != "":
		var drawn := ItemIcon.make(picture, SIZE - 8.0, true)
		drawn.position = Vector2(4, 4)
		icon.add_child(drawn)
	if number != "":
		var label := Label.new()
		label.text = number
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.position = Vector2(0, 6)
		label.size = Vector2(SIZE + 4, SIZE)
		icon.add_child(label)
	return icon


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, TILE)
	draw_rect(r.grow(-1), FRAME, false, 2.0)
	var c := size / 2.0
	match kind:
		"gift":
			# A drop of poison.
			draw_circle(c + Vector2(0, 3), 6.0, Color(0.4, 0.85, 0.3))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(5.6, 1.5), c + Vector2(-5.6, 1.5)]), Color(0.4, 0.85, 0.3))
			draw_circle(c + Vector2(-2, 3), 1.6, Color(0.8, 1.0, 0.7))
		"fluch":
			# An evil eye.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(0, -6), c + Vector2(9, 0), c + Vector2(0, 6)]), Color(0.75, 0.55, 1.0))
			draw_circle(c, 3.2, Color(0.15, 0.05, 0.2))
	if kind in ["fast", "slow"]:
		var up := kind == "fast"
		var tip := Vector2(size.x - 6, 6 if up else 13)
		var col := Color(0.35, 0.9, 0.35) if up else Color(0.95, 0.3, 0.25)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-4, 6 if up else -6), tip + Vector2(4, 6 if up else -6)]), col)
