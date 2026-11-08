class_name LevelMap
extends RefCounted
## A map file as the map workshop (see LevelEditor) edits it: its header lines
## and its grid of letters, read from and written back to the very format of
## the files in levels/ (see Level.load_from_file), plus the checks that
## tell whether the map can be played (see validate).

## The header lines the game reads (see Level.load_from_file, Creations,
## Traps.parse_header). Any other line is a row of the map.
const KEYS := ["name", "hint", "secret", "monsters", "safe", "elite", "building", "lair", "dark", "horror",
		"home", "theme", "walls", "down", "up", "seal", "inn", "floor", "outdoor", "fountain", "traps", "writing", "custom",
		"respawn", "sure", "hatch"]
## Tiles the hero cannot walk through (walls and Level.FURNITURE); "?" (a
## secret wall), "Q" (a block that can be pushed) and "x" (crates, which the
## hero can pick up) are left out.
const SOLID := "(#botkCHBLmhVFfy=U~"
## The biggest map the workshop makes: a dungeon, and the open air (the
## village map is 172 x 46).
const MAX_SIZE := Vector2i(80, 60)
const MAX_OUTDOOR_SIZE := Vector2i(240, 120)

## [key, value] in the order of the file.
var headers: Array = []
var grid: Array[String] = []


static func parse(text: String) -> LevelMap:
	var m := LevelMap.new()
	for line in text.split("\n"):
		line = line.strip_edges(false, true)
		var key := header_key(line)
		if key != "":
			m.headers.append([key, line.substr(key.length() + 1).strip_edges()])
		elif line != "":
			m.grid.append(line)
	return m


static func load_file(path: String) -> LevelMap:
	return parse(FileAccess.get_file_as_string(path))


## A new map: walls round a room of floor, the start and the stairs.
static func blank(w := 16, h := 10) -> LevelMap:
	var m := LevelMap.new()
	m.headers = [["name", "Neue Karte"], ["hint", ""], ["secret", "normal"]]
	for y in h:
		var row := ""
		for x in w:
			row += "#" if x == 0 or y == 0 or x == w - 1 or y == h - 1 else "."
		m.grid.append(row)
	m.set_cell(Vector2i(w / 2, 1), "E")
	m.set_cell(Vector2i(w / 2, h - 2), "P")
	m.set_cell(Vector2i(w / 2, 0), "#")
	return m


## The key of a header line ("name: ..." -> "name"), or "".
static func header_key(line: String) -> String:
	var colon := line.find(":")
	if colon <= 0:
		return ""
	var key := line.substr(0, colon)
	return key if key in KEYS else ""


func to_text() -> String:
	var lines: Array[String] = []
	for h in headers:
		lines.append("%s: %s" % [h[0], h[1]] if str(h[1]) != "" else "%s:" % h[0])
	for row in grid:
		lines.append(row.strip_edges(false, true))
	return "\n".join(lines) + "\n"


# --- Headers ----------------------------------------------------------------

func get_header(key: String, default := "") -> String:
	for h in headers:
		if h[0] == key:
			return h[1]
	return default


func has_header(key: String) -> bool:
	return headers.any(func(h): return h[0] == key)


## Sets a header ("" removes it). A new one goes after the others of its kind.
func set_header(key: String, value: String) -> void:
	for i in headers.size():
		if headers[i][0] == key:
			if value == "" and key != "hint":
				headers.remove_at(i)
			else:
				headers[i][1] = value
			return
	if value != "" or key == "hint":
		headers.insert(_insert_at(key), [key, value])


## A yes/no header such as "dark: ja".
func set_flag(key: String, on: bool) -> void:
	set_header(key, "ja" if on else "")


func _insert_at(key: String) -> int:
	var order := KEYS.find(key)
	for i in headers.size():
		if KEYS.find(headers[i][0]) > order:
			return i
	return headers.size()


func is_outdoor() -> bool:
	return has_header("outdoor")


## The letters this kind of map may use (see Tiles).
func table() -> Dictionary:
	return Tiles.OUTDOOR if is_outdoor() else Tiles.DUNGEON


# --- Creations --------------------------------------------------------------

## letter -> spec of every "custom:" line (see Creations).
func creations() -> Dictionary:
	var out := {}
	for h in headers:
		if h[0] == "custom":
			var c := Creations.parse_line(Creations.HEADER + " " + str(h[1]))
			if not c.is_empty():
				out[c.letter] = c.spec
	return out


## Sets the creation on a letter ({} removes it).
func set_creation(letter: String, spec: Dictionary) -> void:
	for i in headers.size():
		if headers[i][0] == "custom" and str(headers[i][1]).begins_with(letter + " "):
			if spec.is_empty():
				headers.remove_at(i)
			else:
				headers[i][1] = Creations.to_line(letter, spec).substr(Creations.HEADER.length() + 1)
			return
	if not spec.is_empty():
		headers.insert(_insert_at("custom"), ["custom", Creations.to_line(letter, spec).substr(Creations.HEADER.length() + 1)])


# --- The grid ---------------------------------------------------------------

func width() -> int:
	var w := 0
	for row in grid:
		w = maxi(w, row.length())
	return w


func height() -> int:
	return grid.size()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width() and c.y < height()


## The letter on a tile; a blank or a tile past the end of a row is wall.
func cell(c: Vector2i) -> String:
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= grid[c.y].length():
		return "#"
	var ch := grid[c.y][c.x]
	return "#" if ch == " " else ch


func set_cell(c: Vector2i, ch: String) -> void:
	if c.x < 0 or c.y < 0 or c.y >= grid.size():
		return
	var row := grid[c.y]
	while row.length() <= c.x:
		row += "#"
	grid[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


## Grows or crops the map to w x h; new tiles are wall.
func resize(w: int, h: int) -> void:
	w = clampi(w, 3, max_size().x)
	h = clampi(h, 3, max_size().y)
	while grid.size() < h:
		grid.append("#".repeat(w))
	grid.resize(h)
	for y in h:
		var row := grid[y]
		row = row.substr(0, w) if row.length() > w else row + "#".repeat(w - row.length())
		grid[y] = row


## Every tile with the letter ch.
func find_all(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in grid.size():
		var row := grid[y]
		var x := row.find(ch)
		while x >= 0:
			out.append(Vector2i(x, y))
			x = row.find(ch, x + 1)
	return out


## The pressure plates that get no heavy block of their own: each block
## (Q) can reach the plates within 5 tiles of it (middle to middle), and
## one block serves one plate. Empty when every plate can be pressed.
func plates_out_of_reach() -> Array[Vector2i]:
	# On the open-air map "_" is the village wall, not a pressure plate.
	if is_outdoor():
		return []
	var plates := find_all("_")
	var blocks := find_all("Q")
	var holder := {}
	var out: Array[Vector2i] = []
	for p in plates:
		if not _give_block(p, plates, blocks, holder, {}):
			out.append(p)
	return out


## Finds a block for plate `p`, moving another plate onto a different block
## where that frees one (a matching by augmenting paths).
func _give_block(p: Vector2i, plates: Array[Vector2i], blocks: Array[Vector2i], holder: Dictionary, seen: Dictionary) -> bool:
	for b in blocks:
		if seen.has(b) or Vector2(p - b).length() > 5.0:
			continue
		seen[b] = true
		if not holder.has(b) or _give_block(holder[b], plates, blocks, holder, seen):
			holder[b] = p
			return true
	return false


func count(ch: String) -> int:
	return find_all(ch).size()


func max_size() -> Vector2i:
	return MAX_OUTDOOR_SIZE if is_outdoor() else MAX_SIZE


# --- Checks -----------------------------------------------------------------

## What stands in the way of playing the map: {"error": bool, "text",
## "args", "cell"} (cell (-1, -1) when the issue has no tile). Errors stop the
## game from working as it should; the rest are hints. "text" is German with
## places for "args" (see describe).
func validate() -> Array:
	var out: Array = []
	var add := func(error: bool, text: String, at := Vector2i(-1, -1), args := []):
		out.append({"error": error, "text": text, "args": args, "cell": at})
	var table := table()
	var made := creations() if not is_outdoor() else {}
	if grid.is_empty():
		add.call(true, "Die Karte ist leer.")
		return out
	# Letters the game does not know.
	var unknown := {}
	for y in grid.size():
		for x in grid[y].length():
			var ch := grid[y][x]
			var creation_letter := not is_outdoor() and Creations.LETTERS.contains(ch)
			if ch == " " or unknown.has(ch) or made.has(ch) or (table.has(ch) and not creation_letter):
				continue
			unknown[ch] = true
			if Creations.LETTERS.contains(ch) and not is_outdoor():
				add.call(true, "Auf der %s steht kein Geschöpf.", Vector2i(x, y), [ch])
			else:
				add.call(true, "Das Zeichen „%s“ kennt das Spiel nicht.", Vector2i(x, y), [ch])
	var starts := find_all("P")
	if starts.is_empty():
		add.call(true, "Es gibt keinen Start (P).")
	elif starts.size() > 1:
		add.call(true, "Es gibt %d Starts (P), erlaubt ist einer.", starts[1], [starts.size()])
	if get_header("name") == "":
		add.call(false, "Die Karte hat keinen Namen.")
	_check_families(add, made)
	if is_outdoor():
		return out
	var exits := find_all("E")
	if exits.is_empty():
		add.call(true, "Es gibt keinen Ausgang (E).")
	elif exits.size() > 1:
		add.call(false, "Es gibt %d Ausgänge (E); nur einer führt hinaus.", exits[1], [exits.size()])
	if get_header("hint") == "":
		add.call(false, "Die Karte hat keinen Hinweis für den Spieler.")
	var doors := find_all("D")
	var keys := find_all("K")
	var guards := find_all("W")
	for letter in made:
		if made[letter].type == "monster" and made[letter].base == "waechter":
			guards.append_array(find_all(letter))
	if not doors.is_empty() and keys.is_empty() and guards.is_empty():
		add.call(true, "Eine Tür (D), aber kein Schlüssel (K) und kein Wächter, der ihn trägt.", doors[0])
	if doors.is_empty() and not keys.is_empty():
		add.call(false, "Ein Schlüssel (K), aber keine Tür (D).", keys[0])
	# The block puzzle: gates sink once every plate holds a heavy block.
	# (On the open-air map "_" is the village wall and "|" the gate of Sternhall.)
	var plates := 0 if is_outdoor() else count("_")
	var gates: Array[Vector2i] = [] if is_outdoor() else find_all("|")
	if not gates.is_empty() and plates == 0:
		add.call(true, "Ein Gitter (|), aber keine Druckplatte (_), die es öffnet.", gates[0])
	if plates > 0 and gates.is_empty():
		add.call(false, "Druckplatten (_), aber kein Gitter (|), das sie öffnen.", find_all("_")[0])
	if plates > count("Q"):
		add.call(true, "%d Druckplatten, aber nur %d Steinblöcke (Q).", find_all("_")[0], [plates, count("Q")])
	elif plates > 0:
		# A heavy block moves at most 5 tiles from where it lies (see
		# Level.HEAVY_RANGE): every plate needs a block of its own in range.
		var lonely := plates_out_of_reach()
		if not lonely.is_empty():
			add.call(true, "Keine Druckplatte darf weiter als 5 Felder von einem eigenen Steinblock (Q) liegen.", lonely[0])
	for letter in made:
		if count(letter) == 0:
			add.call(false, "„%s“ (%s) steht nirgends auf der Karte.", Vector2i(-1, -1), [Creations.label_of(made[letter]), letter])
	for c in exits:
		if not is_outdoor() and not has_header("home") and cell(c + Vector2i(0, -1)) != "#":
			add.call(false, "Die Treppe steigt nach Norden: über dem Ausgang gehört Wand hin.", c)
	if starts.size() != 1:
		return out
	# Can the hero get out? First without the key, then with it if it lies
	# on the way (or a guardian on the way carries it).
	var gate_open := plates > 0 and plates <= count("Q")
	var reach := reachable(starts[0], false, gate_open)
	var has_key := keys.any(func(k): return reach.has(k)) or guards.any(func(g): return reach.has(g))
	if has_key and not doors.is_empty():
		reach = reachable(starts[0], true, gate_open)
	for c in exits:
		if not reach.has(c):
			if has_key or doors.is_empty():
				add.call(true, "Der Ausgang ist vom Start aus nicht zu erreichen.", c)
			else:
				add.call(true, "Der Ausgang ist nicht zu erreichen: der Schlüssel liegt hinter der Tür oder fehlt.", c)
	for c in keys:
		if not reach.has(c):
			add.call(false, "Der Schlüssel ist nicht zu erreichen.", c)
	var lost := 0
	var first := Vector2i(-1, -1)
	for ch in "cCkK":
		for c in find_all(ch):
			if not reach.has(c):
				lost += 1
				if lost == 1:
					first = c
	if lost > 0:
		add.call(false, "%d Schätze liegen, wo niemand hinkommt.", first, [lost])
	return out


## Whether each monster on the map belongs where the header "monsters:" says
## (see MonsterFamilies): hints only, a map plays either way.
func _check_families(add: Callable, made: Dictionary) -> void:
	var value := get_header(MonsterFamilies.HEADER)
	for name in MonsterFamilies.unknown(value):
		add.call(false, "„%s“ ist keine Monsterfamilie.", Vector2i(-1, -1), [name])
	var families := MonsterFamilies.parse(value)
	var letters: Dictionary = Enemy.WILD_LETTERS if is_outdoor() else Enemy.LETTERS
	var named: Dictionary = EditorPalette.OUTDOOR_NAMES if is_outdoor() else EditorPalette.NAMES
	var told := {}
	for y in grid.size():
		for x in grid[y].length():
			var ch := grid[y][x]
			if told.has(ch):
				continue
			var kind := ""
			var label := ""
			if letters.has(ch):
				kind = letters[ch]
				label = Lang.t(named.get(ch, kind))
			elif made.has(ch) and made[ch].type == "monster":
				kind = made[ch].base
				label = Creations.label_of(made[ch])
			if kind == "" or MonsterFamilies.fits(kind, families):
				continue
			told[ch] = true
			if families.is_empty():
				add.call(false, "Die Karte sagt nicht, welche Monster hier leben (Bewohner).", Vector2i(x, y))
				return
			var family := MonsterFamilies.family_of(kind)
			add.call(false, "%s (%s) lebt hier nicht: Hake die Familie unter Bewohner an.", Vector2i(x, y),
					[label, Lang.t(MonsterFamilies.FAMILIES.get(family, family))])


## An issue of validate in the player's language.
static func describe(issue: Dictionary) -> String:
	var args: Array = issue.get("args", [])
	return Lang.t(issue.text) % args if not args.is_empty() else Lang.t(issue.text)


## Whether anything in the list is an error.
static func has_errors(issues: Array) -> bool:
	return issues.any(func(i): return i.error)


## Every tile the hero can reach from `from`; doors only with the key, gates
## only when the plates can be held down. Secret walls count as found.
func reachable(from: Vector2i, doors_open: bool, gates_open: bool) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	var made := creations()
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not in_bounds(n):
				continue
			var ch := cell(n)
			if SOLID.contains(ch) or (ch == "D" and not doors_open) or (ch == "|" and not gates_open):
				# Things that stand in the way can still be reached (searched,
				# used) from beside them: they count, but lead nowhere.
				if not "#=~".contains(ch):
					seen[n] = true
				continue
			if made.has(ch) and made[ch].type == "npc":
				seen[n] = true
				continue
			seen[n] = true
			todo.append(n)
	return seen
