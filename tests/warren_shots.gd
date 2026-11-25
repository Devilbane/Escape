extends SceneTree
## Pictures of the rabbit burrow (see Warren.burrow) in summer, autumn and winter: from the game's own
## camera and close up. Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/warren_shots.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
## Which seasons to picture (ONLY=autumn takes one).
var SEASONS: Array = [["summer", Weather.SUMMER], ["autumn", Weather.AUTUMN], ["winter", Weather.WINTER]].filter(func(s): return OS.get_environment("ONLY") in ["", s[0]])


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
	game.hero_name = "Warren shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var holes := level.find_children("Burrow", "Node3D", true, false)
	check(holes.size() >= 1, "the meadows have a burrow")
	var hole: Node3D = holes[0]
	var at := hole.global_position
	for s in SEASONS:
		game.player.global_position = at + Vector3(30, 0, 0)
		await _season(_first(s[1]))
		# Snow takes a while to settle.
		await _wait(600 if s[0] == "winter" else 120)
		await _shot("burrow_%s_close" % s[0], at + Vector3(0.6, 1.1, 1.7), at + Vector3(0, 0.05, 0), false)
		game.player.global_position = at + Vector3(0, 0, 3.5)
		await _wait(90)
		await _shot("burrow_%s_game" % s[0], Vector3.ZERO, Vector3.ZERO, true)
	print("PASS: warren shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, look: Vector3, own_camera: bool) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam: Camera3D = null
	if not own_camera:
		cam = Camera3D.new()
		cam.fov = 50.0
		root.add_child(cam)
		cam.global_position = from
		cam.look_at(look)
		cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	if cam != null:
		cam.queue_free()
	game.camera.make_current()
