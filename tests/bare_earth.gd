extends SceneTree
## Headless test: a cellar left bare in the house builder gets the earth material
## (see BareEarth), not a flat colour, and its picture really varies in tone.
## Run with: godot --headless --fixed-fps 60 -s tests/bare_earth.gd
## With SHOTS=<folder> and a display it also saves pictures of the bare cellar.

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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Earth test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	# The picture: several shades, not one flat brown.
	var img := BareEarth.texture().get_image()
	img.decompress()
	var low := 1.0
	var high := 0.0
	for i in 400:
		var l := img.get_pixel((i * 37) % img.get_width(), (i * 91) % img.get_height()).get_luminance()
		low = minf(low, l)
		high = maxf(high, l)
	check(high - low > 0.15, "the earth varies in tone (%.2f to %.2f)" % [low, high])
	check(BareEarth.material() == BareEarth.material(), "every bare face shares one material")
	var found := Rect2i()
	for y in range(game.level.height - 5):
		for x in range(game.level.grid[y].length() - 5):
			if Plots.problem(game.level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sketcher: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sketcher.plan
	plan.deposit("steinblock", 40)
	plan.deposit("bauholz", 20)
	plan.sketch_dig(plan.cells_between(Vector2i(3, 3), Vector2i(5, 5)))
	plan.sketch_stairs(1, 3, "e")
	plan.ordered = true
	for i in 30:
		sketcher.work_once()
	await _wait(5)
	var earthy := 0
	for mi: MeshInstance3D in sketcher.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == BareEarth.material():
			earthy += 1
	check(earthy > 4, "the bare cellar floor and walls are earth (%d faces)" % earthy)
	if shots != "":
		game.level.set_hour(12.0)
		var pit := plan.cell_world(4, 4)
		game.player.global_position = plan.node_world(0, 0) + Vector3(-6, 0, -6)
		await _shot("bare_cellar", pit + Vector3(5, 6, 7), pit + Vector3(0, -2.4, 0))
		await _shot("bare_cellar_close", pit + Vector3(1.2, -0.8, 1.6), pit + Vector3(-1.5, -2.4, -1.2))
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: bare earth" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
