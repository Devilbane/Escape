extends SceneTree
## Pictures of the snow where the mountain's foot meets the snow-covered ground in winter (see snow_cover.gdshader).
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/mountain_snow_edge_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
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


func _shot(lvl: Level, name: String, cell: Vector2i, from: Vector3, to: Vector3, fov := 55.0) -> Image:
	var mid := lvl.cell_to_world(cell)
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = mid + from
	cam.look_at(mid + to)
	cam.make_current()
	await _wait(10)
	var image := root.get_texture().get_image()
	if shots != "":
		image.save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	return image


## The mean brightness (0..1) of a part of a picture, given as fractions of its width and height.
func _brightness(image: Image, x0: float, y0: float, x1: float, y1: float) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var total := 0.0
	var count := 0
	for y in range(int(h * y0), int(h * y1), 2):
		for x in range(int(w * x0), int(w * x1), 2):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(1.0, count)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Edge"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	lvl.set_hour(12.0)
	game.set_weather(Weather.SNOW, 3.0)
	game.snow_cover = 1.0
	game.player.global_position = lvl.cell_to_world(Vector2i(84, 58))
	game.player.visible = false
	await _wait(200)
	# A foot of the mountain seen from the south, near and low, and from further away and higher.
	var cell := Vector2i(84, 54)
	var near: Image = await _shot(lvl, "edge_near", cell, Vector3(0, 1.6, 9.0), Vector3(0, 1.2, 0))
	await _shot(lvl, "edge_far", cell, Vector3(6, 7.0, 22.0), Vector3(0, 1.5, 0), 60.0)
	var other := Vector2i(100, 56)
	await _shot(lvl, "edge_second", other, Vector3(-5, 3.0, 12.0), Vector3(0, 1.0, 0))
	# The snow on the lowest part of the face is as bright as the plain's in front of it (it was a dull grey-blue band
	# with a hard line where the plain ended), and the very foot has no bare rock showing between them.
	var foot := _brightness(near, 0.35, 0.56, 0.65, 0.65)
	var plain := _brightness(near, 0.35, 0.72, 0.65, 0.8)
	print("foot %.3f plain %.3f" % [foot, plain])
	var ok := foot > plain * 0.92
	print("PASS: mountain snow edge" if ok else "FAILED: the snow at the mountain's foot is much duller than the plain's")
	quit(0 if ok else 1)
