extends SceneTree
## Headless test for the quick window icons on the right edge: map,
## compendium, inventory, character and quests stand in one column above the
## menu handle, flush with the screen edge and evenly spaced, each with a
## tooltip naming its window and key. A click opens the window and keeps the
## icon pressed, a second click closes it, a click on another icon switches,
## and the O key opens the quests window with its hints.
## Run with: godot --headless --fixed-fps 60 -s tests/quick_bar.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	if shots != "":
		# Screenshots in English, as the pull request is read in English.
		Lang.language = "en"
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
		print("PASS: quick bar")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _wait(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _click(b: Button) -> void:
	# Same as a click: toggles, then reports the press.
	b.button_pressed = not b.button_pressed
	b.pressed.emit()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	await _wait(120 if shots != "" else 10)
	check(game.state == game.State.PLAYING, "the game is running")
	var w: float = game._hud.get_viewport().get_visible_rect().size.x
	var order := ["karte", "kompendium", "inventar", "charakter", "auftraege"]
	var buttons: Array[Button] = []
	for kind in order:
		check(game._quick_buttons.has(kind), "there is an icon for " + kind)
		buttons.append(game._quick_buttons[kind])

	# Layout: one column flush with the right edge, the handle below it.
	var handle: Rect2 = game._drawer_handle.get_global_rect()
	var last_bottom := -1.0
	for b in buttons:
		var r := b.get_global_rect()
		check(absf(r.end.x - w) < 1.0, "%s icon touches the right edge (%.0f of %.0f)" % [b.tooltip_text, r.end.x, w])
		check(absf(r.position.x - handle.position.x) < 0.5, "%s icon lines up with the handle" % b.tooltip_text)
		check(r.size.x >= 44.0 and r.size.y >= 44.0, "%s icon is at least 44 x 44" % b.tooltip_text)
		if last_bottom >= 0.0:
			check(absf(r.position.y - last_bottom - game.QUICK_GAP) < 0.5, "%s icon keeps the even gap" % b.tooltip_text)
		last_bottom = r.end.y
	check(absf(handle.position.y - last_bottom - game.QUICK_HANDLE_GAP) < 0.5, "a wider gap separates the icons from the handle")
	check(buttons[0].get_global_rect().position.y > game._coin_label.get_global_rect().end.y + 12.0, "the icons stay clear of the gold line")

	# Tooltips name the window and its key.
	for i in order.size():
		var key: String = game.QUICK_WINDOWS[i][2]
		check(buttons[i].tooltip_text.ends_with("(key %s)" % key) or buttons[i].tooltip_text.ends_with("(Taste %s)" % key), "tooltip names the key: " + buttons[i].tooltip_text)
	check(buttons[0].tooltip_text.begins_with("Karte") or buttons[0].tooltip_text.begins_with("Map"), "the map tooltip names the map")
	await _shot("quick_bar")

	# A click opens, a second click closes, another icon switches.
	_click(buttons[0])
	await _wait(3)
	check(game.menus.current == "karte", "the map icon opens the map")
	check(buttons[0].button_pressed, "the open window's icon stays pressed")
	_click(buttons[2])
	await _wait(3)
	check(game.menus.current == "inventar", "the bag icon switches to the inventory")
	check(buttons[2].button_pressed and not buttons[0].button_pressed, "only the open window's icon is pressed")
	_click(buttons[2])
	await _wait(3)
	check(not game.menus.is_open(), "a second click on the icon closes the window")
	check(not buttons[2].button_pressed, "the icon is raised again")

	# The icons keep their place when a window opens by key.
	if shots != "":
		# Two tasks taken on, so the screenshot shows a filled log.
		var ids: Array = Quests.ALL.keys()
		for id in ids.slice(0, 2):
			game.quests.state[id] = {"state": "active", "count": 0}
	var before := buttons[4].get_global_rect()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_O
	key.pressed = true
	game._unhandled_input(key)
	await _wait(3)
	check(game.menus.current == "auftraege", "O opens the quests window")
	check(buttons[4].button_pressed, "the scroll icon shows the quests window is open")
	check(buttons[4].get_global_rect() == before, "the icons do not move when a window opens")
	var hints: Array[String] = game.menus.quest_hints()
	check(not hints.is_empty(), "the quests window always has a hint")
	var texts := []
	for l in game.menus._box.find_children("*", "Label", true, false):
		texts.append(l.text)
	check(Lang.t("Was sich jetzt lohnt") in texts, "the quests window shows what is worth doing")
	check(Lang.t("Deine Aufträge") in texts, "the quests window lists the quests")
	await _shot("quests_window")
	game._unhandled_input(key)
	await _wait(3)
	check(not game.menus.is_open(), "O closes the quests window again")

	# Opening the pull-out menu takes the icons along with it.
	game.set_drawer_open(true)
	await _wait(40)
	check(absf(buttons[0].get_global_rect().end.x - game._drawer_handle.get_global_rect().end.x) < 0.5, "the icons slide out with the menu")
	await _shot("quick_bar_menu_open")
	game.set_drawer_open(false)
	await _wait(40)

	# A tooltip shows on hover (only with a display).
	if shots != "":
		var at := buttons[1].get_global_rect().get_center()
		var move := InputEventMouseMotion.new()
		move.position = at
		move.global_position = at
		root.push_input(move)
		await _wait(60)
		await _shot("quick_bar_tooltip")
	_finish()
