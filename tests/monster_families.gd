extends SceneTree
## Headless test for the monster families (see MonsterFamilies): every kind of
## monster belongs to a family, every map in levels/ names the families that
## live there ("monsters:"), every monster a map places or the open air
## spawns belongs to one of them, and the map workshop's checks catch a
## monster out of place.
## Run with: godot --headless -s tests/monster_families.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.setup()
	_check_kinds()
	_check_maps()
	_check_open_air()
	_check_validation()
	print("PASS: monster families" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Every kind has a known family, and no family is listed for a kind that is gone.
func _check_kinds() -> void:
	for kind in Enemy.KINDS:
		var f := MonsterFamilies.family_of(kind)
		check(f != "", "the kind \"%s\" has no family in MonsterFamilies.KINDS" % kind)
		check(f == "" or MonsterFamilies.FAMILIES.has(f) or f == MonsterFamilies.HORRORS,
				"the kind \"%s\" has the unknown family \"%s\"" % [kind, f])
	for kind in MonsterFamilies.KINDS:
		check(Enemy.KINDS.has(kind), "MonsterFamilies.KINDS lists \"%s\", which is no kind of Enemy" % kind)
	for kind in Enemy.HORRORS:
		check(MonsterFamilies.fits(kind, []), "the horror \"%s\" does not fit everywhere" % kind)
	for family in MonsterFamilies.FAMILIES:
		check(Lang.EN.has(MonsterFamilies.FAMILIES[family]), "no English for the family \"%s\"" % family)


## Every shipped map names its families, all of them known, and every monster on it fits.
func _check_maps() -> void:
	for f in DirAccess.get_files_at("res://levels/"):
		if not f.ends_with(".txt"):
			continue
		var path := "res://levels/" + f
		var m := LevelMap.load_file(path)
		var value := m.get_header(MonsterFamilies.HEADER)
		check(value != "", "%s has no \"monsters:\" header" % f)
		check(MonsterFamilies.unknown(value).is_empty(), "%s names unknown families: %s" % [f, MonsterFamilies.unknown(value)])
		var out_of_place := m.validate().filter(func(i): return i.text.contains("Bewohner") or i.text.contains("Monsterfamilie"))
		check(out_of_place.is_empty(), "%s has monsters out of place: %s" % [f, out_of_place.map(func(i): return LevelMap.describe(i))])
		# The game reads the same families from the file.
		var level := Level.new()
		level.load_from_file(path)
		check(level.monster_families == MonsterFamilies.parse(value), "%s: Level reads the families %s" % [f, level.monster_families])
		check(not level.grid.any(func(row): return row.begins_with(MonsterFamilies.HEADER + ":")), "%s: the header became a row of the map" % f)
		# The Spider Queen calls her young out of the walls.
		if m.count("q") > 0:
			check(MonsterFamilies.fits("spinne", level.monster_families), "%s: the Spider Queen's young do not live there" % f)
		level.free()


## What the open air spawns besides its map letters fits its families.
func _check_open_air() -> void:
	var families: Array[String] = []
	for f in DirAccess.get_files_at("res://levels/"):
		if f.ends_with(".txt") and Level.is_outdoor_file("res://levels/" + f):
			families = MonsterFamilies.parse(LevelMap.load_file("res://levels/" + f).get_header(MonsterFamilies.HEADER))
	check(not families.is_empty(), "the open-air map names no families")
	var spawned: Array = ["wolf", "halsabschneider"]  # the wolf pack, the chief's call
	spawned.append_array(Outdoor.NIGHT_DEAD_KINDS)
	for w in Outdoor.WEATHER_FOES.values():
		spawned.append(w.kind)
	for kind in spawned:
		check(MonsterFamilies.fits(kind, families), "the open air spawns a %s, but its families are %s" % [kind, families])


func _hints_of(text: String) -> Array:
	return LevelMap.parse(text).validate().filter(func(i): return not i.error).map(func(i): return i.text)


## The map workshop names a monster out of place, and nothing else.
func _check_validation() -> void:
	var map := "name: A\nhint: B\n%s#####\n##E##\n#.v.#\n#.P.#\n#####\n"
	var out_of_place := func(hints: Array): return hints.any(func(t): return t.contains("lebt hier nicht"))
	check(out_of_place.call(_hints_of(map % "monsters: undead\n")), "a bat among the undead passes")
	check(not out_of_place.call(_hints_of(map % "monsters: undead, wildlife\n")), "a bat among wildlife is out of place")
	check(_hints_of(map % "").any(func(t): return t.contains("welche Monster")), "a map with monsters but no families passes")
	check(_hints_of(map % "monsters: undaed, wildlife\n").any(func(t): return t.contains("Monsterfamilie")), "an unknown family passes")
	var quiet := "name: A\nhint: B\n#####\n##E##\n#...#\n#.P.#\n#####\n"
	check(not _hints_of(quiet).any(func(t): return t.contains("Bewohner")), "a map without monsters needs families")
	# A creation is judged by its base kind.
	var made := "name: A\nhint: B\nmonsters: wildlife\ncustom: 1 {\"type\": \"monster\", \"base\": \"krieger\", \"name\": \"Knochenfürst\"}\n#####\n##E##\n#.1.#\n#.P.#\n#####\n"
	check(out_of_place.call(_hints_of(made)), "a skeleton creation among wildlife passes")
	# The header round-trips and the editor's order puts it after "secret".
	var m := LevelMap.parse("name: A\nhint: B\nsecret: normal\n#####\n##E##\n#.P.#\n#####\n")
	m.set_header(MonsterFamilies.HEADER, MonsterFamilies.to_value(["ghosts", "undead"]))
	check(m.to_text().begins_with("name: A\nhint: B\nsecret: normal\nmonsters: undead, ghosts\n"), "the header is written as %s" % m.to_text())
