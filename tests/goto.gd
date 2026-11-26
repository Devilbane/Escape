extends SceneTree
## Headless test for the chat line's goto command (see GotoCommand, Game._goto_command): the words
## are read, a line for the current spot reads back to the same spot, and a goto puts the hero on
## the tile in the season and at the time asked for.
## Run with: godot --headless --fixed-fps 60 -s tests/goto.gd

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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)

	# The words.
	var p: Dictionary = GotoCommand.parse("goto dorfx 149 127 autumn 14:30")
	check(p.code == "dorfx" and p.cell == Vector2i(149, 127) and p.season == Weather.AUTUMN and is_equal_approx(p.hour, 14.5), "a full line is read: %s" % p)
	p = GotoCommand.parse("GOTO zelle 3 4 noon winter")
	check(p.season == Weather.WINTER and is_equal_approx(p.hour, 12.0), "season and time come in any order")
	p = GotoCommand.parse("goto zelle 3 4")
	check(p.season == "" and p.hour < 0.0, "season and time may be left out")
	check(GotoCommand.parse("goto").is_empty() and GotoCommand.parse("goto") != null, "the bare word asks for the current spot")
	check(GotoCommand.parse("goto zelle x 4").has("error"), "a bad tile is an error")
	check(GotoCommand.parse("goto zelle 3 4 purple").error == "purple", "a bad word is named")
	check(GotoCommand.parse("gotham") == null and GotoCommand.parse("hallo") == null, "other lines are no command")

	# The line for here reads back to here.
	var here: String = game._goto_here()
	check(here.begins_with("goto "), "the line for here: %s" % here)
	var back: Dictionary = GotoCommand.parse(here)
	check(not back.has("error") and back.cell == game.level.world_to_cell(game.player.global_position), "the line names this tile")
	game._hero_says("goto")
	check(DisplayServer.get_name() == "headless" or DisplayServer.clipboard_get() == here, "the line is copied")

	# A goto: place, tile, season and time. The cell's start tile is always walkable.
	var all := Teleport.areas(game.level_files)
	var hall := Teleport.by_code(all, "stach")
	if hall.is_empty():
		hall = all[1]
	var target := Vector2i(-1, -1)
	game.teleport_to(int(hall.index))
	await _wait(60)
	target = game.level.start_cell
	var line := "goto %s %d %d winter 21:30" % [hall.code, target.x, target.y]
	game.teleport_to(0)
	await _wait(60)
	game._hero_says(line)
	await _wait(60)
	check(game.level_index == int(hall.index), "the goto loaded the place")
	check(game.level.world_to_cell(game.player.global_position) == target, "the hero stands on the tile: %s" % game.level.world_to_cell(game.player.global_position))
	check(Weather.season(game.season_day()) == Weather.WINTER, "it is winter")
	check(absf(game.day_hour - 21.5) < 0.2, "it is 21:30: %f" % game.day_hour)

	# A wall tile is refused, an unknown place too.
	game._hero_says("goto %s 0 0" % hall.code)
	await _wait(60)
	game._hero_says("goto qqqqq 1 1")
	check(game.state == game.State.PLAYING, "an unknown place moves nobody")

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: goto")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
