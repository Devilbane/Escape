extends SceneTree
## Pictures of the ossuary (see Ossuary): the crypt's rooms with their shelves of skulls and a close look at the shelves of
## Madame Medusa and Mr. Snoops. SHOTS=<folder> saves the pictures.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/ossuary_shots.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var _cam: Camera3D
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
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


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _view(at: Vector3, offset: Vector3, look_at_offset := Vector3(0, 0.9, 0)) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 50.0
		root.add_child(_cam)
		_cam.make_current()
	_cam.global_position = at + offset
	_cam.look_at(at + look_at_offset)


func _light(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.omni_range = 9.0
	l.light_energy = 2.5
	root.add_child(l)
	l.global_position = at


func _run() -> void:
	game._title.visible = false
	game.hero_name = "Ossuary shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	game.treasure_maps.state[OwlClock.ID] = TreasureMaps.OPEN
	game.go_inside(OwlClock.ID)
	await _wait(120)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game._fade.color = Color(0, 0, 0, 0)
	var crypt: Level = game.level
	if crypt.fog != null:
		crypt.fog.visible = false
	var shelves := crypt.stations.filter(func(s): return s.kind == Ossuary.KIND)
	print("shelves: ", shelves.size(), " at ", shelves.map(func(s): return s.cell))
	check(shelves.size() >= 8, "shelves stand in the crypt")
	game.player.global_position = crypt.cell_to_world(Vector2i(13, 9)) + Vector3(0, 0, 2)
	game.player.reset_physics_interpolation()
	await _wait(20)
	_view(crypt.cell_to_world(Vector2i(13, 9)), Vector3(0, 30, 22), Vector3(0, 0, 0))
	await _wait(5)
	await _shot("ossuary_overview")
	for s: Dictionary in shelves:
		if s.skull == "":
			continue
		var inward: Vector3 = s.unit.global_transform.basis.z
		var at: Vector3 = s.unit.global_position + Vector3(0, 1.2, 0)
		_light(at + inward * 1.5 + Vector3(0, 1.0, 0))
		_view(at, inward * 2.8 + Vector3(0, 0.6, 0), Vector3(0, 0, 0))
		await _wait(5)
		await _shot("ossuary_" + str(s.skull))
	var first: Dictionary = shelves[0]
	var f_in: Vector3 = first.unit.global_transform.basis.z
	_light(first.unit.global_position + f_in * 2.0 + Vector3(0, 2.0, 0))
	_view(first.unit.global_position + Vector3(0, 1.2, 0), f_in * 5.0 + Vector3(0, 3.0, 0), Vector3(0, 0, 0))
	await _wait(5)
	await _shot("ossuary_shelf")
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: ossuary shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
