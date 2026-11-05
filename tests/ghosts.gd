extends SceneTree
## Headless test for the ghosts and ghouls of the dungeon (see Enemy._ghostly
## and Player.scare): where they haunt, what they leave, how a wraith fades
## until it notices the hero, how a banshee's shriek wakes the monsters
## nearby, how a ghost that has spotted the hero drifts through walls and
## closed doors, and how its fright sends a hero with weak nerves running for
## the nearest way out, while Weisheit, Intuition and Erkunden help to stand firm.
## Run with: godot --headless --fixed-fps 60 -s tests/ghosts.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: ghosts" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _run() -> void:
	_test_tables()
	await _test_dungeon()
	_finish()


## The kinds, their letters, their side, where they haunt and what they leave.
func _test_tables() -> void:
	for pair in [["r", "totengeist"], ["n", "banshee"], ["l", "ghul"]]:
		check(Enemy.LETTERS.get(pair[0], "") == pair[1], "%s places a %s" % pair)
		check(Tiles.DUNGEON.has(pair[0]), "%s is claimed in Tiles" % pair[0])
		check(Factions.of(pair[1]) == "undead", "%s is one of the dead" % pair[1])
		check(not Loot.is_intelligent(pair[1]) and not Loot.carries_valuables(pair[1]), "%s carries no coins or gear" % pair[1])
		check(Loot.coins(pair[1], 1.0).is_empty(), "%s leaves no coins" % pair[1])
		check(Loot.CREATURES.has(pair[1]), "%s has a loot table" % pair[1])
	check(Loot.creature_find("totengeist", "normal") == "ektoplasma", "a wraith may leave ectoplasm")
	check(Loot.creature_find("banshee", "selten") == "bansheehaar", "a banshee may leave a lock of her hair")
	check(Loot.creature_find("ghul", "selten") == "ghulkralle", "a ghoul may leave a claw")
	check(Enemy.KINDS.totengeist.has("ghost") and Enemy.KINDS.banshee.has("ghost") and not Enemy.KINDS.ghul.has("ghost"), "wraiths and banshees are ghosts, ghouls are not")
	for kind in ["totengeist", "banshee", "fog_wraith"]:
		check(int(Enemy.KINDS[kind].get("scare", 0)) > 0, "a %s can frighten the hero" % kind)
	check(not Enemy.KINDS.ghul.has("scare"), "a ghoul frightens nobody with ghostly terror")
	var haunted := {"04_die_gruft.txt": "r", "06_die_katakomben.txt": "lr", "08_die_knochengrube.txt": "ln", "15_das_offene_grab.txt": "rnl"}
	for file in haunted:
		var text := FileAccess.get_file_as_string("res://levels/" + file)
		for ch in haunted[file]:
			var found := false
			for line in text.split("\n"):
				if line.begins_with("#") and line.contains(ch):
					found = true
			check(found, "%s haunts %s" % [Enemy.LETTERS[ch], file])


func _index_of(file: String) -> int:
	for i in game.level_files.size():
		if game.level_files[i].get_file() == file:
			return i
	return -1


func _spawn(lvl: Level, kind: String, cell: Vector2i) -> Enemy:
	var e: Enemy = lvl._spawn_enemy(kind, cell)
	lvl.enemies.append(e)
	return e


func _test_dungeon() -> void:
	game.hero_name = "Ghost test"
	game.load_level(_index_of("08_die_knochengrube.txt"), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Level = game.level
	var p: Player = game.player
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	p.max_hp = 999
	p.hp = 999
	p.sneaking = false
	# Row 8 of the bone pit: open floor either side of a wall at column 9.
	var hero_cell := Vector2i(7, 8)
	var far_cell := Vector2i(11, 8)
	check(lvl.cell_char(Vector2i(9, 8)) == "#", "a wall stands between the two spots")
	p.global_position = lvl.cell_to_world(Vector2i(2, 6))
	await _wait(2)

	# A wraith far from the hero is all but invisible, and bumps into nothing.
	var wraith := _spawn(lvl, "totengeist", Vector2i(16, 7))
	await _wait(4)
	check(wraith.is_ghost() and wraith.collision_mask == 0, "a wraith passes through everything")
	check(is_equal_approx(wraith._ghost_alpha, Enemy.FADED), "an unaware wraith is a mere shimmer (%.2f)" % wraith._ghost_alpha)
	check(not wraith._ghost_mats.is_empty(), "the wraith is drawn see-through")
	# Spikes do not hurt a ghost.
	var hp_before := wraith.hp
	wraith.hurt_by_trap(wraith.global_position)
	check(wraith.hp == hp_before, "spikes do not hurt a ghost")

	# Once it has spotted the hero, it drifts straight through the wall.
	p._fear_calm = 999.0
	p.global_position = lvl.cell_to_world(hero_cell)
	wraith.global_position = lvl.cell_to_world(far_cell)
	wraith.reset_physics_interpolation()
	wraith.alert(p.global_position)
	await _wait(30)
	check(wraith._ghost_alpha > 0.5, "a hunting wraith flares up (%.2f)" % wraith._ghost_alpha)
	var reached := false
	for i in 180:
		await _wait(1)
		var gap := wraith.global_position - p.global_position
		gap.y = 0.0
		if gap.length() < 2.5:
			reached = true
			break
	check(reached, "the wraith came through the wall to the hero")
	check(wraith.global_position.y > -0.5, "and floats instead of falling through the floor (%.2f)" % wraith.global_position.y)
	var to_dead := wraith.hp
	wraith.take_hit(to_dead + 5, p.global_position)
	await _wait(2)
	check(wraith.dead and Corpse.style_of(wraith) == "wisp", "a fallen ghost blows away")

	# A banshee's shriek wakes the monsters nearby.
	var sleeper := _spawn(lvl, "krieger", Vector2i(16, 9))
	var banshee := _spawn(lvl, "banshee", Vector2i(14, 9))
	await _wait(4)
	check(not sleeper.is_hunting(), "the skeleton is not on the hunt yet")
	banshee._shriek(p)
	check(sleeper.is_hunting(), "the banshee's shriek sets it on the hero")
	check(banshee._shriek_cool > 0.0, "she does not shriek again at once")
	sleeper.queue_free()
	banshee.queue_free()
	lvl.enemies.clear()
	await _wait(2)

	# The fright: nerve against strength.
	p._fear_calm = 0.0
	p.cure()
	var nerve := p.attribute("weisheit") + p.attribute("intuition") + Player.NERVE_PER_EXPLORE * p.skill("erkunden")
	check(p.nerve() == nerve, "nerve is Weisheit, Intuition and Erkunden (%d)" % p.nerve())
	var ghost := _spawn(lvl, "totengeist", Vector2i(16, 7))
	await _wait(2)
	var elite := Enemy.new()
	elite.kind = "totengeist"
	elite.elite = true
	elite.rated_level = ghost.rated_level
	elite._stats = Enemy.KINDS.totengeist.duplicate()
	check(elite.scare_strength() == ghost.scare_strength() + Enemy.ELITE_SCARE, "an elite frightens more")
	elite.free()
	ghost.rated_level += 4
	check(ghost.scare_strength() == int(Enemy.KINDS.totengeist.scare) + ghost.rated_level, "a ghost of a higher level frightens more")
	var strength := ghost.scare_strength()
	check(not p.scare(ghost.global_position, strength, [1, 20]), "a steady hero stands firm")
	check(not p.ailments.has("angst"), "and is not afraid")
	p.global_position = lvl.cell_to_world(Vector2i(14, 9))
	await _wait(2)
	var exit: Vector3 = lvl.cell_to_world(lvl.exit_cell)
	var start_gap := p.global_position.distance_to(exit)
	check(p.scare(ghost.global_position, nerve + 30, [20, 1]), "a fright far beyond the hero's nerve breaks it")
	check(p.is_afraid() and not p.can_act(), "the frightened hero cannot fight or act")
	check(not p._flee.is_empty(), "and knows where to run")
	check(not p.scare(ghost.global_position, nerve + 30, [20, 1]), "no new fright while afraid")
	await _wait(roundi(Player.FEAR_TIME * 60.0 * 0.6))
	check(p.global_position.distance_to(exit) < start_gap - 3.0, "the hero ran towards the way out (%.1f -> %.1f)" % [start_gap, p.global_position.distance_to(exit)])
	await _wait(roundi(Player.FEAR_TIME * 60.0 * 0.6))
	check(not p.ailments.has("angst") and p.can_act(), "the fear wears off after %.0f seconds" % Player.FEAR_TIME)
	check(not p.scare(ghost.global_position, nerve + 30, [20, 1]), "and the hero is not frightened again right after")
	check(game.hero_ailments().is_empty() or not game.hero_ailments().has(["angst", ""]), "the fear's icon is gone")
	# No way out reachable: the hero runs away from the ghost.
	var away := lvl.flee_path(Vector3(0, 0, -9999), Vector3(0, 0, -9990))
	check(not away.is_empty(), "there is always somewhere to run")
	# A wiser, warier hero has the nerve for it.
	p.xp["weisheit"] = 5000.0
	p.xp["intuition"] = 5000.0
	p.xp["erkunden"] = 5000.0
	check(p.nerve() > nerve, "training Weisheit, Intuition and Erkunden steadies the nerve (%d > %d)" % [p.nerve(), nerve])
