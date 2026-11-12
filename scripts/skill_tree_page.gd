class_name SkillTreePage
extends Control
## One tree of the skill tree window (see Menus._build_skill_trees): every
## skill of the tree is shown at once on a canvas of a fixed size, masters on
## top, advanced skills in the middle and basic skills at the bottom, with a
## line from each skill to the skills of this tree it needs. A skill that needs
## a skill of another tree carries a star. Pointing at a skill shows it in the
## details card, a click keeps it there.
##
## A plate always says what the skill is in words (its level, "open", "locked"
## or "not in the game yet") and never by colour alone. The canvas has the same
## size for every tree, so switching trees never reshapes the window.

signal shown_changed(id: String)

const WIDTH := 860.0
const HEIGHT := 270.0
## The most plates a row holds: the widest tree has five basic skills.
const COLUMNS := 5
const PLATE_SIZE := Vector2(156.0, 58.0)
## Master skills stand on top, basic skills at the bottom.
const ROW_TOP := {"master": 4.0, "advanced": 106.0, "basic": 208.0}
const GOLD := Color(1.0, 0.82, 0.4)
const WHITE := Color(0.92, 0.92, 0.96)
const DIM := Color(0.66, 0.66, 0.74)
const PLATE := Color(0.05, 0.035, 0.08, 0.9)
const NAME_SIZE := 16
const LINE_SIZE := 16

var hero: Player
var font: Font
var tree := ""
var hovered := ""
var picked := ""
## Where each plate is drawn, for pointing: skill id -> Rect2.
var _hits := {}


func _init(for_hero: Player, text_font: Font, tree_id: String, pick_id := "") -> void:
	hero = for_hero
	font = text_font
	tree = tree_id
	picked = pick_id
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Pass, so the mouse wheel still scrolls the window around it.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_hits = layout(tree)


## Where each skill of a tree stands: skill id -> Rect2. Every row is centred.
static func layout(tree_id: String) -> Dictionary:
	var places := {}
	for row in SkillTrees.ROWS:
		var ids := SkillTrees.in_row(tree_id, row)
		var gap := (WIDTH - COLUMNS * PLATE_SIZE.x) / (COLUMNS - 1)
		var span := ids.size() * PLATE_SIZE.x + (ids.size() - 1) * gap
		var x := (WIDTH - span) / 2.0
		for id in ids:
			places[id] = Rect2(Vector2(x, ROW_TOP[row]), PLATE_SIZE)
			x += PLATE_SIZE.x + gap
	return places


## What the details card shows: the skill pointed at, else the picked one.
func shown() -> String:
	return hovered if hovered != "" else picked


func point(id: String) -> void:
	if id == hovered:
		return
	hovered = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" else Control.CURSOR_ARROW
	queue_redraw()
	shown_changed.emit(shown())


func pick(id: String) -> void:
	picked = id
	queue_redraw()
	shown_changed.emit(shown())


func skill_at(at: Vector2) -> String:
	for id in _hits:
		if _hits[id].has_point(at):
			return id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		point(skill_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hovered = skill_at(event.position)
		pick(hovered)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		point("")


## The second line of a plate.
func plate_line(id: String) -> String:
	match SkillTrees.status(hero, id):
		"known":
			return Lang.t("Stufe %d") % SkillTrees.level_of(hero, id)
		"open":
			return Lang.t("Offen")
		"locked":
			return Lang.t("Gesperrt")
	return Lang.t("Noch nicht im Spiel")


func _draw() -> void:
	_hits = layout(tree)
	# The lines first, under the plates: from the top of a skill down to the
	# bottom of each skill of this tree it needs.
	for id in _hits:
		for need in SkillTrees.ALL[id].get("needs", {}):
			if _hits.has(need):
				var from: Rect2 = _hits[need]
				var to: Rect2 = _hits[id]
				draw_line(Vector2(from.position.x + from.size.x / 2.0, from.position.y),
						Vector2(to.position.x + to.size.x / 2.0, to.position.y + to.size.y), Color(GOLD, 0.45), 1.5, true)
	for id in _hits:
		_draw_plate(id, _hits[id])


func _draw_plate(id: String, rect: Rect2) -> void:
	var status := SkillTrees.status(hero, id)
	var color := GOLD if status == "known" else (WHITE if status == "open" else DIM)
	draw_rect(rect, PLATE)
	if id == shown():
		draw_rect(rect, Color(GOLD, 0.16))
	draw_rect(rect, Color(color, 0.9 if id == shown() else 0.55), false, 3.0 if id == shown() else 1.5)
	var name := Lang.t(SkillTrees.name_of(id))
	if SkillTrees.crosses_trees(id):
		name += " *"
	var size := UiKit.sized(NAME_SIZE)
	while size > 8 and font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x - 12.0:
		size -= 1
	draw_string(font, rect.position + Vector2(8.0, 24.0), name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, size, color)
	draw_string(font, rect.position + Vector2(8.0, 46.0), plate_line(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0,
			UiKit.sized(LINE_SIZE), Color(color, 0.85))


# --- The details card ----------------------------------------------------------

## The details card's text for a skill: title, lines and a note. With no skill,
## how to read the tree.
func details(id: String) -> Dictionary:
	if id == "" or not SkillTrees.ALL.has(id):
		return {"title": Lang.t(SkillTrees.tree_name(tree)), "lines": [
			Lang.t("Unten die Grundfertigkeiten, in der Mitte die fortgeschrittenen, oben die Meister."),
			Lang.t("Eine Linie führt von dem, was gebraucht wird, zu der Fertigkeit, die es öffnet. Ein Stern * braucht eine Fertigkeit aus einem anderen Baum."),
		], "note": Lang.t("Zeig auf eine Fertigkeit, um mehr zu sehen.")}
	var skill: Dictionary = SkillTrees.ALL[id]
	var lines := []
	var row_text := ""
	match skill.row:
		"basic":
			row_text = Lang.t("Grundfertigkeit")
		"advanced":
			row_text = Lang.t("Fortgeschrittene Fertigkeit")
		_:
			row_text = Lang.t("Meisterfertigkeit")
	var status := SkillTrees.status(hero, id)
	if SkillTrees.in_game(id):
		lines.append(Lang.t("%s, Stufe %d von %d (im fertigen Baum %d)") % [row_text, SkillTrees.level_of(hero, id), SkillTrees.level_cap(id), skill.levels])
	else:
		lines.append(Lang.t("%s, im fertigen Baum %d Stufen") % [row_text, skill.levels])
	var names := []
	for a in skill.attributes:
		names.append(Lang.t(Training.ATTRIBUTES[a].name))
	lines.append(Lang.t("Bestimmt von: %s") % ", ".join(names))
	lines.append(_needs_line(id))
	var opened := []
	for other in SkillTrees.opens(id):
		opened.append(Lang.t(SkillTrees.name_of(other)))
	if not opened.is_empty():
		lines.append(Lang.t("Öffnet: %s") % ", ".join(opened))
	var note := ""
	if status == "planned":
		note = Lang.t("Noch nicht im Spiel: Dieser Baum wächst Stück für Stück.")
	elif status == "locked":
		note = Lang.t("Gesperrt: es fehlt noch etwas.")
	elif Training.SKILLS.has(id):
		# How the hero feels about it, in their own words (see SleepRoll).
		# The crafts do not wait for a night yet.
		note = "„%s“" % SleepRoll.tip(hero.sleep_state, id, hero.xp)
	return {"title": Lang.t(SkillTrees.name_of(id)), "lines": lines, "note": note}


## "Braucht: Klingen 10 (du: 3), Geschick 18" or "Braucht nichts."
func _needs_line(id: String) -> String:
	var needs := SkillTrees.needs_of(id)
	if needs.is_empty():
		return Lang.t("Braucht nichts.")
	var parts := []
	for entry in needs:
		var name := Lang.t(SkillTrees.name_of(entry.id)) if entry.skill else Lang.t(Training.ATTRIBUTES[entry.id].name)
		var have := SkillTrees.level_of(hero, entry.id) if entry.skill else hero.attribute(entry.id)
		parts.append("%s %d%s" % [name, entry.level, " ✓" if have >= entry.level else ""])
	return Lang.t("Braucht: %s") % ", ".join(parts)
