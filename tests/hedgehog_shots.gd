extends SceneTree
## Pictures of the village hedgehog (see Hedgehog): close up and from a game-like camera, and where the
## hedgehogs with an apple hoard live.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/hedgehog_shots.gd

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
	game._title.visible = false
	game.hero_name = "Hedgehog shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	await _season(_first(Weather.AUTUMN))
	var hogs: Array[Hedgehog] = level.woods.hedgehogs
	for h in hogs:
		print("hedgehog village=%s hoard=%s at %s hero start %s" % [h.is_village(), h.hoard != null, h.global_position, game.player.global_position])
	var village := hogs.filter(func(h: Hedgehog): return h.is_village())
	check(village.size() >= 1, "there is a village hedgehog")
	if village.is_empty():
		quit(1)
		return
	var a: Hedgehog = village[0]
	for h: Hedgehog in village:
		if h.hoard != null:
			a = h
	game.player.global_position = a.global_position + Vector3(30, 0, 0)
	await _wait(60)
	# Holds it still, mid-stride, so that the camera finds it where it stands.
	a.set_physics_process(false)
	# Onto the open meadow by the start, away from walls and hay.
	var meadow: Vector3 = level.cell_to_world(level.world_to_cell(Vector3(48, 0, 24)))
	a.global_position = Vector3(meadow.x, 0.0, meadow.z)
	a.reset_physics_interpolation()
	a.rotation.y = 0.6
	a._path.clear()
	a.state = "walk"
	a._phase = 1.1
	a._curl = 0.0
	a._pose(0.0)
	var at := a.global_position
	var side := a.global_transform.basis.x.normalized()
	var front := a.global_transform.basis.z.normalized()
	await _shot("hog_game", at + Vector3(0, 4.5, 4.5), at + Vector3(0, 0.2, 0))
	await _shot("hog_side", at + side * 1.3 + Vector3(0, 0.45, 0), at + Vector3(0, 0.22, 0))
	await _shot("hog_front", at + front * 1.1 + side * 0.5 + Vector3(0, 0.5, 0), at + Vector3(0, 0.25, 0))
	a.state = "snuffle"
	a._pose(0.0)
	await _shot("hog_snuffle", at + front * 0.9 - side * 0.5 + Vector3(0, 0.4, 0), at + Vector3(0, 0.25, 0))
	print("PASS: hedgehog shots" if failures == 0 else "FAILED: %d" % failures)
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
