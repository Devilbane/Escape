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
	if id == Mines.CRYSTAL_ID:
		return "crystal"
	if not Items.ALL.has(id):
		return "bag"
	var item: Dictionary = Items.ALL[id]
	match item.slot:
		"waffe":
			if id in ["streitkolben", "kriegshammer", "donnerhammer"]:
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
		"licht":
			return "torch_out"
		"munition":
			return "knife"
		"futter":
			return item.get("icon", "sausage")
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
		"knife":
			# A throwing knife: a slim leaf blade, a wrapped grip, a ring.
			draw_colored_polygon(PackedVector2Array([p.call(0.88, 0.12), p.call(0.62, 0.3), p.call(0.48, 0.52), p.call(0.7, 0.38)]), STEEL)
			draw_line(p.call(0.48, 0.52), p.call(0.25, 0.75), LEATHER, u * 0.09)
			draw_arc(p.call(0.2, 0.8), u * 0.07, 0.0, TAU, 12, STEEL, u * 0.04)
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
		"crystal":
			# Three glowing crystal points out of a little rock (see Mines).
			draw_colored_polygon(PackedVector2Array([p.call(0.12, 0.88), p.call(0.2, 0.74), p.call(0.8, 0.74), p.call(0.88, 0.88)]), Color(0.42, 0.44, 0.5))
			for spike in [[0.32, 0.38, 0.12], [0.52, 0.1, 0.14], [0.7, 0.32, 0.11]]:
				var x: float = spike[0]
				var w: float = spike[2]
				draw_colored_polygon(PackedVector2Array([p.call(x - w, 0.78), p.call(x, spike[1]), p.call(x + w, 0.78)]), Mines.CRYSTAL)
				draw_line(p.call(x, spike[1] + 0.06), p.call(x - w * 0.4, 0.74), Color(0.85, 0.97, 1.0), u * 0.03)
		"crate":
			draw_rect(Rect2(p.call(0.15, 0.15), Vector2(u * 0.7, u * 0.7)), WOOD)
			draw_line(p.call(0.15, 0.15), p.call(0.85, 0.85), WOOD.darkened(0.4), u * 0.06)
		"iron", "bar_bronze", "bar_silber", "bar_gold":
			# A bar of metal; the fine ones in their own colour (see Forge.METALS).
			var metal: Color = STEEL if kind_of(what) == "iron" else Forge.METALS[kind_of(what).substr(4)].color
			draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.75), p.call(0.25, 0.45), p.call(0.9, 0.45), p.call(0.75, 0.75)]), metal.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([p.call(0.25, 0.45), p.call(0.32, 0.32), p.call(0.82, 0.32), p.call(0.9, 0.45)]), metal)
		"hammer_anvil":
			draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.45), p.call(0.9, 0.45), p.call(0.7, 0.62), p.call(0.66, 0.85), p.call(0.34, 0.85), p.call(0.3, 0.62)]), STEEL.darkened(0.3))
			draw_line(p.call(0.55, 0.38), p.call(0.85, 0.08), WOOD, u * 0.07)
			draw_rect(Rect2(p.call(0.42, 0.22), Vector2(u * 0.22, u * 0.16)), STEEL)
		"flame":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.05), p.call(0.8, 0.5), p.call(0.72, 0.85), p.call(0.5, 0.95), p.call(0.28, 0.85), p.call(0.2, 0.5)]), Color(1.0, 0.5, 0.15))
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.4), p.call(0.65, 0.7), p.call(0.5, 0.88), p.call(0.35, 0.7)]), Color(1.0, 0.85, 0.3))
		"torch", "torch_out":
			# A torch held slanted: a wooden shaft, a wrapped head, and a flame
			# on it while it burns ("torch"); a dark, cold head when it is out.
			draw_line(p.call(0.3, 0.95), p.call(0.56, 0.45), WOOD, u * 0.11)
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.36), p.call(0.7, 0.42), p.call(0.62, 0.56), p.call(0.46, 0.5)]), LEATHER.darkened(0.25))
			if kind_of(what) == "torch":
				draw_colored_polygon(PackedVector2Array([p.call(0.64, 0.02), p.call(0.84, 0.3), p.call(0.74, 0.46), p.call(0.56, 0.44), p.call(0.44, 0.3)]), Color(1.0, 0.5, 0.15))
				draw_colored_polygon(PackedVector2Array([p.call(0.62, 0.18), p.call(0.72, 0.34), p.call(0.64, 0.42), p.call(0.54, 0.36)]), Color(1.0, 0.85, 0.3))
			else:
				draw_line(p.call(0.5, 0.36), p.call(0.66, 0.42), Color(0.45, 0.42, 0.4), u * 0.05)
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
		"apple":
			draw_circle(p.call(0.5, 0.58), u * 0.3, Color(0.8, 0.18, 0.15))
			draw_circle(p.call(0.4, 0.5), u * 0.08, Color(0.95, 0.5, 0.45))
			draw_line(p.call(0.5, 0.3), p.call(0.55, 0.14), WOOD, u * 0.06)
			draw_colored_polygon(PackedVector2Array([p.call(0.55, 0.22), p.call(0.78, 0.12), p.call(0.66, 0.3)]), Color(0.35, 0.7, 0.3))
		"salt":
			draw_colored_polygon(PackedVector2Array([p.call(0.15, 0.75), p.call(0.3, 0.35), p.call(0.7, 0.3), p.call(0.88, 0.72), p.call(0.5, 0.85)]), Color(0.9, 0.88, 0.84))
			draw_line(p.call(0.3, 0.35), p.call(0.5, 0.85), Color(0.7, 0.68, 0.66), u * 0.04)
			draw_line(p.call(0.5, 0.42), p.call(0.66, 0.5), Color(0.98, 0.98, 1.0), u * 0.05)
		"paw":
			# "kind:paw:fuchs": in the colour of that kind of companion.
			var parts := what.split(":")
			var paw: Color = Companions.SPECIES[parts[2]].colour if parts.size() > 2 and Companions.SPECIES.has(parts[2]) else GOLDEN
			draw_circle(p.call(0.5, 0.64), u * 0.2, paw)
			for toe in [Vector2(0.24, 0.4), Vector2(0.4, 0.24), Vector2(0.6, 0.24), Vector2(0.76, 0.4)]:
				draw_circle(p.call(toe.x, toe.y), u * 0.09, paw)
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
		"map":
			# A map folded in three, with a red route to a cross.
			var paper := Color(0.9, 0.82, 0.62)
			draw_colored_polygon(PackedVector2Array([p.call(0.06, 0.2), p.call(0.36, 0.1), p.call(0.36, 0.8), p.call(0.06, 0.9)]), paper)
			draw_colored_polygon(PackedVector2Array([p.call(0.36, 0.1), p.call(0.64, 0.2), p.call(0.64, 0.9), p.call(0.36, 0.8)]), paper.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([p.call(0.64, 0.2), p.call(0.94, 0.1), p.call(0.94, 0.8), p.call(0.64, 0.9)]), paper)
			var route := Color(0.8, 0.2, 0.15)
			draw_polyline(PackedVector2Array([p.call(0.16, 0.72), p.call(0.32, 0.52), p.call(0.5, 0.62), p.call(0.7, 0.42)]), route, u * 0.05)
			draw_line(p.call(0.72, 0.24), p.call(0.86, 0.38), route, u * 0.07)
			draw_line(p.call(0.86, 0.24), p.call(0.72, 0.38), route, u * 0.07)
		"hero":
			# Head and shoulders.
			draw_circle(p.call(0.5, 0.28), u * 0.18, GOLDEN)
			var body := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				body.append(p.call(0.5 + cos(a) * 0.36, 0.92 + sin(a) * 0.4))
			draw_colored_polygon(body, GOLDEN)
		"house":
			# A house with a gable roof and a door: home.
			draw_colored_polygon(PackedVector2Array([p.call(0.06, 0.5), p.call(0.5, 0.1), p.call(0.94, 0.5)]), GOLDEN)
			draw_rect(Rect2(p.call(0.18, 0.5), Vector2(u * 0.64, u * 0.4)), GOLDEN)
			draw_rect(Rect2(p.call(0.42, 0.62), Vector2(u * 0.16, u * 0.28)), TILE)
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
