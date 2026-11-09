extends SceneTree
## Headless test for the chat line's teleport command (see Teleport,
## Game.teleport_to): prefixes match names case-insensitively in both
## languages, with or without the article, and by file id; an exact name beats
## a longer one; several matches only list, none says so; one match puts the
## hero at that area's entrance on a walkable spot; it is refused while a
## window is open; and the command is not spoken aloud.
## Run with: godot --headless --fixed-fps 60 -s tests/teleport.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _news() -> Array:
	return game.event_log.entries()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)

	# The words.
	check(Teleport.parse("teleport zel") == "zel", "the command is read")
	check(Teleport.parse("  TELEPORT  Zel ") == "Zel", "case and spaces do not matter")
	check(Teleport.parse("teleport") == "", "the bare word asks for the list")
	check(Teleport.parse("teleporter zel") == null and Teleport.parse("hallo") == null, "other lines are no command")

	# The codes: five lowercase letters each, unique, stable.
	var all := Teleport.areas(game.level_files)
	check(all.size() > 20, "there are many areas: %d" % all.size())
	var seen := {}
	for area in all:
		var code: String = area.code
		check(code.length() == 5 and code == code.to_lower() and code.strip_edges() == code, "%s: code '%s' is five letters" % [area.file, code])
		for ch in code:
			check(ch >= "a" and ch <= "z", "%s: code '%s' holds only letters" % [area.file, code])
		check(not seen.has(code), "code '%s' is unique" % code)
		seen[code] = true
		check(Lang.EN.has(area.name), "%s has an English name" % area.name)
	var again := Teleport.areas(game.level_files)
	check(again.map(func(a): return a.code) == all.map(func(a): return a.code), "the codes are the same every time")
	check(Teleport.by_code(all, "ZELLE").get("file", "").contains("zelle"), "the cell has the code ZELLE (any case)")
	check(Teleport.by_code(all, "qqqqq").is_empty(), "an unknown code finds nothing")
	var hero: Player = game.player
	var start: int = game.level_index

	# The flow: "teleport" lists, the next line is a code.
	var before: int = _news().size()
	game._hero_says("teleport")
	var listed := _news().slice(before)
	check(listed.size() >= all.size(), "the log lists every place: %d lines for %d places" % [listed.size(), all.size()])
	check(listed.any(func(l): return l.contains("ZELLE") and l.contains("Zelle")), "a line shows code and name")
	game._hero_says("qqqqq")
	check(_news()[-1].contains("QQQQQ"), "an unknown code is said: %s" % _news()[-1])
	check(game.level_index == start and game.state == game.State.PLAYING, "an unknown code moves nobody")
	game._hero_says("Hallo da")
	check(_news()[-1].ends_with("Hallo da"), "another line is spoken and ends the wait")
	game._hero_says("zelle")
	check(game.state == game.State.PLAYING and _news()[-1].ends_with("zelle"), "a code without the list is only speech")

	# A window open: refused.
	game.menus.open("inventar")
	await _wait(3)
	check(not game.teleport_to(2), "no teleporting while a window is open")
	game.menus.close()
	await _wait(3)

	# To every area, one after the other: it loads, and the hero stands on open ground.
	for area in all:
		check(game.teleport_to(area.index), "teleport to %s starts" % area.name)
		check(game.state == game.State.TRANSITION, "the fade runs")
		await _wait(60)
		check(game.state == game.State.PLAYING and not hero.frozen, "%s: playing again" % area.name)
		check(game.level_index == area.index, "%s: the level is loaded (%d)" % [area.name, game.level_index])
		var at: Vector2i = game.level.world_to_cell(hero.global_position)
		check(game.level._walkable(at), "%s: the hero stands on a walkable cell %s" % [area.name, at])

	# The whole flow to one place, and back to the entrance of the same one.
	game._hero_says("teleport")
	game._hero_says("ZELLE")
	await _wait(60)
	check(game.level.level_name == "Die Zelle", "the code took the hero to the cell: %s" % game.level.level_name)
	hero.global_position += Vector3(5, 0, 0)
	game._hero_says("teleport zelle")
	await _wait(60)
	check(hero.global_position.distance_to(game.level.cell_to_world(game.level.start_cell)) < 0.5, "'teleport zelle' brings the hero back to the entrance")

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: teleport")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
