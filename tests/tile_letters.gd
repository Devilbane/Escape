extends SceneTree
## Headless test for the map letters (see Tiles): every letter a map uses is
## listed in Tiles for its kind of map, every letter the code builds or
## spawns is listed there too, and no letter is handed to two things at once
## (say a new tile in the match of the builder and a new monster in
## Enemy.WILD_LETTERS that picked the same letter).
## Run with: godot --headless -s tests/tile_letters.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_check_maps()
	_check_dungeon_code()
	_check_outdoor_code()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Every letter on every map is listed for its kind of map.
func _check_maps() -> void:
	var dir := DirAccess.open("res://levels")
	var files := Array(dir.get_files()).filter(func(f): return f.ends_with(".txt"))
	check(files.size() > 0, "no level files found")
	for file in files:
		var path: String = "res://levels/" + file
		var outdoor := Level.is_outdoor_file(path)
		var table: Dictionary = Tiles.OUTDOOR if outdoor else Tiles.DUNGEON
		var kind := "Tiles.OUTDOOR" if outdoor else "Tiles.DUNGEON"
		var seen := {}
		for line in FileAccess.get_file_as_string(path).split("\n"):
			line = line.strip_edges(false, true)
			if line == "" or _is_header(line):
				continue
			for ch in line:
				if ch != " " and not table.has(ch) and not seen.has(ch):
					seen[ch] = true
					check(false, "%s uses the letter '%s', which is not in %s" % [file, ch, kind])


## A header line such as "name: Die Zelle" or "building: ^".
func _is_header(line: String) -> bool:
	var colon := line.find(":")
	if colon <= 0:
		return false
	for ch in line.substr(0, colon):
		if not (ch >= "a" and ch <= "z") and ch != "_":
			return false
	return true


func _check_dungeon_code() -> void:
	var sources := {
		"Level._build_content": _match_letters("res://scripts/level.gd", "_build_content"),
		"Enemy.LETTERS": Enemy.LETTERS.keys(),
		"Creations.LETTERS": _letters(Creations.LETTERS),
	}
	_check_listed(sources, Tiles.DUNGEON, "Tiles.DUNGEON")
	_check_listed({"DungeonLife.OPEN_FLOOR": _letters(DungeonLife.OPEN_FLOOR),
			"DungeonLife.WEBBED": _letters(DungeonLife.WEBBED)}, Tiles.DUNGEON, "Tiles.DUNGEON")
	_check_no_clash(sources)


func _check_outdoor_code() -> void:
	# Each of these hands a letter to one kind of thing on the open-air map.
	var sources := {
		"Outdoor._build_outdoor_cell": _match_letters("res://scripts/outdoor.gd", "_build_outdoor_cell"),
		"Outdoor.BLOCK_CHARS": _letters(Outdoor.BLOCK_CHARS),
		"Outdoor.VILLAGERS": _letters(Outdoor.VILLAGERS),
		"Enemy.WILD_LETTERS": Enemy.WILD_LETTERS.keys(),
		"Animal.LETTERS": Animal.LETTERS.keys(),
		"CraftingSquare.LETTERS": _letters(CraftingSquare.LETTERS),
	}
	_check_listed(sources, Tiles.OUTDOOR, "Tiles.OUTDOOR")
	# Groupings of letters already handed out above.
	_check_listed({"Outdoor.WALK": _letters(Outdoor.WALK), "Outdoor.CAMP": _letters(Outdoor.CAMP)},
			Tiles.OUTDOOR, "Tiles.OUTDOOR")
	var life := {"SurfaceLife.GROUND": _letters(SurfaceLife.GROUND), "SurfaceLife.UNDER": _letters(SurfaceLife.UNDER),
			"SurfaceLife.PATH": _letters(SurfaceLife.PATH), "SurfaceLife.WATER": _letters(SurfaceLife.WATER)}
	for biome in SurfaceLife.BIOMES:
		life["SurfaceLife.BIOMES." + biome] = _letters(SurfaceLife.BIOMES[biome])
	_check_listed(life, Tiles.OUTDOOR, "Tiles.OUTDOOR")
	# Every villager letter has a role. Villager.ROLES may hold more roles
	# than the map places (the wandering merchant's "%" is a role id only).
	for ch in Outdoor.VILLAGERS:
		check(Villager.ROLES.has(ch), "the villager letter '%s' has no role in Villager.ROLES" % ch)
	_check_no_clash(sources)


func _check_listed(sources: Dictionary, table: Dictionary, kind: String) -> void:
	for source in sources:
		check(not sources[source].is_empty(), "found no letters in " + source)
		for ch in sources[source]:
			check(table.has(ch), "%s uses the letter '%s', which is not in %s" % [source, ch, kind])


## No letter is claimed by two of the sources.
func _check_no_clash(sources: Dictionary) -> void:
	var owner := {}
	for source in sources:
		for ch in sources[source]:
			if owner.has(ch) and owner[ch] != source:
				check(false, "the letter '%s' is used by both %s and %s" % [ch, owner[ch], source])
			owner[ch] = source


func _letters(s: String) -> Array:
	var out := []
	for ch in s:
		if not out.has(ch):
			out.append(ch)
	return out


## The letters of the arms of the match in one function of a script, e.g.
## "P": and "<", ">": (the default arm _ is left out).
func _match_letters(path: String, func_name: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var start := text.find("\nfunc %s(" % func_name)
	check(start >= 0, "%s not found in %s" % [func_name, path])
	if start < 0:
		return []
	var end := text.find("\nfunc ", start + 1)
	var body := text.substr(start, end - start if end > 0 else -1)
	var arm := RegEx.create_from_string("(?m)^\\t\\t((?:\"[^\"]+\"(?:,\\s*)?)+):\\s*$")
	var letter := RegEx.create_from_string("\"([^\"]+)\"")
	var out := []
	for m in arm.search_all(body):
		for l in letter.search_all(m.get_string(1)):
			# As written in the script: "\\" is the letter \.
			out.append(l.get_string(1).c_unescape())
	return out
