class_name WallMap
extends RefCounted
## The template of a climbing wall (see WallRules for the climbing, WallBuild for the 3D wall and
## WallWorkshop for the editor). A grid of squares of one metre each, at least MIN_SIZE x MIN_SIZE: every
## square is one climbing step. Three layers:
## - holds: a square either has a hold or is smooth rock. A hold carries a malus 0..9 (how much harder it is
##   to take than the wall's base level) and the directions one may climb on from it (up, down, left, right),
##   so one wall can hold several routes of different difficulty, one-way slides and dead ends;
## - hazards: a surface on a square (ice, loose stones, wet moss) that fails a climber no matter how skilled;
## - gaps: rectangles of the wall that are a crack. A climber on the hold beside a gap may try to jump across
##   it along a row, if skilled enough; the gap's area in square metres is what is written beside it.
##
## The text format (also what the files in walls/ hold), `-` is smooth rock, a hold is its malus digit and
## the letters of the directions out of it (u up, d down, l left, r right), a hazard row is one letter per
## square (. none, i ice, s loose stones, w wet moss). Row 1 is the top of the wall, the last row its foot:
##
##   name: Sample face
##   level: 3
##   summit: 11_die_freiheit.txt:square   (optional: where the top of the wall leads)
##   door: 22_die_glutstollen.txt:square  (optional: where a door or secret marker leads, into a dungeon or mine; a secret
##   door looks like plain rock, with no sign, until the climber reaches it)
##   size: 24 24
##   [holds]
##   - 1udlr 2r ...          (one line per row, the squares divided by spaces)
##   [hazards]
##   ....i...s.              (one line per row)
##   [gaps]
##   9 5 3 2                 (column, row, width, height: the top left square of the gap and its size)
##   [markers]
##   9 0 garden              (column, row, kind: a goal or event on a square, see MARKERS)
##
## Lines starting with # and empty lines are ignored. tests/wall_map.gd plays it through.

## The smallest wall (squares along each side) and the largest the workshop makes.
const MIN_SIZE := 24
const MAX_SIZE := 48
## Metres of one square.
const SQUARE := 1.0
const MAX_MALUS := 9
const NO_HOLD := -1

## Directions as bit masks, and the step each takes on the grid (row 0 is the top).
const UP := 1
const DOWN := 2
const LEFT := 4
const RIGHT := 8
const ALL_DIRS := UP | DOWN | LEFT | RIGHT
const DIR_LETTERS := {"u": UP, "d": DOWN, "l": LEFT, "r": RIGHT}
const DIR_ORDER := [UP, DOWN, LEFT, RIGHT]
const DIR_STEP := {UP: Vector2i(0, -1), DOWN: Vector2i(0, 1), LEFT: Vector2i(-1, 0), RIGHT: Vector2i(1, 0)}

## The surfaces (letter in the file and the hazard layer).
const NONE := 0
const ICE := 1
const LOOSE := 2
const WET := 3
const HAZARD_LETTERS := ".isw"
## What a square can hold as a goal or an event of the climb (the id in the file, its German name and what the
## climber is told on reaching it). Only the dead climber has a body in the 3D wall so far (see WallStage); the
## others are shown by their sign and told, the game attaches what happens next.
const MARKERS := {
	"garden": {"name": "Geheimer Garten", "text": "Über der Kante liegt ein verborgener Garten.", "colour": Color(0.4, 0.8, 0.4)},
	"cave": {"name": "Höhle", "text": "Hier öffnet sich eine Höhle im Fels.", "colour": Color(0.6, 0.5, 0.8)},
	"nest": {"name": "Drachennest", "text": "Ein Drachennest! Verbrannte Knochen und warme Asche.", "colour": Color(0.9, 0.4, 0.2)},
	"tomb": {"name": "Grabkammer", "text": "Eine Grabkammer der Priester, still seit Jahrhunderten.", "colour": Color(0.85, 0.75, 0.45)},
	"tar": {"name": "Bergteer", "text": "Aus einem Riss im Fels quillt dunkles, klebriges Harz: Bergteer. Du kratzt davon ab.", "colour": Color(0.85, 0.6, 0.25)},
	"edelweiss": {"name": "Edelweiß", "text": "Auf einem schmalen Absatz blüht ein Büschel Edelweiß. Du pflückst es.", "colour": Color(0.95, 0.97, 1.0)},
	"door": {"name": "Stollentür", "text": "Eine alte Tür im Fels. Dahinter beginnt ein Stollen.", "colour": Color(0.8, 0.6, 0.35)},
	"secret": {"name": "Geheimtür", "text": "Der Fels klingt hohl. Ein Stein schwingt auf: eine verborgene Tür!", "colour": Color(0.8, 0.6, 0.35), "hidden": true},
	"camp": {"name": "Rastplatz", "text": "Ein Felsband, breit genug zum Rasten: hier kann man die Nacht verbringen (R).", "colour": Color(1.0, 0.8, 0.4)},
	"body": {"name": "Toter Kletterer", "text": "Ein toter Kletterer hängt im Seil. Seine Ausrüstung ist noch brauchbar.", "colour": Color(0.75, 0.75, 0.8)},
}

var wall_name := "Wand"
## The Klettern level of a climber who just manages a hold with malus 0.
var level := 3
## Where the top of the wall leads, as "level file:place" (see Teleport and TestPanel.PLACES, e.g.
## "11_die_freiheit.txt:square"), or "" for nothing (the climber just stands on top).
var summit := ""
## Where the door (marker "door") leads, "level file:place" like the summit; empty for a door that only shows.
var door := ""
var width := MIN_SIZE
var height := MIN_SIZE
## Per square, row by row: the malus (NO_HOLD for smooth rock), the direction mask and the hazard.
var malus := PackedInt32Array()
var dirs := PackedInt32Array()
var hazard := PackedInt32Array()
## The gaps as rectangles of squares.
var gaps: Array[Rect2i] = []
## Goals and events on squares: Vector2i -> a key of MARKERS.
var markers := {}
## What parsing found wrong (the map is still usable, with the faulty parts left out).
var parse_errors: Array[String] = []


## A wall of smooth rock.
static func blank(w := MIN_SIZE, h := MIN_SIZE) -> WallMap:
	var m := WallMap.new()
	m.resize(w, h)
	return m


## Sets the size, clearing the wall.
func resize(w: int, h: int) -> void:
	width = clampi(w, MIN_SIZE, MAX_SIZE)
	height = clampi(h, MIN_SIZE, MAX_SIZE)
	malus = PackedInt32Array()
	malus.resize(width * height)
	malus.fill(NO_HOLD)
	dirs = PackedInt32Array()
	dirs.resize(width * height)
	hazard = PackedInt32Array()
	hazard.resize(width * height)
	gaps = []
	markers = {}


## The wall's size in the same width and height, keeping what fits (the workshop's size fields).
func resized(w: int, h: int) -> WallMap:
	var out := WallMap.blank(w, h)
	out.wall_name = wall_name
	out.level = level
	out.summit = summit
	out.door = door
	for r in mini(height, out.height):
		for c in mini(width, out.width):
			out.malus[r * out.width + c] = malus[r * width + c]
			out.dirs[r * out.width + c] = dirs[r * width + c]
			out.hazard[r * out.width + c] = hazard[r * width + c]
	for cell: Vector2i in markers:
		if cell.x < out.width and cell.y < out.height:
			out.markers[cell] = markers[cell]
	for g in gaps:
		var kept := g.intersection(Rect2i(0, 0, out.width, out.height))
		if kept.size.x > 0 and kept.size.y > 0:
			out.gaps.append(kept)
	return out


func duplicate_map() -> WallMap:
	var out := WallMap.parse(to_text())
	return out


func inside(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < width and r < height


func _i(c: int, r: int) -> int:
	return r * width + c


func has_hold(c: int, r: int) -> bool:
	return inside(c, r) and malus[_i(c, r)] != NO_HOLD


func malus_at(c: int, r: int) -> int:
	return malus[_i(c, r)] if inside(c, r) else NO_HOLD


func dirs_at(c: int, r: int) -> int:
	return dirs[_i(c, r)] if has_hold(c, r) else 0


func hazard_at(c: int, r: int) -> int:
	return hazard[_i(c, r)] if inside(c, r) else NONE


## The index of the gap that covers the square, or -1.
func gap_at(c: int, r: int) -> int:
	for i in gaps.size():
		if gaps[i].has_point(Vector2i(c, r)):
			return i
	return -1


## Puts a hold on a square. A square in a gap cannot hold one (take the gap away first).
func set_hold(c: int, r: int, mal: int, mask: int) -> void:
	if not inside(c, r) or gap_at(c, r) >= 0:
		return
	malus[_i(c, r)] = clampi(mal, 0, MAX_MALUS)
	dirs[_i(c, r)] = mask & ALL_DIRS


func clear_hold(c: int, r: int) -> void:
	if inside(c, r):
		malus[_i(c, r)] = NO_HOLD
		dirs[_i(c, r)] = 0


func set_dirs(c: int, r: int, mask: int) -> void:
	if has_hold(c, r):
		dirs[_i(c, r)] = mask & ALL_DIRS


func set_hazard(c: int, r: int, kind: int) -> void:
	if inside(c, r):
		hazard[_i(c, r)] = kind


## Opens a gap (a crack) in the wall: the holds in it go. Returns its index.
func add_gap(rect: Rect2i) -> int:
	var clipped := rect.abs().intersection(Rect2i(0, 0, width, height))
	if clipped.size.x < 1 or clipped.size.y < 1:
		return -1
	for r in range(clipped.position.y, clipped.end.y):
		for c in range(clipped.position.x, clipped.end.x):
			clear_hold(c, r)
	gaps.append(clipped)
	return gaps.size() - 1


func marker_at(c: int, r: int) -> String:
	return String(markers.get(Vector2i(c, r), ""))


## Puts a marker (a key of MARKERS) on a square; "" removes it.
func set_marker(c: int, r: int, kind: String) -> void:
	if not inside(c, r):
		return
	if kind == "" or not MARKERS.has(kind):
		markers.erase(Vector2i(c, r))
	else:
		markers[Vector2i(c, r)] = kind


func remove_gap_at(c: int, r: int) -> void:
	var i := gap_at(c, r)
	if i >= 0:
		gaps.remove_at(i)


## The gap's size in square metres (what is written beside the crack).
func gap_area(index: int) -> float:
	var g := gaps[index]
	return float(g.size.x * g.size.y) * SQUARE * SQUARE


## How far a climber has to jump across the gap, in metres: its width in squares.
func gap_span(index: int) -> float:
	return float(gaps[index].size.x) * SQUARE


## Every move from a hold: the neighbouring hold in each direction that is allowed (kind "step"), and a
## jump across a gap along the row (kind "jump", carrying the gap's index and the span in metres). An
## empty list for a square without a hold.
func moves_from(c: int, r: int) -> Array:
	var out := []
	if not has_hold(c, r):
		return out
	var mask := dirs_at(c, r)
	for d: int in DIR_ORDER:
		if mask & d == 0:
			continue
		var to: Vector2i = Vector2i(c, r) + DIR_STEP[d]
		if has_hold(to.x, to.y):
			out.append({"to": to, "dir": d, "kind": "step", "gap": -1, "span": 0.0})
		elif (d == LEFT or d == RIGHT) and gap_at(to.x, to.y) >= 0:
			var gi := gap_at(to.x, to.y)
			var g := gaps[gi]
			var landing := Vector2i(g.end.x if d == RIGHT else g.position.x - 1, r)
			if has_hold(landing.x, landing.y):
				out.append({"to": landing, "dir": d, "kind": "jump", "gap": gi, "span": gap_span(gi)})
	return out


## Whether the square at the foot (the last row) is where a climb starts, and the top row where it ends.
func is_start(c: int, r: int) -> bool:
	return has_hold(c, r) and r == height - 1


func is_top(c: int, r: int) -> bool:
	return has_hold(c, r) and r == 0


## The wall's checks: what would make it unplayable (no way to the top) and what looks like a mistake.
## Each issue is {"level": "error"|"note", "text": German text, "cell": Vector2i or null}.
func validate() -> Array:
	var out := []
	var starts := 0
	var tops := 0
	for c in width:
		if is_start(c, height - 1):
			starts += 1
		if is_top(c, 0):
			tops += 1
	if starts == 0:
		out.append({"level": "error", "text": "Kein Griff in der untersten Reihe: hier fängt niemand an.", "cell": null})
	if tops == 0:
		out.append({"level": "error", "text": "Kein Griff in der obersten Reihe: hier kommt niemand an.", "cell": null})
	if starts > 0 and tops > 0 and WallRoutes.easiest(self, 99).is_empty():
		out.append({"level": "error", "text": "Kein Weg führt vom Fuß zum Gipfel.", "cell": null})
	for r in height:
		for c in width:
			if not has_hold(c, r):
				continue
			var reach := moves_from(c, r)
			if dirs_at(c, r) != 0 and reach.is_empty():
				out.append({"level": "note", "text": "Die Pfeile dieses Griffs führen ins Leere.", "cell": Vector2i(c, r)})
	for i in gaps.size():
		if not _gap_crossable(i):
			var g := gaps[i]
			out.append({"level": "note", "text": "Über diese Spalte führt kein Sprung (links und rechts fehlt ein Griff mit Pfeil zur Spalte).",
					"cell": g.position})
	return out


func _gap_crossable(index: int) -> bool:
	var g := gaps[index]
	for r in range(g.position.y, g.end.y):
		var left := Vector2i(g.position.x - 1, r)
		var right := Vector2i(g.end.x, r)
		if has_hold(left.x, left.y) and has_hold(right.x, right.y) and dirs_at(left.x, left.y) & RIGHT != 0:
			return true
		if has_hold(left.x, left.y) and has_hold(right.x, right.y) and dirs_at(right.x, right.y) & LEFT != 0:
			return true
	return false


## The wall as text (see the format above).
func to_text() -> String:
	var lines := PackedStringArray()
	lines.append("# Kletterwand: ein Feld ist ein Meter. [holds]: Malus 0-9 und Richtungen udlr, - ist glatter Fels.")
	lines.append("name: %s" % wall_name)
	lines.append("level: %d" % level)
	if summit != "":
		lines.append("summit: %s" % summit)
	if door != "":
		lines.append("door: %s" % door)
	lines.append("size: %d %d" % [width, height])
	lines.append("[holds]")
	for r in height:
		var row := PackedStringArray()
		for c in width:
			row.append(_token(c, r))
		lines.append(" ".join(row))
	lines.append("[hazards]")
	for r in height:
		var row := ""
		for c in width:
			row += HAZARD_LETTERS[hazard[_i(c, r)]]
		lines.append(row)
	lines.append("[gaps]")
	for g in gaps:
		lines.append("%d %d %d %d" % [g.position.x, g.position.y, g.size.x, g.size.y])
	lines.append("[markers]")
	var cells := markers.keys()
	cells.sort()
	for cell: Vector2i in cells:
		lines.append("%d %d %s" % [cell.x, cell.y, markers[cell]])
	return "\n".join(lines) + "\n"


func _token(c: int, r: int) -> String:
	if not has_hold(c, r):
		return "-"
	var s := str(malus[_i(c, r)])
	for letter: String in DIR_LETTERS:
		if dirs[_i(c, r)] & int(DIR_LETTERS[letter]) != 0:
			s += letter
	return s


## Reads a wall. Mistakes are listed in `parse_errors` and the faulty parts are left out.
static func parse(text: String) -> WallMap:
	var m := WallMap.new()
	var w := MIN_SIZE
	var h := MIN_SIZE
	var section := ""
	var hold_rows: Array[String] = []
	var hazard_rows: Array[String] = []
	var gap_lines: Array[String] = []
	var marker_lines: Array[String] = []
	var errors: Array[String] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("["):
			section = line
			continue
		if section == "":
			var parts := line.split(":", true, 1)
			if parts.size() < 2:
				errors.append("Unbekannte Zeile: %s" % line)
				continue
			var key := parts[0].strip_edges()
			var value := parts[1].strip_edges()
			match key:
				"name":
					m.wall_name = value
				"level":
					m.level = clampi(int(value), 1, 99)
				"summit":
					m.summit = value
				"door":
					m.door = value
				"size":
					var nums := value.split(" ", false)
					if nums.size() == 2 and nums[0].is_valid_int() and nums[1].is_valid_int():
						w = int(nums[0])
						h = int(nums[1])
					else:
						errors.append("Ungültige Größe: %s" % value)
				_:
					errors.append("Unbekannter Schlüssel: %s" % key)
		elif section == "[holds]":
			hold_rows.append(line)
		elif section == "[hazards]":
			hazard_rows.append(line)
		elif section == "[gaps]":
			gap_lines.append(line)
		elif section == "[markers]":
			marker_lines.append(line)
		else:
			errors.append("Unbekannter Abschnitt: %s" % section)
	if w < MIN_SIZE or h < MIN_SIZE or w > MAX_SIZE or h > MAX_SIZE:
		errors.append("Die Wand muss zwischen %d und %d Feldern groß sein." % [MIN_SIZE, MAX_SIZE])
	m.resize(w, h)
	for r in mini(hold_rows.size(), m.height):
		var tokens := hold_rows[r].split(" ", false)
		for c in mini(tokens.size(), m.width):
			m._read_token(c, r, tokens[c], errors)
		if tokens.size() != m.width:
			errors.append("Reihe %d hat %d statt %d Felder." % [r + 1, tokens.size(), m.width])
	if hold_rows.size() != m.height:
		errors.append("Es sind %d statt %d Reihen Griffe." % [hold_rows.size(), m.height])
	for r in mini(hazard_rows.size(), m.height):
		for c in mini(hazard_rows[r].length(), m.width):
			var k := HAZARD_LETTERS.find(hazard_rows[r][c])
			if k < 0:
				errors.append("Unbekannter Belag '%s' in Reihe %d." % [hazard_rows[r][c], r + 1])
			else:
				m.hazard[m._i(c, r)] = k
	for line in gap_lines:
		var nums := line.split(" ", false)
		if nums.size() != 4:
			errors.append("Ungültige Spalte: %s" % line)
			continue
		var rect := Rect2i(int(nums[0]), int(nums[1]), int(nums[2]), int(nums[3]))
		if m.add_gap(rect) < 0:
			errors.append("Spalte außerhalb der Wand: %s" % line)
	for line in marker_lines:
		var parts := line.split(" ", false)
		if parts.size() != 3 or not MARKERS.has(parts[2]) or not m.inside(int(parts[0]), int(parts[1])):
			errors.append("Ungültige Markierung: %s" % line)
			continue
		m.markers[Vector2i(int(parts[0]), int(parts[1]))] = parts[2]
	m.parse_errors = errors
	return m


func _read_token(c: int, r: int, token: String, errors: Array[String]) -> void:
	if token == "-":
		return
	if not token[0].is_valid_int():
		errors.append("Ungültiger Griff '%s' in Reihe %d." % [token, r + 1])
		return
	var mask := 0
	for i in range(1, token.length()):
		var letter := token[i]
		if DIR_LETTERS.has(letter):
			mask |= int(DIR_LETTERS[letter])
		else:
			errors.append("Unbekannte Richtung '%s' in Reihe %d." % [letter, r + 1])
	malus[_i(c, r)] = clampi(int(token[0]), 0, MAX_MALUS)
	dirs[_i(c, r)] = mask


## Loads a wall file (res:// or user://), or null.
static func load_file(path: String) -> WallMap:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return parse(f.get_as_text())
