class_name ItemIcon
extends Control
## A small drawn picture for the trading windows: what kind of thing an item
## is (a sword, a shield, boots, a book ...), in the item's own colour, on a
## dark tile with a golden frame. Also draws the little up and down arrows of
## the comparison card ("up", "down") and the category emblems.

## What to draw: an item id, or one of the plain kinds below with "kind:".
var what := ""
## Draws only the picture, without the tile and frame (for arrows and emblems).
var bare := false

const FRAME := Color(0.85, 0.66, 0.32, 0.85)
const TILE := Color(0.07, 0.06, 0.09, 1.0)
const STEEL := Color(0.78, 0.8, 0.86)
const WOOD := Color(0.55, 0.34, 0.17)
const LEATHER := Color(0.55, 0.33, 0.16)
const GOLDEN := Color(1.0, 0.8, 0.35)
const UP := Color(0.35, 0.9, 0.35)
const DOWN := Color(0.95, 0.3, 0.25)


static func make(id: String, size := 44.0, plain := false) -> ItemIcon:
	var icon := ItemIcon.new()
	icon.what = id
	icon.bare = plain
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## The kind of picture an item gets, from its slot (and weapon skill).
static func kind_of(id: String) -> String:
	if id.begins_with("kind:"):
		return id.split(":")[1]
	if not Items.ALL.has(id):
		return "bag"
	var item: Dictionary = Items.ALL[id]
	match item.slot:
		"waffe":
			if id == "streitkolben" or id == "kriegshammer":
				return "hammer"
			return "axe" if item.get("uses", "") == "aexte" else "sword"
		"schild":
			return "shield"
		"kopf":
			return "helmet"
		"umhang":
			return "cloak"
		"ruestung":
			return "armour"
		"schuhe":
			return "boots"
		"amulett":
			return "amulet"
		"ring":
			return "ring"
		"armreif":
			return "bracelet"
		"spezial":
			return "special"
		"rucksack":
			return "bag"
		"buch":
			return "book"
		"stein":
			return "stone"
		"erz":
			return "ore"
		"kiste":
			return "crate"
		"futter":
			return "sausage"
	return "scroll"


## The item's own colour: its tint, else one by material.
static func color_of(id: String) -> Color:
	if not Items.ALL.has(id):
		return GOLDEN
	var item: Dictionary = Items.ALL[id]
	if item.has("tint"):
		return item.tint
	match item.get("material", ""):
		"leather":
			return LEATHER
		"cloth":
			return Color(0.6, 0.5, 0.4)
		"fur":
			return Color(0.5, 0.36, 0.22)
		"bone":
			return Color(0.9, 0.88, 0.78)
		"metal", "chain":
			return STEEL
	return GOLDEN


func _draw() -> void:
	var s := size
	if not bare:
		draw_rect(Rect2(Vector2.ZERO, s), TILE)
		draw_rect(Rect2(Vector2.ONE, s - Vector2.ONE * 2), FRAME, false, 1.5)
	# All shapes are drawn on a 0..1 square scaled into the control.
	var pad := 0.0 if bare else s.x * 0.12
	var u := (minf(s.x, s.y) - pad * 2.0)
	var o := (s - Vector2(u, u)) / 2.0
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	var c := color_of(what)
	match kind_of(what):
		"sword":
			draw_line(p.call(0.25, 0.75), p.call(0.82, 0.18), STEEL, u * 0.09)
			draw_line(p.call(0.15, 0.6), p.call(0.4, 0.85), GOLDEN, u * 0.07)
			draw_line(p.call(0.22, 0.78), p.call(0.1, 0.9), WOOD, u * 0.08)
		"axe":
			draw_line(p.call(0.2, 0.9), p.call(0.65, 0.15), WOOD, u * 0.08)
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.2), p.call(0.88, 0.12), p.call(0.92, 0.5), p.call(0.62, 0.42)]), STEEL)
		"hammer":
			draw_line(p.call(0.2, 0.9), p.call(0.62, 0.3), WOOD, u * 0.08)
			draw_colored_polygon(PackedVector2Array([p.call(0.42, 0.22), p.call(0.66, 0.05), p.call(0.92, 0.38), p.call(0.68, 0.55)]), STEEL)
		"shield":
			var pts := PackedVector2Array([p.call(0.18, 0.15), p.call(0.82, 0.15), p.call(0.82, 0.5), p.call(0.5, 0.92), p.call(0.18, 0.5)])
			draw_colored_polygon(pts, WOOD)
			pts.append(pts[0])
			draw_polyline(pts, STEEL, u * 0.06)
			draw_line(p.call(0.5, 0.2), p.call(0.5, 0.82), GOLDEN, u * 0.05)
			draw_line(p.call(0.25, 0.42), p.call(0.75, 0.42), GOLDEN, u * 0.05)
		"helmet":
			draw_circle(p.call(0.5, 0.52), u * 0.32, c)
			draw_rect(Rect2(p.call(0.16, 0.52), Vector2(u * 0.68, u * 0.32)), c)
			draw_rect(Rect2(p.call(0.3, 0.55), Vector2(u * 0.4, u * 0.08)), TILE)
			draw_line(p.call(0.5, 0.63), p.call(0.5, 0.84), TILE, u * 0.06)
		"cloak":
			draw_colored_polygon(PackedVector2Array([p.call(0.38, 0.12), p.call(0.62, 0.12), p.call(0.88, 0.9), p.call(0.12, 0.9)]), c)
			draw_circle(p.call(0.5, 0.16), u * 0.07, GOLDEN)
		"armour":
			draw_colored_polygon(PackedVector2Array([p.call(0.15, 0.2), p.call(0.38, 0.12), p.call(0.5, 0.22), p.call(0.62, 0.12), p.call(0.85, 0.2),
					p.call(0.78, 0.45), p.call(0.72, 0.42), p.call(0.72, 0.88), p.call(0.28, 0.88), p.call(0.28, 0.42), p.call(0.22, 0.45)]), c)
			draw_line(p.call(0.5, 0.25), p.call(0.5, 0.85), c.darkened(0.35), u * 0.04)
		"boots":
			for dx in [0.0, 0.3]:
				draw_colored_polygon(PackedVector2Array([p.call(0.18 + dx, 0.15), p.call(0.4 + dx, 0.15), p.call(0.4 + dx, 0.72), p.call(0.55 + dx, 0.78),
						p.call(0.55 + dx, 0.9), p.call(0.15 + dx, 0.9)]), c.darkened(dx))
		"amulet":
			draw_arc(p.call(0.5, 0.32), u * 0.3, 0.2, PI - 0.2, 24, GOLDEN, u * 0.04)
			draw_arc(p.call(0.5, 0.2), u * 0.36, 0.6, PI - 0.6, 24, GOLDEN, u * 0.04)
			draw_circle(p.call(0.5, 0.72), u * 0.16, GOLDEN)
			draw_circle(p.call(0.5, 0.72), u * 0.1, Color(0.3, 0.55, 1.0))
		"ring":
			draw_arc(p.call(0.5, 0.6), u * 0.26, 0, TAU, 32, GOLDEN, u * 0.09)
			draw_circle(p.call(0.5, 0.3), u * 0.12, Color(0.95, 0.25, 0.3) if what == "rubinring" else GOLDEN.darkened(0.2))
		"bracelet":
			draw_arc(p.call(0.5, 0.5), u * 0.34, 0, TAU, 32, c, u * 0.12)
			draw_arc(p.call(0.5, 0.5), u * 0.34, 0, TAU, 32, c.lightened(0.3), u * 0.03)
		"special":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.08), p.call(0.62, 0.38), p.call(0.92, 0.4), p.call(0.68, 0.6), p.call(0.78, 0.92),
					p.call(0.5, 0.74), p.call(0.22, 0.92), p.call(0.32, 0.6), p.call(0.08, 0.4), p.call(0.38, 0.38)]), Color(0.75, 0.5, 1.0))
		"bag":
			draw_circle(p.call(0.5, 0.62), u * 0.32, c)
			draw_rect(Rect2(p.call(0.36, 0.14), Vector2(u * 0.28, u * 0.22)), c.darkened(0.2))
			draw_line(p.call(0.34, 0.34), p.call(0.66, 0.34), GOLDEN, u * 0.05)
		"book":
			draw_rect(Rect2(p.call(0.2, 0.12), Vector2(u * 0.6, u * 0.76)), Color(0.45, 0.22, 0.12))
			draw_rect(Rect2(p.call(0.2, 0.12), Vector2(u * 0.6, u * 0.76)), GOLDEN, false, u * 0.04)
			draw_line(p.call(0.5, 0.3), p.call(0.5, 0.7), GOLDEN, u * 0.05)
			draw_line(p.call(0.35, 0.45), p.call(0.65, 0.45), GOLDEN, u * 0.05)
		"stone":
			draw_rect(Rect2(p.call(0.15, 0.3), Vector2(u * 0.7, u * 0.5)), Color(0.62, 0.6, 0.56))
			draw_colored_polygon(PackedVector2Array([p.call(0.15, 0.3), p.call(0.3, 0.16), p.call(0.97, 0.16), p.call(0.85, 0.3)]), Color(0.76, 0.74, 0.7))
		"ore":
			draw_colored_polygon(PackedVector2Array([p.call(0.2, 0.7), p.call(0.3, 0.3), p.call(0.6, 0.15), p.call(0.85, 0.45), p.call(0.7, 0.85)]), c)
			draw_line(p.call(0.4, 0.35), p.call(0.55, 0.6), Color.WHITE, u * 0.04)
		"crate":
			draw_rect(Rect2(p.call(0.15, 0.15), Vector2(u * 0.7, u * 0.7)), WOOD)
			draw_line(p.call(0.15, 0.15), p.call(0.85, 0.85), WOOD.darkened(0.4), u * 0.06)
		"iron":
			draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.75), p.call(0.25, 0.45), p.call(0.9, 0.45), p.call(0.75, 0.75)]), STEEL.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([p.call(0.25, 0.45), p.call(0.32, 0.32), p.call(0.82, 0.32), p.call(0.9, 0.45)]), STEEL)
		"hammer_anvil":
			draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.45), p.call(0.9, 0.45), p.call(0.7, 0.62), p.call(0.66, 0.85), p.call(0.34, 0.85), p.call(0.3, 0.62)]), STEEL.darkened(0.3))
			draw_line(p.call(0.55, 0.38), p.call(0.85, 0.08), WOOD, u * 0.07)
			draw_rect(Rect2(p.call(0.42, 0.22), Vector2(u * 0.22, u * 0.16)), STEEL)
		"flame":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.05), p.call(0.8, 0.5), p.call(0.72, 0.85), p.call(0.5, 0.95), p.call(0.28, 0.85), p.call(0.2, 0.5)]), Color(1.0, 0.5, 0.15))
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.4), p.call(0.65, 0.7), p.call(0.5, 0.88), p.call(0.35, 0.7)]), Color(1.0, 0.85, 0.3))
		"scissors":
			draw_arc(p.call(0.28, 0.75), u * 0.14, 0, TAU, 20, GOLDEN, u * 0.06)
			draw_arc(p.call(0.72, 0.75), u * 0.14, 0, TAU, 20, GOLDEN, u * 0.06)
			draw_line(p.call(0.36, 0.64), p.call(0.75, 0.1), STEEL, u * 0.07)
			draw_line(p.call(0.64, 0.64), p.call(0.25, 0.1), STEEL, u * 0.07)
		"needle":
			draw_line(p.call(0.2, 0.85), p.call(0.8, 0.15), STEEL, u * 0.06)
			draw_circle(p.call(0.2, 0.85), u * 0.08, Color(0.3, 0.4, 0.9))
		"hair":
			# what is "kind:hair:<colour>" for a hair colour swatch.
			draw_circle(p.call(0.5, 0.55), u * 0.32, Color(0.85, 0.7, 0.55))
			draw_arc(p.call(0.5, 0.55), u * 0.36, PI, TAU, 24, _hair_color(), u * 0.18)
		"sausage":
			draw_line(p.call(0.2, 0.7), p.call(0.8, 0.3), Color(0.65, 0.3, 0.2), u * 0.26)
			draw_circle(p.call(0.2, 0.7), u * 0.13, Color(0.65, 0.3, 0.2))
			draw_circle(p.call(0.8, 0.3), u * 0.13, Color(0.65, 0.3, 0.2))
		"potion":
			draw_circle(p.call(0.5, 0.65), u * 0.28, Color(0.4, 0.75, 0.4, 0.8))
			draw_rect(Rect2(p.call(0.42, 0.12), Vector2(u * 0.16, u * 0.28)), GOLDEN)
		"up":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.15), p.call(0.9, 0.85), p.call(0.1, 0.85)]), UP)
		"down":
			draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.15), p.call(0.9, 0.15), p.call(0.5, 0.85)]), DOWN)
		"plus":
			draw_line(p.call(0.5, 0.15), p.call(0.5, 0.85), FRAME, u * 0.08)
			draw_line(p.call(0.15, 0.5), p.call(0.85, 0.5), FRAME, u * 0.08)
		"chev_up":
			draw_polyline(PackedVector2Array([p.call(0.15, 0.7), p.call(0.5, 0.3), p.call(0.85, 0.7)]), GOLDEN, u * 0.12)
		"chev_down":
			draw_polyline(PackedVector2Array([p.call(0.15, 0.3), p.call(0.5, 0.7), p.call(0.85, 0.3)]), GOLDEN, u * 0.12)
		"coin":
			draw_circle(p.call(0.5, 0.5), u * 0.42, GOLDEN.darkened(0.25))
			draw_circle(p.call(0.5, 0.5), u * 0.32, GOLDEN)
		_:
			draw_rect(Rect2(p.call(0.25, 0.15), Vector2(u * 0.5, u * 0.7)), Color(0.9, 0.82, 0.62))
			for y in [0.35, 0.5, 0.65]:
				draw_line(p.call(0.33, y), p.call(0.67, y), WOOD, u * 0.03)


## The colour of a hair swatch ("kind:hair:<colour id>", see HairLook).
func _hair_color() -> Color:
	var parts := what.split(":")
	var id := parts[2] if parts.size() > 2 else "natural"
	match id:
		"black":
			return Color(0.1, 0.1, 0.12)
		"blond":
			return Color(0.95, 0.82, 0.45)
		"silver":
			return Color(0.8, 0.82, 0.86)
		"red":
			return Color(0.75, 0.15, 0.1)
		"green":
			return Color(0.2, 0.75, 0.3)
		"blue":
			return Color(0.2, 0.4, 0.95)
		"pink":
			return Color(1.0, 0.45, 0.75)
		"purple":
			return Color(0.6, 0.25, 0.85)
		"rainbow":
			return Color(1.0, 0.6, 0.2)
		"fire":
			return Color(1.0, 0.35, 0.05)
	return Color(0.42, 0.28, 0.16)
