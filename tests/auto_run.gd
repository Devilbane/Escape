extends SceneTree
## Headless test for running to a spot picked on the map (see AutoRun): a click on an explored tile of
## the map, or on a place in its list, closes the window and sends the hero running there along the
## path finding, with a ring and a dotted route on the ground (AutoRunMarker). A step of the player's
## own, a jump or a hit calls the run off; a spot no way leads to leaves the window open with a note.
## Run with: godot --headless --fixed-fps 60 -s tests/auto_run.gd

const HERO := "Auto run test"
const MAX_FRAMES := 3600

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
	Storage.use(Storage.Memory.new())
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


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: auto run")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Lets the journal look at everything around the hero as if some time had passed.
func _look() -> void:
	if game.level.fog != null:
		game.level.fog._recompute(game.player.global_position)
	game.journal._timer = 0.0
	game.journal.update(0.0)


## An open tile about `tiles` tiles from the hero that a way leads to and the hero has seen.
func _open_tile(tiles: int) -> Vector2i:
	var here: Vector2i = game.level.world_to_cell(game.player.global_position)
	var file: String = game.journal.current_file()
	var from: Vector2i = game.level.set_out_cell(game.player.global_position)
	for d in range(tiles, tiles + 12):
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				var c := here + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == d and game.level.astar.is_in_boundsv(c) and not game.level.astar.is_point_solid(c) \
						and game.journal.is_explored(file, c) and not game.level.grid_path(from, c).is_empty():
					return c
	return Vector2i(-1, -1)


func _open_map() -> MapView:
	game.menus.map_page = "karte"
	game.menus.open("karte")
	return game.menus._box.find_child("MapView", true, false)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = HERO
	game.journal.clear()
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	_look()
	var villagers = game.level.get("villagers")
	if villagers != null:
		for v in villagers:
			if is_instance_valid(v):
				v.collision_layer = 0

	var view := _open_map()
	check(view != null and view.pickable, "the map can be clicked on the floor the hero stands on")
	var goal_cell := _open_tile(4)
	check(goal_cell.x >= 0, "an explored open tile lies near the hero")
	if goal_cell.x < 0:
		_finish()
		return

	# A click on the map: the window closes and the hero runs.
	view.tile_picked.emit(goal_cell)
	await _wait(3)
	check(not game.menus.is_open(), "the click closes the window")
	check(game.auto_run.active, "the hero is on the way")
	check(not game.player.path.is_empty(), "the hero has a way to run")
	var marker: AutoRunMarker = null
	for child in game.level.get_children():
		if child is AutoRunMarker:
			marker = child
	check(marker != null, "a marker shows where the hero runs")
	await _wait(30)
	check(marker != null and marker._dots.multimesh.visible_instance_count > 0, "a dotted route shows the way")
	check(game.player.sprinting or game.player.winded, "the hero runs")
	for i in MAX_FRAMES:
		await process_frame
		if not game.auto_run.active:
			break
	var gap := Vector2(game.player.global_position.x - game.level.cell_to_world(goal_cell).x, game.player.global_position.z - game.level.cell_to_world(goal_cell).z).length()
	check(not game.auto_run.active and gap <= Level.TILE * 1.5, "the hero arrived (%.1f m away)" % gap)
	await _wait(40)
	check(not is_instance_valid(marker), "the marker is gone once there")

	# A place of the list does the same.
	_look()
	view = _open_map()
	var button: Button = null
	for b in game.menus._box.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text == Lang.t("Dorthin laufen"):
			button = b
			break
	check(button != null, "the list of places has run buttons")
	if button != null:
		button.pressed.emit()
		await _wait(3)
		check(not game.menus.is_open() and game.auto_run.active, "a place of the list sends the hero running")

	# A step of the player's own calls the run off, so does a jump or a hit.
	await _wait(10)
	Input.action_press("ui_left")
	await _wait(2)
	Input.action_release("ui_left")
	check(not game.auto_run.active, "a step of the player's own stops the run")
	await _wait(30)
	game.player.global_position = game.level.cell_to_world(game.level.start_cell)
	_look()
	game.menus.close()
	view = _open_map()
	view.tile_picked.emit(_open_tile(4))
	await _wait(5)
	game.player.hurt.emit(1)
	await _wait(2)
	check(not game.auto_run.active, "a hit stops the run")

	# A spot no way leads to: the window stays open and says so.
	_look()
	game.menus.close()
	view = _open_map()
	var far := Vector2i(-50, -50)
	view.tile_picked.emit(far)
	await _wait(2)
	check(game.menus.is_open() and not game.auto_run.active, "an unreachable spot leaves the window open")
	check(view.get_node_or_null("MapNote") != null, "a note on the map says why")

	game.menus.close()
	_finish()
