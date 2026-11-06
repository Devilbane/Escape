extends SceneTree
## Headless test for the pause window on Esc: Esc in the game stops the world
## and opens the pause window with "Weiterspielen" and "Spiel beenden"; Esc
## again (or "Weiterspielen") plays on. An open window or the pull-out menu is
## closed by the first Esc instead, and a busy hero can still pause.
## Run with: godot --headless --fixed-fps 60 -s tests/pause_menu.gd

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


func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	game._unhandled_input(key)


func _button(text: String) -> Button:
	for b in game.menus._box.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


func _paused() -> bool:
	return game.level.process_mode == Node.PROCESS_MODE_DISABLED and game.player.frozen


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	check(game.state == game.State.PLAYING, "the game is running")
	var menus = game.menus

	# Esc pauses and shows both buttons.
	_key(KEY_ESCAPE)
	await _wait(2)
	check(menus.current == "beenden", "Esc opens the pause window")
	check(_paused(), "the world stands still while paused")
	var hour: float = game.day_hour
	await _wait(30)
	check(is_equal_approx(hour, game.day_hour), "the clock stops while paused")
	check(_button(Lang.t("Weiterspielen")) != null, "the pause window has a resume button")
	check(_button(Lang.t("Spiel beenden")) != null, "the pause window has a quit button")

	# Esc again plays on.
	_key(KEY_ESCAPE)
	await _wait(2)
	check(not menus.is_open(), "Esc again closes the pause window")
	check(not _paused(), "the world runs again")

	# The resume button plays on as well.
	_key(KEY_ESCAPE)
	await _wait(2)
	var resume := _button(Lang.t("Weiterspielen"))
	if resume:
		resume.pressed.emit()
	await _wait(2)
	check(not menus.is_open() and not _paused(), "Weiterspielen plays on")

	# An open window is closed first; only the next Esc pauses.
	menus.open("inventar")
	await _wait(2)
	_key(KEY_ESCAPE)
	await _wait(2)
	check(not menus.is_open(), "the first Esc closes an open window")
	_key(KEY_ESCAPE)
	await _wait(2)
	check(menus.current == "beenden", "the next Esc pauses")
	_key(KEY_ESCAPE)
	await _wait(2)

	# The pull-out menu is pushed away first, too.
	game.set_drawer_open(true)
	await _wait(2)
	_key(KEY_ESCAPE)
	await _wait(2)
	check(not game.is_drawer_open(), "the first Esc closes the pull-out menu")
	check(not menus.is_open(), "closing the pull-out menu does not pause yet")

	# A hero in the middle of something can still pause.
	game.player._busy = 0.5
	check(not game.player.can_act(), "the hero is busy")
	_key(KEY_ESCAPE)
	await _wait(1)
	check(menus.current == "beenden", "a busy hero can pause too")
	_key(KEY_ESCAPE)

	if failures == 0:
		print("PASS: pause menu")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
