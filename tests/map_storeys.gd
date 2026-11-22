extends SceneTree
## Headless test for the floors of the map (see MapView.storey): down in the forgotten silver
## mine the hero's map notes the tunnels they see (Journal.deep), not the woods overhead; the open
## air's map then has a second floor, and the map window opens on the floor the hero stands on.
## The floor buttons and Page Up / Page Down switch floors without moving anything outside the map,
## the arrow shows only on the hero's floor, the legend names the mine's marks, and the mine's map
## is kept in the saved game. A map with one floor has no floor buttons.
## Run with: godot --headless --fixed-fps 60 -s tests/map_storeys.gd
## With SHOTS=<folder> and a display it also saves both floors of the map.

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
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
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


func _view() -> MapView:
	return game.menus._box.find_child("MapView", true, false)


func _storeys() -> Control:
	return game.menus._box.find_child("MapStoreys", true, false)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	game.menus._map_zoom_key(e)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.escaped = true
	game.journal.clear()
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var j: Journal = game.journal
	var outside := j.current_file()
	# Up on the ground: the map has one floor.
	game.player.global_position = LostMine.sketch().cell_world(41, 24) + Vector3(0, 0.1, 2.0)
	game.player.reset_physics_interpolation()
	await _wait(5)
	j._timer = 0.0
	j.update(0.0)
	check(not j.has_deep(), "before the hero climbs down the mine is not on the map")
	check(MapView.storeys(j, outside) == [MapView.GROUND], "the open air's map has one floor")
	game.menus.map_page = "karte"
	game.menus.open("karte")
	check(_view() != null and _storeys() == null, "a map with one floor has no floor buttons")
	game.menus.close()
	# Down the shaft and along the gallery: the tunnels seen go on the map, the woods above do not.
	var above_before: int = Array(j.explored[outside]).count(1)
	for c in [LostMine.SHAFT + Vector2i(0, 2), Vector2i(42, 31), Vector2i(36, 31), Vector2i(30, 31)]:
		game.player.global_position = LostMine.floor_at(c) + Vector3(0, 0.1, 0)
		game.player.reset_physics_interpolation()
		await _wait(3)
		j._timer = 0.0
		j.update(0.0)
	check(j.has_deep(), "down there the mine goes on the map")
	check(j.is_deep_seen(Vector2i(30, 31)) and j.is_deep_seen(LostMine.SHAFT), "the tunnels walked are seen")
	check(not j.is_deep_seen(Vector2i(69, 28)), "the far east drift is not seen from the gallery")
	var through := false
	for y in LostMine.grid_size().y:
		for x in LostMine.grid_size().x:
			if j.is_deep_seen(Vector2i(x, y)) and not LostMine.cells().has(Vector2i(x, y)):
				through = true
	check(not through, "only the mine's own cells are seen")
	check(Array(j.explored[outside]).count(1) == above_before, "the woods overhead are not explored from down there")
	check(MapView.storeys(j, outside) == [MapView.GROUND, MapView.DEEP], "the open air's map has the mine as a second floor")
	# The map opens on the hero's floor: the mine, with the arrow and the mine's legend.
	game.menus.map_page = "karte"
	game.menus.open("karte")
	await _wait(2)
	var view := _view()
	check(view != null and view.storey == MapView.DEEP, "down in the mine the map opens on the mine's floor")
	check(view != null and view.hero_at != Vector2.INF, "the arrow shows on the hero's floor")
	check(_storeys() != null, "the floor buttons show")
	var name: Label = _storeys().find_child("StoreyName", true, false) if _storeys() else null
	check(name != null and name.text == Lang.t("Silbergrube"), "the floor's name is shown")
	check(view != null and view.deep_places().size() >= 1 and view.deep_places()[0].name == "Leiter zur Steigerhütte", "the ladder is marked on the mine's floor")
	check(_has_label(Lang.t("Leiter zur Steigerhütte")), "the legend names the mine's marks")
	if shots != "":
		await _shot("map_mine")
	var panel: Rect2 = game.menus._panel.get_global_rect()
	var map_rect: Rect2 = view.get_global_rect()
	var tabs := _label_rect(Lang.t("Karte und Tagebuch"))
	# One floor up: the ground, without the arrow; nothing outside the map moves.
	_key(KEY_PAGEUP)
	await _wait(2)
	view = _view()
	check(view.storey == MapView.GROUND, "Page Up shows the ground")
	check(view.hero_at == Vector2.INF, "no arrow on a floor the hero is not on")
	check(game.menus._panel.get_global_rect() == panel, "switching floors keeps the window's size and place")
	check(view.get_global_rect() == map_rect, "switching floors keeps the map where it was")
	check(_label_rect(Lang.t("Karte und Tagebuch")) == tabs, "the window's title stays where it was")
	var up_button: Button = _storeys().find_children("*", "Button", true, false)[0]
	var down_button: Button = _storeys().find_children("*", "Button", true, false)[1]
	check(up_button.disabled and not down_button.disabled, "on the top floor only the way down is open")
	if shots != "":
		await _shot("map_ground")
	# The button down goes back to the mine.
	down_button.pressed.emit()
	await _wait(2)
	check(_view().storey == MapView.DEEP, "the button down shows the mine again")
	_key(KEY_PAGEDOWN)
	await _wait(2)
	check(_view().storey == MapView.DEEP, "there is no floor below the mine")
	game.menus.close()
	# Up on the ground again: the map opens on the ground.
	game.player.global_position = LostMine.sketch().cell_world(41, 24) + Vector3(0, 0.1, 2.0)
	game.player.reset_physics_interpolation()
	await _wait(3)
	game.menus.open("karte")
	await _wait(2)
	check(_view().storey == MapView.GROUND, "up on the ground the map opens on the ground")
	game.menus.close()
	# The mine's map is kept in the saved game.
	var saved := j.for_save()
	var again := Journal.new(game)
	again.load_from(JSON.parse_string(JSON.stringify(saved)))
	check(again.has_deep() and again.is_deep_seen(Vector2i(30, 31)) and not again.is_deep_seen(Vector2i(69, 28)), "the mine's map is kept in the saved game")
	for text in ["Oberfläche", "Silbergrube", "Eine Ebene höher (Bild ↑)", "Eine Ebene tiefer (Bild ↓)", "Leiter zur Steigerhütte", "Versiegeltes Tor", "Erzader im Fels"]:
		check(Lang.EN.has(text), "English for: " + text)
	print("PASS: map storeys" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _has_label(text: String) -> bool:
	for l in game.menus._box.find_children("*", "Label", true, false):
		if (l as Label).text.ends_with(text):
			return true
	return false


func _label_rect(text: String) -> Rect2:
	for l in game.menus._box.find_children("*", "Label", true, false):
		if (l as Label).text == text:
			return (l as Label).get_global_rect()
	return Rect2()


func _shot(name: String) -> void:
	await _wait(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
