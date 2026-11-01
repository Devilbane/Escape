extends SceneTree
## Headless test for the pull-out menu on the right edge: it starts closed
## with only its handle on screen, slides fully into view when the handle is
## clicked or Tab is pressed, holds every clickable button, and a button that
## opens a window pushes the menu away again.
## Run with: godot --headless --fixed-fps 60 -s tests/hud_drawer.gd

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


func _finish() -> void:
	if failures == 0:
		print("PASS: hud drawer")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _screen_width() -> float:
	return game._hud.get_viewport().get_visible_rect().size.x


func _press(b: Button) -> void:
	b.button_down.emit()


func _button(text: String) -> Button:
	for b in game._drawer.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


func _tab() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	key.pressed = true
	game._unhandled_input(key)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	check(game.state == game.State.PLAYING, "the game is running")
	var drawer: Control = game._drawer
	var w := _screen_width()

	check(not game.is_drawer_open(), "the menu starts closed")
	var rect := drawer.get_global_rect()
	check(absf(rect.position.x + game._drawer_handle.size.x - w) < 2.0,
		"only the handle shows while closed (left %.0f, screen %.0f)" % [rect.position.x, w])

	for label in ["Inventar", "Charakter", "Kompendium", "Laden", "Springen", "Werfen", "Schlagen", "Kiste", "Stein", "Beenden"]:
		check(_button(Lang.t(label)) != null, "the menu holds the %s button" % label)
	check(drawer.is_ancestor_of(game._sound_button), "the sound button is in the menu")

	_press(game._drawer_handle)
	await _wait(40)
	check(game.is_drawer_open(), "clicking the handle opens the menu")
	rect = drawer.get_global_rect()
	check(absf(rect.end.x - w) < 2.0 and rect.position.x < w - 200.0,
		"the opened menu lies fully on screen at the right edge (%.0f to %.0f)" % [rect.position.x, rect.end.x])
	check(rect.position.y >= 0.0 and rect.end.y <= game._hud.get_viewport().get_visible_rect().size.y, "the menu fits the screen height")

	_press(game._drawer_handle)
	await _wait(40)
	check(not game.is_drawer_open(), "clicking the handle again closes it")
	check(absf(drawer.get_global_rect().position.x + game._drawer_handle.size.x - w) < 2.0, "the closed menu slides back off screen")

	_tab()
	await _wait(40)
	check(game.is_drawer_open(), "Tab opens the menu")

	_press(_button(Lang.t("Inventar")))
	await _wait(5)
	check(game.menus.is_open(), "the Inventory button opens the inventory")
	check(not game.is_drawer_open(), "opening a window pushes the menu away")
	game.menus.close()
	await _wait(5)

	# Action buttons such as Crate keep the menu out for the next click.
	_tab()
	await _wait(40)
	_press(_button(Lang.t("Kiste")))
	await _wait(2)
	check(game.is_drawer_open(), "action buttons leave the menu out")
	_tab()
	await _wait(40)
	check(not game.is_drawer_open(), "Tab closes the menu again")
	_finish()
