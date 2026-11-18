extends SceneTree
## Headless test for the compendium's monster levels per place (see PlaceMonsters):
## every shipped map is read, the level range matches the monsters listed, and
## it keeps to the area's levels (HeroLevel.AREAS) or, in the dungeon, to its top.
## Run with: godot --headless -s tests/place_monsters.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.setup()
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://levels/"):
		if f.ends_with(".txt"):
			files.append("res://levels/" + f)
	files.sort()
	var with_monsters := 0
	for i in files.size():
		var info := PlaceMonsters.of(files[i], i)
		if info.kinds.is_empty():
			continue
		with_monsters += 1
		var levels: Array = info.kinds.filter(func(k): return k.kind != "waechter").map(func(k): return k.level)
		if levels.is_empty():
			levels = info.kinds.map(func(k): return k.level)
		check(info.low == levels.min() and info.high == levels.max(), "%s: range matches its monsters" % files[i])
		check(info.low >= 1 and info.high <= HeroLevel.MAX, "%s: levels are in 1 to %d" % [files[i], HeroLevel.MAX])
	check(with_monsters >= 20, "most maps have monsters (%d)" % with_monsters)
	# The first floor holds skeletons of low level; the Great Old One's lair is the world's top.
	var first := PlaceMonsters.of(files[0], 0)
	check(first.high <= 3, "the first cell stays easy (high %d)" % first.high)
	var lair := PlaceMonsters.of("res://levels/26_das_lager_des_grossen_alten.txt", 25)
	check(lair.high == HeroLevel.WORLD_TOP, "the Great Old One's lair tops the world (%d)" % lair.high)
	# The guardian (level 3) does not drag a deep floor's range down.
	check(PlaceMonsters.of("res://levels/32_die_zisterne_sonnet.txt", 31).low >= 16, "the guardian is left out of the range")
	# A safe village building has no monsters.
	check(PlaceMonsters.of("res://levels/14_das_wohnhaus.txt", 13).kinds.is_empty(), "a house has no monsters")
	check(PlaceMonsters.range_text(4, 4) != PlaceMonsters.range_text(4, 6), "one level and a range read differently")
	print("PASS: place monsters" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
