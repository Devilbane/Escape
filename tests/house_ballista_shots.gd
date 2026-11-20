extends SceneTree
## Headless test: ballistae on a house (see HouseBallista): one on a flat roof
## and one in the garden get built, shoot at a slime that comes near, and the
## blueprint bar still fits the screen with the ballista tool.
## Run with: godot --headless --fixed-fps 60 -s tests/house_ballista_shots.gd
## With SHOTS=<folder> and a display it also saves pictures of the house, a bolt
## in flight, a close look at one and the blueprint with the ballista's reach.

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
	if shots != "":
		Lang.language = OS.get_environment("SHOT_LANG") if OS.get_environment("SHOT_LANG") != "" else "en"
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
	if shots != "":
		game._title.visible = false
	game.hero_name = "Ballista shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false
	var found := Rect2i()
	for y in range(lvl.height - 5):
		for x in range(lvl.grid[y].length() - 5):
			if Plots.problem(lvl, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(lvl, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sketcher: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sketcher.plan
	# A small house with a flat roof, a ballista on it and one in the garden.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch_roof(plan.cells_between(Vector2i(1, 1), Vector2i(3, 3)), HouseSketch.SLAB, 0)
	plan.sketch_ballista(2, 2, 1)
	plan.sketch_ballista(6, 6, 0)
	plan.deposit(HouseSketch.STONE, 200)
	plan.deposit(HouseSketch.TIMBER, 200)
	plan.order()
	for i in 200:
		if not sketcher.work_once():
			break
	check(plan.count(HouseSketch.BALLISTA, HouseSketch.BUILT) == 2, "both ballistae stand")
	check(sketcher.ballistae().size() == 2, "both are on the map")
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.dead = true
			e.global_position = Vector3(0, -50, 0)
	var n := plan.nodes()
	var mid := plan.node_world(n.x / 2, n.y / 2)
	game.player.global_position = mid + Vector3(-4, 0, Level.TILE * 2)
	await _shot("ballista_house", mid + Vector3(10, 9, 14), mid + Vector3(0, 2, 0))
	# Close up on the one in the garden, from the front and from behind.
	var garden: HouseBallista = sketcher.ballistae()[0]
	for gun: HouseBallista in sketcher.ballistae():
		if gun.global_position.y < garden.global_position.y:
			garden = gun
	var foot := garden.global_position
	await _shot("ballista_close", foot + Vector3(-2.6, 2.1, 3.0), foot + Vector3(0, 0.9, 0.2))
	await _shot("ballista_back", foot + Vector3(-2.2, 2.0, -2.8), foot + Vector3(0, 0.9, 0.3))
	# A slime comes near: both turn to it and shoot.
	var slime := lvl.spawn_slime("schleim", mid + Vector3(12, 0, -3), {})
	slime.rated_level = Enemy.fit_level(slime.kind, slime._stats, slime.hardening, 18, SlimeGrowth.MAX_LEVEL)
	SlimeGrowth.blob_up(slime)
	slime.hp = slime.max_hp()
	var life := slime.hp
	var shot := 0
	for gun: HouseBallista in sketcher.ballistae():
		while gun.shots == 0 and shot < 300:
			await _wait(1)
			shot += 1
	await _wait(4)
	await _shot("ballista_bolt", mid + Vector3(4, 7, 13), mid + Vector3(6, 1.5, -2))
	await _wait(60)
	check(slime.hp < life, "the slime is hit (%d -> %d)" % [life, slime.hp])
	await _shot("ballista_hit", mid + Vector3(4, 7, 13), mid + Vector3(8, 1.5, -2))
	# The blueprint with the ballista tool: the reach shows round each ballista.
	sketcher.enter()
	sketcher.select_tool(HouseSketcher.TOOL_BALLISTA)
	sketcher.hover(plan.cell_world(0, 6))
	await _wait(5)
	var width: float = sketcher._bar.size.x
	check(width <= 1280.0 - 16.0, "the blueprint bar fits the screen (%d px)" % int(width))
	if shots != "":
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = true
		await _wait(40)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("ballista_blueprint.png"))
	sketcher.leave()
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house ballista shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


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
