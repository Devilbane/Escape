class_name CharacterPage
extends Control
## The character page (key P): a wheel. The circle in the middle holds the
## three main attributes (Stärke, Geschick, Intelligenz), each in the direction
## of its sector. The rings around it are cut into the six Training.SECTORS;
## each skill sits in the sector of the attributes that govern it, with its
## level and the chance of a roll on it:
## d100 <= (sum of the attributes / their number) x (level + 1).
## Basic skills sit in the inner ring, right around the attributes;
## advanced skills, which need basic skills first, sit in the outer ring, with
## a line to each basic skill they build on.
##
## The wheel shows only names and numbers, all at 16 px or more. Everything
## else (how a roll is made up, what an attribute does, why a skill is
## dimmed) shows in the details card beside it (see Menus._build_character):
## pointing at a skill or attribute shows it there, a click or tap keeps it.

## What the details card should show changed: the entry pointed at, else the
## picked one; "" for none.
signal shown_changed(id: String)

const SIZE := 580.0
const INNER := 124.0
## Where the ring of basic skills ends and the ring of advanced skills starts.
const MIDDLE := 204.0
const OUTER := 262.0
## Text sizes: names and values the player reads, and the main attributes'
## values as the wheel's focal point. Designed at 16 and 28 px, drawn at the
## game's text scale (see UiKit.TEXT_SCALE).
const TEXT_SIZE := 12
const VALUE_SIZE := 21
## A skill's plate: its name and level, and under it the chance of a roll.
const LINE := 19.0
const PLATE_PAD := Vector2(8.0, 5.0)
## A skill's name and level wider than this break over two lines.
const NAME_WIDTH := 120.0
## The gap between the plates of skills stacked in one sector.
const PLATE_GAP := 6.0
## Main attribute colours; a shared sector mixes the two.
const COLORS := {
	"staerke": Color(0.85, 0.3, 0.22),
	"geschick": Color(0.3, 0.75, 0.38),
	"intelligenz": Color(0.35, 0.55, 0.95),
}
const GOLD := Color(1.0, 0.82, 0.4)
const DIM := Color(0.75, 0.75, 0.8, 0.6)
const PLATE := Color(0.05, 0.035, 0.08, 0.85)

var player: Player
var font: Font
## The entry under the pointer and the one clicked or tapped last (a skill or
## attribute id, or "").
var hovered := ""
var picked := ""
## Where each skill and main attribute is drawn, for pointing: id -> Rect2.
var _hits := {}


func _init(hero: Player, text_font: Font) -> void:
	player = hero
	font = text_font
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Pass, so the mouse wheel still scrolls the window around it.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_hits = _layout()


## The direction of a sector's middle, in degrees clockwise from the right
## (screen y points down): sector 0 is at the top.
static func sector_angle(i: int) -> float:
	return -90.0 + 60.0 * i


static func _dir(degrees: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(degrees))


static func _sector_color(i: int) -> Color:
	var color := Color(0, 0, 0, 0)
	var attrs: Array = Training.SECTORS[i]
	for a in attrs:
		color += COLORS[a] / attrs.size()
	return color


## What the details card shows: the entry pointed at, else the picked one.
func shown() -> String:
	return hovered if hovered != "" else picked


## Points at an entry (also from outside the wheel, e.g. the attribute list
## beside it); "" when the pointer leaves.
func point(id: String) -> void:
	if id == hovered:
		return
	hovered = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" else Control.CURSOR_ARROW
	_changed()


## Keeps an entry in the details card; "" lets it go.
func pick(id: String) -> void:
	picked = id
	_changed()


func _changed() -> void:
	queue_redraw()
	shown_changed.emit(shown())


## The entry at a point of the wheel, or "".
func entry_at(at: Vector2) -> String:
	for id in _hits:
		if _hits[id].has_point(at):
			return id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		point(entry_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# A click on an empty spot lets the picked entry go.
		var id := entry_at(event.position)
		hovered = id
		pick(id)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		point("")


## Where everything that can be pointed at sits: each main attribute's block
## in the middle circle and each skill's plate in its ring.
func _layout() -> Dictionary:
	var c := Vector2(SIZE, SIZE) / 2.0
	var hits := {}
	for i in Training.MAIN_ATTRIBUTES.size():
		var at := _attribute_place(c, i)
		hits[Training.MAIN_ATTRIBUTES[i]] = Rect2(at + Vector2(-58, -30), Vector2(116, 62))
	var places := _skill_places(c)
	for id in places:
		hits[id] = _plate(id, places[id])
	return hits


## The middle of a main attribute's block: its name above, its value below.
func _attribute_place(c: Vector2, i: int) -> Vector2:
	return c + _dir(sector_angle(2 * i)) * 70.0


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
			var dir := _dir(sector_angle(i))
			# The widest plate goes where the sector is widest: outwards in the
			# top and bottom sectors, where the plates stack along the middle.
			ids.sort_custom(func(a, b): return _plate(a, Vector2.ZERO).size.x < _plate(b, Vector2.ZERO).size.x)
			if dir.y < -0.9:
				ids.reverse()
			var radius := (INNER + MIDDLE) / 2.0 if t == 1 else (MIDDLE + OUTER) / 2.0
			# One column of plates, PLATE_GAP apart: each plate's size and its
			# middle relative to the column's middle.
			var sizes := {}
			var total := PLATE_GAP * (ids.size() - 1)
			for id in ids:
				sizes[id] = _plate(id, Vector2.ZERO).size
				total += sizes[id].y
			var group := {}
			var y := -total / 2.0
			for id in ids:
				group[id] = Rect2(Vector2(-sizes[id].x / 2.0, y), sizes[id])
				y += sizes[id].y + PLATE_GAP
			var at := c + _dir(sector_angle(i)) * radius
			if t == 1 and not ids.is_empty():
				# Without advanced skills in the sector its whole ring is free.
				var taken := []
				for id in places:
					taken.append(_plate(id, places[id]))
				at = _best_place(group.values(), taken, c, dir, MIDDLE if _has_tier(i, 2) else OUTER)
			for id in group:
				places[id] = at + group[id].get_center()
	return places


## Whether a sector holds skills of a tier (1 basic, 2 advanced).
static func _has_tier(i: int, t: int) -> bool:
	for id in Training.SKILLS:
		if Training.sector_of(id) == i and Training.tier(id) == t:
			return true
	return false


## Where a sector's column of plates fits best between the middle circle and
## the ring's outer edge, inside its sector: tried along the sector's middle
## line and turned a little to each side, the place with the most room wins.
## Room is the least of: the space to the middle circle, to the ring's outer
## edge, to the plates of the sectors placed before, and (up to LINE_SLACK
## over them) to the sector's two edges. Turning away from the middle costs
## a little, so a tie stays on the middle line.
const LINE_SLACK := 10.0


func _best_place(rects: Array, taken: Array, c: Vector2, dir: Vector2, outer: float) -> Vector2:
	# The normals of the sector's two edges, pointing into the sector.
	var edges := [dir.rotated(deg_to_rad(-30.0)).rotated(PI / 2.0), dir.rotated(deg_to_rad(30.0)).rotated(-PI / 2.0)]
	var best := c + dir * (INNER + outer) / 2.0
	var best_room := -INF
	for turn in range(-15, 16, 3):
		var along := dir.rotated(deg_to_rad(turn))
		for r in range(int(INNER), int(outer) + 1, 2):
			var at := c + along * r
			var room := INF
			for rect in rects:
				var moved: Rect2 = Rect2(rect.position + at, rect.size)
				room = minf(room, _distance_to(moved, c) - INNER)
				for corner in [moved.position, moved.end, Vector2(moved.position.x, moved.end.y), Vector2(moved.end.x, moved.position.y)]:
					room = minf(room, outer - (corner - c).length())
					for normal in edges:
						room = minf(room, (corner - c).dot(normal) + LINE_SLACK)
				for other in taken:
					room = minf(room, _gap(moved, other))
			room -= absf(turn) * 0.2
			if room > best_room:
				best_room = room
				best = at
	return best


## The space between two rectangles; less than 0 when they overlap.
static func _gap(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), maxf(a.position.y - b.end.y, b.position.y - a.end.y))


## How far the nearest point of a rectangle is from a point.
static func _distance_to(rect: Rect2, point: Vector2) -> float:
	return (point.clamp(rect.position, rect.end) - point).length()


## A skill's lines: name and level (a long name broken over two lines, so
## the plate fits its sector), then the chance of a roll (with the rank of an
## advanced skill), shown in gold. No chance while the skill is dimmed.
func _skill_lines(id: String) -> Dictionary:
	var enabled := player.skill_enabled(id)
	var level := player.skill(id) if enabled else Training.skill_level(player.xp.get(id, 0.0), id)
	var name := Lang.t(Training.SKILLS[id].name)
	var label := "%s %d" % [name, level]
	var names := [label]
	var space := name.rfind(" ")
	if space > 0 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x > NAME_WIDTH:
		names = [name.substr(0, space), "%s %d" % [name.substr(space + 1), level]]
	var detail := ""
	if enabled:
		detail = "%d %%" % mini(player.skill_chance(id), 100)
		var rank := Training.rank(id, level)
		if rank != "":
			detail = Lang.t(rank) + " · " + detail
	return {"names": names, "detail": detail}


## The plate under a skill's text, around its middle point.
func _plate(id: String, at: Vector2) -> Rect2:
	var lines := _skill_lines(id)
	var shown: Array = lines.names + ([lines.detail] if lines.detail != "" else [])
	var width := 0.0
	for line in shown:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x)
	var height := LINE * shown.size()
	return Rect2(at - Vector2(width / 2.0, height / 2.0) - PLATE_PAD, Vector2(width, height) + PLATE_PAD * 2.0)


func _draw() -> void:
	_hits = _layout()
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
				draw_line(places[basic], places[id], Color(GOLD, 0.55), 1.5, true)
	# The attribute circle in the middle.
	draw_circle(c, INNER, Color(0.06, 0.04, 0.1, 0.95))
	draw_arc(c, INNER, 0.0, TAU, 96, GOLD, 3.0, true)
	for i in Training.MAIN_ATTRIBUTES.size():
		var id: String = Training.MAIN_ATTRIBUTES[i]
		var at := _attribute_place(c, i)
		if id == shown():
			_draw_frame(_hits[id])
		_text(at + Vector2(0, -8), Lang.t(Training.ATTRIBUTES[id].name), TEXT_SIZE, COLORS[id].lightened(0.4))
		_text(at + Vector2(0, 22), str(player.attribute(id)), VALUE_SIZE, Color.WHITE)
	for i in Training.SECTORS.size():
		_draw_skills(i, places)


## A gold frame round the entry the details card shows.
func _draw_frame(rect: Rect2) -> void:
	draw_rect(rect, Color(GOLD, 0.16))
	draw_rect(rect, GOLD, false, 2.0)


## The sector's name along the outer edge, never upside down.
func _draw_sector_title(c: Vector2, i: int) -> void:
	var angle := deg_to_rad(sector_angle(i))
	var rotation := angle + PI / 2.0
	var below := sin(angle) > 0.01
	if below:
		rotation -= PI
	var names := []
	for a in Training.SECTORS[i]:
		names.append(Lang.t(Training.ATTRIBUTES[a].name))
	var title: String = " · ".join(names)
	# The text sits just outside the ring: its baseline outside for the top
	# half, its cap line outside for the bottom half (where it is turned).
	draw_set_transform(c + Vector2.from_angle(angle) * (OUTER + (18.0 if below else 7.0)), rotation)
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	draw_string(font, Vector2(-width / 2.0, 0.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, _sector_color(i).lightened(0.5))
	draw_set_transform(Vector2.ZERO)


## The skills of a sector on dark plates: name and level, then the chance
## of a roll. Skills the worn gear (or a missing basic skill) does not allow
## are dimmed and show no chance. A sector without basic skills shows a dash.
func _draw_skills(i: int, places: Dictionary) -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	var has_basic := false
	for id in places:
		if Training.sector_of(id) != i:
			continue
		has_basic = has_basic or Training.tier(id) == 1
		var enabled := player.skill_enabled(id)
		var lines := _skill_lines(id)
		var plate: Rect2 = _hits[id]
		# The dark plate keeps the lines to advanced skills behind the text.
		draw_rect(plate, PLATE)
		if id == shown():
			_draw_frame(plate)
		var top := plate.position.y + PLATE_PAD.y
		var baseline := top + 14.0
		for line in lines.names:
			_text(Vector2(plate.get_center().x, baseline), line, TEXT_SIZE, Color.WHITE if enabled else DIM)
			baseline += LINE
		if lines.detail != "":
			_text(Vector2(plate.get_center().x, baseline), lines.detail, TEXT_SIZE, GOLD)
	if not has_basic:
		_text(c + _dir(sector_angle(i)) * ((INNER + MIDDLE) / 2.0 + 2.0) + Vector2(0, 6), "—", UiKit.sized(20), DIM)


## A line of text centred on a point (the point is on the baseline).
func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(at.x - width / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- The details card ---------------------------------------------------------

## What each attribute does, and what makes it grow (see Player and the
## compendium's text on attributes). The three main attributes show their
## real numbers instead (live_effects).
const ATTRIBUTE_EFFECTS := {
	"konstitution": "+1 Leben je Punkt; länger rennen und schneller heilen.",
	"tempo": "Wie schnell du gehst und rennst.",
	"intuition": "+2 % je Punkt, einen Geheimraum zu entdecken.",
	"weisheit": "5 % schneller lernen je Punkt; ab 12 bieten Schreine eine vierte Gabe.",
}
const ATTRIBUTE_GROWTH := {
	"staerke": "Wächst durch Kämpfen.",
	"konstitution": "Wächst durch Treffer, die du einsteckst.",
	"tempo": "Wächst durch Laufen und Springen.",
	"intuition": "Wächst durch Durchsuchen und Geheimnisse.",
	"geschick": "Wächst durch Springen, Werfen und Fallen.",
	"weisheit": "Wächst durch alles, was du durchstehst.",
	"intelligenz": "Wächst, wenn du Neues verstehst.",
}
## What a skill does, for skills whose use is not plain from their name.
const SKILL_EFFECTS := {
	"erkunden": "Je Stufe: +3 % Geheimräume, +3 % Fallen, +4 % Fackeln, +8 % Inschriften. Wächst mit jeder ganz erkundeten Karte.",
}
## The entry for the hit and block chances beside the wheel (see
## Menus._build_character): against a person of the hero's own level.
const ODDS := "odds"
## The entries for the hero's protection beside the wheel: Härtung (a flat
## amount off every hit) and Rüstungswert (a share off every hit).
const HARDENING := "haertung"
const ARMOUR := "ruestungswert"
## The entry for the armour set worn (see ArmourSets).
const ARMOUR_SET := "ruestungsset"


## Why a skill is dimmed: the gear it needs.
const GEAR_HINTS := {
	"klingen": "Gedimmt: braucht eine Klinge in der Hand.",
	"aexte": "Gedimmt: braucht eine Axt in der Hand.",
	"blocken": "Gedimmt: braucht einen Schild.",
	"ruestung": "Gedimmt: braucht eine Rüstung.",
}


## The details card's text for an entry: its title, its lines, and a note
## (in another colour) for how a roll works or why a skill is dimmed. With no
## entry, how a roll on a skill works.
func details(id: String) -> Dictionary:
	if id == ODDS:
		return odds_details()
	if id == HARDENING or id == ARMOUR:
		return protection_details(id)
	if id == ARMOUR_SET:
		return set_details()
	if Training.ATTRIBUTES.has(id):
		return _attribute_details(id)
	if Training.SKILLS.has(id):
		return _skill_details(id)
	return {
		"title": Lang.t("Fertigkeitsprobe"),
		"lines": [Lang.t("W100 ≤ (Summe der Eigenschaften / ihre Anzahl) × (Stufe + 1)"),
			Lang.t("Beispiel: Klingen 2, Stärke 12, Geschick 10: (12 + 10) / 2 × 3 = 33 %"),
			Lang.t("Ein Wuchttreffer (+1 Schaden) ist eine Probe auf die Waffen-Fertigkeit.")],
		"note": Lang.t("Zeig auf eine Fertigkeit oder Eigenschaft, um mehr zu sehen."),
	}


## What Härtung or Rüstungswert does, with the hero's numbers, and how much
## of it the worn armour set gives (see ArmourSets).
func protection_details(id: String) -> Dictionary:
	var kind := ArmourSets.worn(player.equipped)
	if id == HARDENING:
		var lines := [Lang.t("Wert %d: Jeder Treffer gegen dich wird um so viel schwächer.") % player.hardening,
			Lang.t("Ein Treffer behält aber mindestens die Hälfte seiner Wucht.")]
		if kind != "":
			lines.append(Lang.t("Davon +%d aus dem %s.") % [ArmourSets.hardening(player.equipped), ArmourSets.title(kind)])
		return {"title": Lang.t("Härtung"), "lines": lines,
			"note": Lang.t("Kommt von harter Rüstung, Schilden und Rüstungssets.")}
	return {"title": Lang.t("Rüstungswert"),
		"lines": [Lang.t("%d %%: Was nach der Härtung von einem Treffer übrig ist, wird um diesen Anteil kleiner.") % player.armour_value,
			Lang.t("Leichte Treffer fängt die Rüstung so manchmal ganz ab."),
			Lang.t("Höchstens %d %%.") % Player.ARMOUR_VALUE_MAX],
		"note": Lang.t("Kommt von Helm, Rüstung, Handschuhen und Schuhen. Stoff schützt wenig, Stahl und Schuppen viel.")}


## The armour set worn and what it gives, or how close the hero is to one.
func set_details() -> Dictionary:
	var kind := ArmourSets.worn(player.equipped)
	var lines := []
	if kind != "":
		lines.append(Lang.t("Du trägst das %s: %s.") % [ArmourSets.title(kind), ArmourSets.bonus_text(kind)])
	else:
		var near := ArmourSets.closest(player.equipped)
		lines.append(Lang.t("Du trägst kein ganzes Set.") if near == "" else
				Lang.t("%s: %d von %d Teilen.") % [ArmourSets.title(near), ArmourSets.pieces_worn(player.equipped, near), ArmourSets.PIECES.size()])
	lines.append(Lang.t("Helm, Rüstung, Handschuhe und Schuhe aus einem Material ergeben ein Set. Der Umhang zählt nicht."))
	lines.append(Lang.t("Stoff und Leder geben mehr Geschick, Eisen und Stahl mehr Härtung, Schuppen beides."))
	return {"title": Lang.t("Rüstungsset"), "lines": lines,
		"note": Lang.t("Das beste Set: Drachenschuppen, +3 Geschick und +4 Härtung.")}


func _attribute_details(id: String) -> Dictionary:
	var a: Dictionary = Training.ATTRIBUTES[id]
	var value := player.attribute(id)
	var unit := "%" if id == "tempo" else ""
	var lines := [Lang.t("Wert %d%s, höchstens %d%s") % [value, unit, a.max, unit]]
	if id == "geschick" and ArmourSets.dexterity(player.equipped) > 0:
		var kind := ArmourSets.worn(player.equipped)
		lines[0] += " " + Lang.t("(+%d aus dem %s)") % [ArmourSets.dexterity(player.equipped), ArmourSets.title(kind)]
	var live := live_effects(id)
	lines.append_array(live if not live.is_empty() else [Lang.t(ATTRIBUTE_EFFECTS.get(id, ""))])
	if id == "tempo":
		lines.append(Lang.t("Grundtempo mit Ausrüstung: %d %%") % roundi(minf(player.base_speed_wanted, Player.BASE_SPEED_CAP) * 100.0)
				+ (" " + Lang.t("(Höchstgrenze %d %%, Rennen zählt obendrauf)") % roundi(Player.BASE_SPEED_CAP * 100.0) if player.base_speed_capped else ""))
	var governs := []
	for skill in Training.SKILLS:
		if Training.SKILLS[skill].attributes.has(id):
			governs.append(Lang.t(Training.SKILLS[skill].name))
	if not governs.is_empty():
		lines.append(Lang.t("Bestimmt: %s") % ", ".join(governs))
	var note := Lang.t(ATTRIBUTE_GROWTH[id])
	if value < a.max:
		note += " " + Lang.t("Noch %d %% bis zum nächsten Punkt.") % (100 - floori(Training.attribute_progress(id, player.xp.get(id, 0.0)) * 100.0))
	return {"title": Lang.t(a.name), "lines": lines, "note": note}


## What a main attribute does for the hero right now, with the real numbers
## and what one more point adds (see Player); empty for the others.
func live_effects(id: String) -> Array:
	match id:
		"staerke":
			return [Lang.t("Nahkampf: +%d Schaden, Hieb %d (+1 je Punkt)") % [player.strength_points(), player.power],
				Lang.t("Lasten wiegen für dich nur %d %%") % roundi(100.0 * Training.ATTRIBUTES.staerke.start / player.attribute("staerke"))]
		"geschick":
			var dodge := roundi(player.dodge_chance() * 100.0)
			var per := roundi(Player.DODGE_PER_DEXTERITY * 100.0)
			return [Lang.t("Messerwurf: +%d Schaden, Wurf %d (+1 je Punkt)") % [player.dexterity_points(), player.throw_power()],
				Lang.t("Ausweichen: %d %% (+%d %% je Punkt, bis %d %%)") % [dodge, per, roundi(Player.DODGE_MAX * 100.0)],
				Lang.t("Stacheln: %d %% ausweichen; Sprünge +%d %%") % [mini(100, per * player.dexterity_points()), roundi(Player.JUMP_PER_DEXTERITY * 100.0 * player.dexterity_points())]]
		"intelligenz":
			return [Lang.t("Fertigkeiten lernen +%d %% schneller (+%d %% je Punkt)") % [roundi(player.skill_learning_bonus() * 100.0), roundi(Player.SKILL_LEARNING_PER_INTELLIGENCE * 100.0)],
				Lang.t("Erfahrung, auch aus Rätseln: +%d %% (+%d %% je Punkt)") % [roundi(Player.XP_PER_INTELLIGENCE * 100.0 * player.intelligence_points()), roundi(Player.XP_PER_INTELLIGENCE * 100.0)]]
	return []


func _skill_details(id: String) -> Dictionary:
	var skill: Dictionary = Training.SKILLS[id]
	var enabled := player.skill_enabled(id)
	var xp: float = player.xp.get(id, 0.0)
	var level := player.skill(id) if enabled else Training.skill_level(xp, id)
	var lines := []
	if Training.tier(id) == 2:
		var rank := Training.rank(id, level)
		lines.append(Lang.t("Fortgeschrittene Fertigkeit, Stufe %d von %d") % [level, Training.skill_max(id)]
				+ ("" if rank == "" else " (%s)" % Lang.t(rank)))
		lines.append(Lang.t("Novize, Fortgeschritten, Meister: je 3 Stufen."))
	else:
		lines.append(Lang.t("Grundfertigkeit, Stufe %d von %d") % [level, Training.skill_max(id)])
	var names := []
	var values := []
	for a in skill.attributes:
		names.append(Lang.t(Training.ATTRIBUTES[a].name))
		values.append(str(player.attribute(a)))
	lines.append(Lang.t("Bestimmt von: %s") % ", ".join(names))
	if SKILL_EFFECTS.has(id):
		lines.append(Lang.t(SKILL_EFFECTS[id]))
	elif id == "werfen":
		lines.append(Lang.t("Griffbereit: %d Wurfmesser (3, und eines mehr je zwei Stufen)") % player.knife_cap())
	if Training.skill_level(xp, id) < Training.skill_max(id):
		lines.append(Lang.t("Noch %d %% Übung bis zur nächsten Stufe.") % (100 - floori(Training.skill_progress(xp, id) * 100.0)))
	var note := ""
	if enabled:
		var average: String = values[0] if values.size() == 1 else "(%s) / %d" % [" + ".join(values), values.size()]
		note = Lang.t("Probe: %d %% = %s × %d") % [mini(player.skill_chance(id), 100), average, level + 1]
	else:
		note = _dimmed_reason(id)
	return {"title": Lang.t(skill.name), "lines": lines, "note": note}


## Why a skill cannot be used now: an attribute too low, a basic skill not
## learned far enough, or the gear it needs.
func _dimmed_reason(id: String) -> String:
	var skill: Dictionary = Training.SKILLS[id]
	var requires: Dictionary = skill.get("requires", {})
	for a in requires:
		if player.attribute(a) < int(requires[a]):
			return Lang.t("Gedimmt: braucht %s %d.") % [Lang.t(Training.ATTRIBUTES[a].name), int(requires[a])]
	var needs: Dictionary = skill.get("needs", {})
	for basic in needs:
		if Training.skill_level(player.xp.get(basic, 0.0), basic) < int(needs[basic]):
			return Lang.t("Gedimmt: braucht erst %s %d.") % [Lang.t(Training.SKILLS[basic].name), int(needs[basic])]
	return Lang.t(GEAR_HINTS.get(id, "Gedimmt: braucht passende Ausrüstung"))


## The hero's odds against a person of the hero's own level, or of the
## world's top above it (see HeroLevel.measured, Enemy.reference_foe and
## Player.odds_against).
func odds() -> Dictionary:
	var foe := Enemy.reference_foe(HeroLevel.measured(player.hero_level()))
	var o := player.odds_against(foe)
	o.foe = foe
	return o


static func percent(chance: float) -> String:
	return "%d %%" % roundi(chance * 100.0)


## The details card for the hit and block chances: what the reference foe
## has, and how each chance is made up.
func odds_details() -> Dictionary:
	var o := odds()
	var foe: Dictionary = o.foe
	var lines := [
		Lang.t("Halsabschneider, Stufe %d: %d Leben, %d Schaden je Hieb.") % [foe.level, foe.hp, foe.damage],
		Lang.t("Treffer: %s, in Reichweite immer.") % percent(o.hit),
		Lang.t("Wuchttreffer (+1): %s, Probe auf %s.") % [percent(o.heavy), Lang.t(Training.SKILLS[o.weapon].name)],
		(Lang.t("Block: %s mit deinem Schild.") % percent(o.block)) if player.equipped.has("schild")
				else Lang.t("Block: 0 %, du trägst keinen Schild."),
		Lang.t("Ausweichen: %s der übrigen Hiebe.") % percent(o.dodge),
	]
	return {
		"title": Lang.t("Treffer und Block"),
		"lines": lines,
		"note": (Lang.t("Er trifft dich bei %s seiner Hiebe nicht. Du fällst ihn mit einem Hieb.") % percent(o.unharmed)) if o.blows <= 1
				else Lang.t("Er trifft dich bei %s seiner Hiebe nicht. Du fällst ihn in höchstens %d Hieben.") % [percent(o.unharmed), o.blows],
	}
