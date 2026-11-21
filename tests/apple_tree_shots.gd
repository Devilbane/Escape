extends SceneTree
## Pictures of the apple trees (see AppleTree): the four round the village fountain in each season,
## and a garden tree on a plot at each stage of its growth in summer.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/apple_tree_shots.gd

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
	HouseFurniture.reload()
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


## Moves the game's season to season day `d` (by the day count, or the season shift where the
## seasons follow the calendar).
func _season(d: int) -> void:
	if "season_shift" in game:
		game.season_shift += d - game.level.season_day
	else:
		game.day = d
	game.day_hour = 12.0
	await _wait(30)


func _first(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d + 2
	return 0


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Apple shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var round_fountain := level.square_trees.filter(func(t): return not t.get("garden", false) and not t.get("pocket", false))
	check(round_fountain.size() == 4, "four apple trees round the fountain (%d)" % round_fountain.size())
	var fountain := Vector3.ZERO
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == "F":
				fountain = level.cell_to_world(Vector2i(x, y))
	game.player.global_position = fountain + Vector3(0, 0, 6)
	for season in Weather.SEASONS:
		await _season(_first(season))
		await _shot("square_" + season, fountain + Vector3(10, 11, 17), fountain)
	await _season(_first(Weather.SUMMER))
	await _shot("square_close", fountain + Vector3(-7, 3.5, 9), fountain + Vector3(-3, 2.5, 3))
	# The apple trees in the village's gardens, from above, and one close in autumn.
	await _shot("village_summer", fountain + Vector3(0, 34, 30), fountain + Vector3(0, 0, -6))
	await _season(_first(Weather.AUTUMN))
	await _shot("village_autumn", fountain + Vector3(0, 34, 30), fountain + Vector3(0, 0, -6))
	var gardens := level.square_trees.filter(func(t): return t.get("garden", false))
	if not gardens.is_empty():
		var tree: Vector3 = (gardens[0].node as Node3D).position
		await _shot("garden_tree_autumn", tree + Vector3(5, 3.5, 7), tree + Vector3(0, 3, 0))
	await _season(_first(Weather.SUMMER))
	# A garden: one tree of each stage.
	var found := Rect2i()
	for y in range(level.height - 5):
		for x in range(level.grid[y].length() - 5):
			if Plots.problem(level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var plan: HouseSketch = game.house_sketcher.plan
	var store := HouseFurniture.of(game.hero_name)
	for stage in 4:
		store.add(AppleTree.KIND)
		check(store.place(plan, AppleTree.KIND, 0, stage * 2, 1, 0, {"planted": 0}) == "", "tree %d planted" % stage)
	store.save(game.hero_name)
	var mid := plan.cell_world(3, 1)
	game.player.global_position = plan.cell_world(3, 4)
	for s in [Weather.SUMMER, Weather.SPRING, Weather.AUTUMN, Weather.WINTER]:
		await _season(_first(s) + Weather.YEAR_DAYS * 3)
		_stages()
		await _shot("garden_" + s, mid + Vector3(0, 6, 16), mid + Vector3(0, 1.5, 0))
	print("PASS: apple tree shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The garden's trees, west to east: one of each stage on today's season day.
func _stages() -> void:
	var store := HouseFurniture.of(game.hero_name)
	var i := 0
	for p in store.placed:
		if p.kind == AppleTree.KIND:
			p.planted = game.level.season_day - AppleTree.STAGE_FROM[i] * AppleTree.season_days()
			i += 1
	store.save(game.hero_name)
	game.house_furnisher.refresh()


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
