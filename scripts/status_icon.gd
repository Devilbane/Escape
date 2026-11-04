class_name StatusIcon
extends Control
## A little icon for a condition the hero is in (see
## Game._update_status_icons): a dark tile with a coloured frame and a drawn
## picture, with a number in its corner where the condition has one.
## Passing troubles, with a red frame, in a row under the life bar
## (Game.hero_ailments):
##   "gift"     poisoned: a green drop
##   "fluch"    cursed: a violet eye
##   "brand"    burning: a flame
##   "slow"     slower: boots with an arrow down
## boons, with a green frame, in the status block at the top left
## (Game.hero_boons):
##   "power"    stronger blows: a sword, with the fighting power
##   "fast"     faster: boots with an arrow up
##   "hardening" hardened: a shield, with the hardening
## and, with a golden frame, things waiting for the hero (Game.hero_notices):
##   "repair"   worn gear to mend: hammer and anvil, with how many pieces
##   "upgrade"  a home upgrade Hagen can build now: a stone block, arrow up

## The tile's side, in pixels; every icon has the same size.
const SIZE := 26.0
const FRAME := Color(0.9, 0.22, 0.2)
const NOTICE_FRAME := Color(0.95, 0.75, 0.3)
const BOON_FRAME := Color(0.4, 0.92, 0.4)
## The kinds that are notices (golden frame) rather than conditions.
const NOTICES := ["repair", "upgrade"]
## The kinds that are boons (green frame) rather than troubles.
const BOONS := ["power", "fast", "hardening"]
const TILE := Color(0.07, 0.05, 0.07, 0.9)
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

var kind := ""
var value := ""


## `tip` is the short explanation shown when the pointer rests on the icon
## (already translated); the icon then takes the pointer but lets clicks pass.
static func make(what: String, number := "", tip := "") -> StatusIcon:
	var icon := StatusIcon.new()
	icon.kind = what
	icon.value = number
	icon.custom_minimum_size = Vector2(SIZE, SIZE)
	icon.size = icon.custom_minimum_size
	icon.tooltip_text = tip
	icon.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	var picture := ""
	match what:
		"brand": picture = "kind:flame"
		"power": picture = "kind:sword"
		"fast", "slow": picture = "kind:boots"
		"hardening": picture = "kind:shield"
		"repair": picture = "kind:hammer_anvil"
		"upgrade": picture = "kind:stone"
	if picture != "":
		var drawn := ItemIcon.make(picture, SIZE - 8.0, true)
		drawn.position = Vector2(4, 4)
		icon.add_child(drawn)
	if number != "":
		var label := Label.new()
		label.text = number
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", UiKit.sized(14))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.position = Vector2(0, 6)
		label.size = Vector2(SIZE + 4, SIZE)
		icon.add_child(label)
	return icon


## The frame of a kind's tile: gold for a notice, green for a boon, red for
## a trouble.
static func frame_color(what: String) -> Color:
	if what in NOTICES:
		return NOTICE_FRAME
	if what in BOONS:
		return BOON_FRAME
	return FRAME


## The colour a kind's explanation has in the event log, matching its frame
## (a lighter red for a trouble, which reads better as text).
static func log_color(what: String) -> Color:
	if what in NOTICES or what in BOONS:
		return frame_color(what)
	return Color(1.0, 0.6, 0.55)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, TILE)
	draw_rect(r.grow(-1), frame_color(kind), false, 2.0)
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
	if kind in ["fast", "slow", "upgrade"]:
		var up := kind != "slow"
		var tip := Vector2(size.x - 6, 6 if up else 13)
		var col := Color(0.35, 0.9, 0.35) if up else Color(0.95, 0.3, 0.25)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-4, 6 if up else -6), tip + Vector2(4, 6 if up else -6)]), col)
