extends SceneTree
## A night with a breakthrough writes "Resting" and the skill into the journal.
## Run with: godot --headless --fixed-fps 60 -s tests/journal_resting_shots.gd
## With SHOTS=<folder> (needs a display) it also saves a screenshot of the journal.

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
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
	game._title.visible = false
	game.hero_name = "Ivy"
	await _wait(10)
	var j: Journal = game.journal
	var before := j.entries.size()
	# A night with one breakthrough and one miss.
	game._journal_night({"practised": ["klingen"], "won": [{"id": "klingen", "level": 4, "flash": false}], "missed": ["aexte"]})
	check(j.entries.size() == before + 2, "a resting line and one line for the win, none for the miss: %d" % (j.entries.size() - before))
	check(j.entries[before].t == "Ausgeruht", "the first line is Resting")
	check(Lang.t(j.entries[before].t) == "Resting", "it reads Resting in English")
	var text := " ".join(j.entry_text(j.entries[before + 1]))
	check(text.contains("level 4"), "the win names its level: " + text)
	# A night with nothing rolled writes nothing.
	var n := j.entries.size()
	game._journal_night({"practised": [], "won": [], "missed": []})
	check(j.entries.size() == n, "no rolls, no lines")
	if shots != "":
		game.menus.map_page = "tagebuch"
		game.menus.open("karte")
		await _wait(20)
		root.get_viewport().get_texture().get_image().save_png(shots.path_join("journal_resting.png"))
	print("journal resting test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(failures)
