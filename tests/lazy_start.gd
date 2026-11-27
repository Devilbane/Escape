extends SceneTree
## Headless test that the first level is built only when a game starts: with the deferred start on, the title
## has no level behind it; "New" builds level 1, and Continue builds the saved game's level. Also checks how the
## loading screen cuts the patch notes into a left and a right half.
## Run with: godot --headless --fixed-fps 60 -s tests/lazy_start.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	load("res://scripts/game.gd").lazy_start = true
	_make_game()


func _make_game() -> void:
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


func _wait_playing() -> void:
	for i in 300:
		if game.state == game.State.PLAYING:
			break
		await process_frame
	await _wait(6)


func _run() -> void:
	check(game.level == null, "no level is built behind the title")
	check(game._player == null, "no hero is made behind the title")

	game.new_game()
	check(game._player != null and not game.player.visible, "New Game makes the hero, still out of sight until the game starts")
	game._name_edit.text = "Lazy"
	game._start_new_game()
	await _wait_playing()
	check(game.level != null and game.level_index == 0, "New builds level 1")
	check(game.player.visible, "the hero is back in the world")
	check(game.save_game(), "the game saves")
	var path: String = game.save_path()

	game.queue_free()
	await _wait(3)
	_make_game()
	await _wait(5)
	check(game.level == null, "a restart again has no level behind the title")
	game.continue_game(path)
	await _wait_playing()
	check(game.level != null and game.hero_name == "Lazy", "Continue builds the saved game's level")
	check(game.player.visible, "the continued hero is in the world")

	var notes := ["a", "b", "c", "d", "e"]
	var parts := LoadingScreen.halves(notes)
	check(parts.left == ["a", "b", "c"] and parts.right == ["d", "e"] and parts.more == 0, "five notes split 3 and 2")
	var many := []
	for i in 20:
		many.append("n%d" % i)
	parts = LoadingScreen.halves(many)
	check(parts.left.size() == 7 and parts.right.size() == 7 and parts.more == 6, "long notes are cut with a count of the rest")
	check(LoadingScreen.halves([]).left.is_empty(), "no notes, no lines")

	print("PASS" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)
