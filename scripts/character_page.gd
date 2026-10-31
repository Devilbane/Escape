class_name CharacterPage
extends Control
## The character page (key P): a wheel. The small circle in the middle holds
## the hero's attributes: the three main ones (Stärke, Geschick, Intelligenz)
## each in the direction of its sector, the others (Konstitution, Weisheit,
## Intuition) between them, and life and speed in the very centre.
## The rings around it are cut into the six Training.SECTORS; each skill sits in
## the sector of the attributes that govern it, with its level and the chance
## of a roll on it: d100 <= (sum of the attributes / their number) x (level + 1).
## Basic skills sit in the inner ring, right around the attributes;
## advanced skills, which need basic skills first, sit in the outer ring, with
## a line to each basic skill they build on.

const SIZE := 540.0
const INNER := 114.0
## Where the ring of basic skills ends and the ring of advanced skills starts.
const MIDDLE := 196.0
const OUTER := 250.0
## Main attribute colours; a shared sector mixes the two.
const COLORS := {
	"staerke": Color(0.85, 0.3, 0.22),
	"geschick": Color(0.3, 0.75, 0.38),
	"intelligenz": Color(0.35, 0.55, 0.95),
}
const GOLD := Color(1.0, 0.82, 0.4)
const DIM := Color(0.75, 0.75, 0.8, 0.45)
## Where the other attributes sit in the middle circle: between the two
## main attributes they lie closest to.
const SECONDARY := {"konstitution": -30.0, "intuition": 90.0, "weisheit": 210.0}

var player: Player
var font: Font


func _init(hero: Player, text_font: Font) -> void:
	player = hero
	font = text_font
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The direction of a sector's middle, in degrees clockwise from the right
## (screen y points down): sector 0 is at the top.
static func sector_angle(i: int) -> float:
	return -90.0 + 60.0 * i


static func _dir(degrees: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(degrees))


func _sector_color(i: int) -> Color:
	var color := Color(0, 0, 0, 0)
	var attrs: Array = Training.SECTORS[i]
	for a in attrs:
		color += COLORS[a] / attrs.size()
	return color


func _draw() -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	# The ring of skill sectors.
	for i in Training.SECTORS.size():
		var from := sector_angle(i) - 30.0
		var points := PackedVector2Array()
		for step in 25:
			points.append(c + _dir(from + 60.0 * step / 24.0) * OUTER)
		for step in 25:
			points.append(c + _dir(from + 60.0 - 60.0 * step / 24.0) * INNER)
		var fill := _sector_color(i)
		fill.a = 0.22
		draw_colored_polygon(points, fill)
		draw_line(c + _dir(from) * INNER, c + _dir(from) * OUTER, Color(GOLD, 0.5), 2.0, true)
		_draw_sector_title(c, i)
	draw_arc(c, MIDDLE, 0.0, TAU, 96, Color(GOLD, 0.35), 1.5, true)
	draw_arc(c, OUTER, 0.0, TAU, 96, Color(GOLD, 0.7), 2.0, true)
	var places := _skill_places(c)
	for id in places:
		for basic in Training.SKILLS[id].get("needs", {}):
			if places.has(basic):
				draw_line(places[basic] + Vector2(0, 8), places[id] + Vector2(0, -6), Color(GOLD, 0.55), 1.5, true)
	# The attribute circle in the middle.
	draw_circle(c, INNER, Color(0.06, 0.04, 0.1, 0.95))
	draw_arc(c, INNER, 0.0, TAU, 96, GOLD, 3.0, true)
	for i in Training.MAIN_ATTRIBUTES.size():
		var id: String = Training.MAIN_ATTRIBUTES[i]
		var at := c + _dir(sector_angle(2 * i)) * 80.0
		_text(at + Vector2(0, -8), Lang.t(Training.ATTRIBUTES[id].name), 12, COLORS[id].lightened(0.35))
		_text(at + Vector2(0, 18), str(player.attribute(id)), 26, Color.WHITE)
	for id in SECONDARY:
		var at := c + _dir(SECONDARY[id]) * 70.0
		_text(at + Vector2(0, -5), Lang.t(Training.ATTRIBUTES[id].name), 10, Color(0.8, 0.82, 0.9))
		_text(at + Vector2(0, 14), str(player.attribute(id)), 17, Color(0.92, 0.92, 0.96))
	_text(c + Vector2(0, -20), Lang.t("Leben"), 12, GOLD)
	_text(c + Vector2(0, 4), "%d / %d" % [player.hp, player.max_hp], 22, Color(1.0, 0.55, 0.5))
	_text(c + Vector2(0, 20), "%d%%" % player.attribute("tempo"), 11, Color(0.8, 0.82, 0.9))
	_text(c + Vector2(0, 31), Lang.t("Tempo"), 9, Color(0.8, 0.82, 0.9))
	for i in Training.SECTORS.size():
		_draw_skills(i, places)


## The sector's name along the outer edge, never upside down.
func _draw_sector_title(c: Vector2, i: int) -> void:
	var angle := deg_to_rad(sector_angle(i))
	var rotation := angle + PI / 2.0
	if sin(angle) > 0.01:
		rotation -= PI
	var names := []
	for a in Training.SECTORS[i]:
		names.append(Lang.t(Training.ATTRIBUTES[a].name))
	var title: String = " · ".join(names)
	var title_color := _sector_color(i).lightened(0.45)
	draw_set_transform(c + Vector2.from_angle(angle) * (OUTER + 11.0), rotation)
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(-width / 2.0, 4.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, title_color)
	draw_set_transform(Vector2.ZERO)


## Where each skill is drawn: in its sector, in the inner ring if basic and
## the outer ring if an advanced skill, several one under the other.
func _skill_places(c: Vector2) -> Dictionary:
	var places := {}
	for i in Training.SECTORS.size():
		for t in [1, 2]:
			var ids := []
			for id in Training.SKILLS:
				if Training.sector_of(id) == i and Training.tier(id) == t:
					ids.append(id)
			var radius := (INNER + MIDDLE) / 2.0 + 4.0 if t == 1 else (MIDDLE + OUTER) / 2.0 - 4.0
			for k in ids.size():
				var shift := k - (ids.size() - 1) / 2.0
				places[ids[k]] = c + _dir(sector_angle(i)) * radius + Vector2(0, 31.0 * shift)
	return places


## The skills of a sector: name and level, then the chance of a roll.
## Skills the worn gear (or a missing basic skill) does not allow are dimmed.
## A sector without basic skills shows a dash.
func _draw_skills(i: int, places: Dictionary) -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	var has_basic := false
	for id in places:
		if Training.sector_of(id) != i:
			continue
		var basic := Training.tier(id) == 1
		has_basic = has_basic or basic
		var enabled := player.skill_enabled(id)
		var level := player.skill(id) if enabled else Training.skill_level(player.xp.get(id, 0.0), id)
		var label := "%s %d" % [Lang.t(Training.SKILLS[id].name), level]
		var at: Vector2 = places[id] + Vector2(0, -2 if enabled else 4)
		var font_size := 12 if basic else 11
		var detail := ""
		if enabled:
			detail = "%d %%" % mini(player.skill_chance(id), 100)
			var rank := Training.rank(id, level)
			if rank != "":
				detail = Lang.t(rank) + " · " + detail
		# A dark plate under the text keeps the lines to advanced skills behind it.
		var width := maxf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
				font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 10.0
		draw_rect(Rect2(at.x - width / 2.0, at.y - 13.0, width, 30.0 if enabled else 18.0), Color(0.05, 0.035, 0.08, 0.8))
		_text(at, label, font_size, Color.WHITE if enabled else DIM)
		if enabled:
			_text(at + Vector2(0, 13), detail, 11, GOLD)
	if not has_basic:
		_text(c + _dir(sector_angle(i)) * (INNER + MIDDLE) / 2.0 + Vector2(0, 5), "—", 16, DIM)


## A line of text centred on a point (the point is on the baseline).
func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(at.x - width / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
