extends SceneTree
## Headless test for zooming the map and the houses on it (see MapView): the
## map zooms in until a tile is MAX_TILE pixels wide, the wheel keeps the point
## under the pointer, a drag moves the zoomed map, zooming never changes the
## window's size, the buttons switch off at the ends, the zoom is kept when the
## window is opened again, and a house built on a plot shows on the open map,
## piece by piece as it is built.
## Run with: godot --headless -s tests/map_zoom.gd
## With SHOTS=<folder> (needs a display) it also saves the map zoomed out and
## zoomed in on a house.

var failures := 0
var game: Node
var frames := 0
const HERO := "Kartenzoom Test"
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_setup()
	elif frames == 8:
		_run()
	return false


func _run() -> void:
	_test()
	if shots != "" and failures == 0:
		await _shoot()
	_clean_up()
	if failures == 0:
		print("PASS: map_zoom")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _clean_up() -> void:
	var empty := HouseSketch.of(HERO, plot)
	empty.pieces.clear()
	empty.save(HERO)
	Plots.release(HERO)
	game.delete_save(game.save_path())


var plot := Rect2i()
var outside := ""


func _setup() -> void:
	game.hero_name = HERO
	game.journal.clear()
	game.load_level(game._outdoor_index())


func _wall_keys(house: HouseSketch) -> Array:
	var out := []
	for key in house.pieces:
		if house.pieces[key].kind == HouseSketch.WALL:
			out.append(key)
	return out


func _view() -> MapView:
	return game.menus._box.find_child("MapView", true, false)


func _test() -> void:
	var j: Journal = game.journal
	outside = j.current_file()
	var info := j.map_of(outside)
	check(not info.is_empty() and info.outdoor, "the test runs on the open map (" + outside + ")")
	if info.is_empty() or not info.outdoor:
		return
	# A plot of bare grass, found on the map, and a little house sketched on it.
	Plots.release(HERO)
	for y in range(2, info.height - 6):
		for x in range(2, info.width - 6):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(game.level, r) == "":
				plot = r
				break
		if plot.size != Vector2i.ZERO:
			break
	check(plot.size != Vector2i.ZERO and Plots.register(game.level, HERO, plot) == "", "a plot is registered")
	var house := HouseSketch.of(HERO, plot)
	house.pieces.clear()
	house.sketch(house.run_between(Vector2i(1, 1), Vector2i(4, 1)), HouseSketch.WALL)
	house.save(HERO)
	var c := plot.get_center()
	game.player.global_position = game.level.cell_to_world(c + Vector2i(0, 4))
	j._timer = 0.0
	j.update(0.0)
	# The whole open map seen, so the map starts small and has far to zoom.
	var seen := PackedByteArray()
	seen.resize(info.width * info.height)
	seen.fill(1)
	j.explored[outside] = seen

	game.state = game.State.PLAYING
	game.menus.map_page = "karte"
	game.menus.open("karte")
	var view := _view()
	check(view != null, "the map window shows a map")
	if view == null:
		return
	# Houses: the plot shows; a sketched house is not "built" yet.
	var own := view.own_house()
	check(not own.is_empty() and own.plot == plot, "the hero's plot is on the map")
	check(not own.is_empty() and not own.built and own.edges.size() == 3, "the sketched walls are on the map, not built")
	var legend := func(text: String) -> bool:
		for l in game.menus._box.find_children("*", "Label", true, false):
			if (l as Label).text == Lang.t(text):
				return true
		return false
	check(legend.call("Dein Grundstück"), "the legend names the plot while nothing is built")
	# Build one wall: the house shows as built at once.
	house = HouseSketch.of(HERO, plot)
	var key: String = _wall_keys(house)[0]
	house.pieces[key].state = HouseSketch.BUILT
	house.save(HERO)
	game.menus._rebuild()
	view = _view()
	own = view.own_house()
	var built: Array = own.edges.filter(func(e): return e[3])
	check(own.built and built.size() == 1, "a built wall shows as built")
	check(legend.call("Dein Haus"), "the legend names the house once a piece stands")
	var parts: Array = HouseSketch.parts_of(key)
	var expect: Vector2 = Vector2(plot.position) + Vector2(parts[1], parts[2]) / 2.0
	check(built.size() == 1 and built[0][0].distance_to(expect) < 0.01, "the wall sits where it stands on the plot")

	# Zoom: the window keeps its size whatever the map does.
	var panel_rect: Rect2 = game.menus._panel.get_global_rect()
	var view_rect := view.get_global_rect()
	check(view.zoom == 1.0 or game.menus._map_zoom.has(outside), "a fresh map starts whole")
	view.zoom_fit()
	check(game.menus._zoom_out.disabled and game.menus._zoom_fit.disabled, "zoomed out fully, out and whole switch off")
	check(not game.menus._zoom_in.disabled, "zoom in is possible")
	var fit := view.tile_size()
	var steps := 0
	while view.can_zoom_in() and steps < 50:
		game.menus._zoom_in.pressed.emit()
		steps += 1
	check(absf(view.tile_size() - MapView.MAX_TILE) < 0.5, "the closest zoom shows a tile %d px wide (%.1f)" % [MapView.MAX_TILE, view.tile_size()])
	check(view.tile_size() > fit, "zooming in makes the tiles bigger")
	check(game.menus._zoom_in.disabled and not game.menus._zoom_out.disabled, "at the closest zoom, zoom in switches off")
	check(game.menus._panel.get_global_rect() == panel_rect and view.get_global_rect() == view_rect, "zooming does not move or resize the window")
	# The wheel keeps the point under the pointer.
	# (Away from the edge of the map, which the view never leaves.)
	view.zoom_fit()
	view.zoom_at(1.0)
	check(view.fit_tile() < 10.0, "the whole open map starts with small tiles (%.1f px)" % view.fit_tile())
	var zoom_before := view.zoom
	var at := view.size * Vector2(0.45, 0.55)
	var under := view.tile_at(at)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = at
	view._gui_input(wheel)
	check(view.zoom > zoom_before, "the wheel zooms in")
	check(view.tile_at(at).distance_to(under) < 0.05, "the wheel keeps the point under the pointer")
	# A drag moves the zoomed map.
	view.zoom_at(2.0)
	var before := view.view_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	view._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(40, 0)
	view._gui_input(move)
	press.pressed = false
	view._gui_input(press)
	check(view.view_center().x < before.x or view.view_center().x == before.x and before.x <= view._view.position.x + view.size.x / view.tile_size() * 0.5 + 0.01,
			"dragging moves the map")
	# Keys: + zooms, 0 shows it whole.
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_0
	check(game.menus._map_zoom_key(key_event) and view.zoom == 1.0, "0 shows the whole map")
	key_event.physical_keycode = KEY_EQUAL
	check(game.menus._map_zoom_key(key_event) and view.zoom > 1.0, "+ zooms in")
	# Zoomed out, the house is a mark; it is drawn without errors either way.
	view.queue_redraw()
	# The zoom is kept when the window is opened again.
	var kept := view.zoom
	game.menus.close()
	game.menus.open("karte")
	check(is_equal_approx(_view().zoom, kept), "the map keeps its zoom when opened again")
	game.menus.close()


## A whole little house (walls, a door, a window, a floor and a roof, one wall
## still planned), then the map zoomed out and zoomed in on it.
func _shoot() -> void:
	var house := HouseSketch.of(HERO, plot)
	house.pieces.clear()
	for run in [[Vector2i(1, 1), Vector2i(5, 1)], [Vector2i(5, 1), Vector2i(5, 4)], [Vector2i(5, 4), Vector2i(1, 4)], [Vector2i(1, 4), Vector2i(1, 1)]]:
		house.sketch(house.run_between(run[0], run[1]), HouseSketch.WALL)
	house.sketch([[2, 4, HouseSketch.ORIENT_X]], HouseSketch.DOOR)
	house.sketch([[5, 2, HouseSketch.ORIENT_Y]], HouseSketch.WINDOW)
	for y in range(1, 4):
		for x in range(1, 5):
			house.pieces[HouseSketch.key_of(x, y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": HouseSketch.BUILT, "surface": "wood"}
			if x < 3:
				house.pieces[HouseSketch.key_of(x, y, "ry", 0)] = {"kind": HouseSketch.SADDLE, "state": HouseSketch.BUILT}
	for key in house.pieces:
		if not key.ends_with(":y") or HouseSketch.parts_of(key)[1] != 1:
			house.pieces[key].state = HouseSketch.BUILT
	house.save(HERO)
	game.menus.open("karte")
	var view := _view()
	view.zoom_fit()
	await _save("map_zoomed_out.png")
	view.zoom_at(3.0)
	view.center = Vector2(plot.get_center())
	view.queue_redraw()
	await _save("map_zoomed_middle.png")
	view.zoom_at(20.0)
	view.center = Vector2(plot.get_center())
	view.queue_redraw()
	await _save("map_zoomed_in.png")
	game.menus.close()


func _save(file: String) -> void:
	for i in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(file))
