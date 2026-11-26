extends SceneTree
## Pictures of the owl clock riddle (see OwlClock): the graveyard on a full-moon night with the clock owl in
## its dead tree, a gravestone close up, the open crypt's stairwell and the crypt's rooms. It also checks the
## crypt's map is entered by its building id and that the stairs stand once the way is open.
## SHOTS=<folder> saves the pictures.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/owl_clock_shots.gd

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


func _hide_hud() -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game._fade.color = Color(0, 0, 0, 0)


func _run() -> void:
	game._title.visible = false
	game.hero_name = "Owl clock shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var night := 0
	while not Moon.is_full(night):
		night += 1
	game.day = night
	game.day_hour = 23.5
	await _wait(20)
	_hide_hud()
	var lvl: Outdoor = game.level
	var grave := lvl.owlav_pos
	var hero: Player = game.player
	hero.global_position = lvl.cell_to_world(lvl.start_cell)
	hero.reset_physics_interpolation()
	game.treasure_maps.state[OwlClock.ID] = ""
	await _wait(10)
	_view(grave, Vector3(6, 9, 16), Vector3(0, 0.5, -2))
	await _wait(25)
	await _shot("graveyard_night")
	_view(grave, Vector3(0, 2.2, 5.0), Vector3(0, 1.0, -0.6))
	await _wait(3)
	await _shot("owlav_grave_closed")
	# Before the riddle the way down is not there: the ground in front of the grave is plain.
	_view(grave + Vector3(0, 0, 1.75), Vector3(0, 6.0, 4.5), Vector3(0, 0, 0))
	await _wait(3)
	await _shot("front_of_grave_closed")
	# Open it.
	game.treasure_maps.state[OwlClock.ID] = TreasureMaps.OPEN
	OwlClock.build_stairs(lvl, grave, false)
	await _wait(5)
	check(not lvl.stations.filter(func(s): return s.get("building", "") == OwlClock.ID).is_empty(), "the way down is a station once open")
	_view(grave + Vector3(0, 0, 1.75), Vector3(0, 6.0, 4.5), Vector3(0, 0, 0))
	await _wait(3)
	await _shot("front_of_grave_open")
	_view(grave, Vector3(4, 4, 9), Vector3(0, 0.3, 1.5))
	await _wait(3)
	await _shot("crypt_way_open")
	# Counter stone and a read stone.
	var counter: Dictionary = lvl.stations.filter(func(s): return s.get("counter", false))[0]
	game._use_station(counter)
	await _wait(5)
	var tell: String = game.riddles.card(lvl.level_name)
	check(tell.contains("Apple Valley") and tell.contains("00/02"), "the counter reads in English: %s" % tell)
	# Inside.
	game.go_inside(OwlClock.ID)
	await _wait(120)
	_hide_hud()
	check(game.level.building == OwlClock.ID, "the way leads into the crypt")
	var inner: Level = game.level
	var mid := inner.cell_to_world(Vector2i(13, 9))
	_view(mid, Vector3(0, 22, 12), Vector3(0, 0, 0))
	await _wait(10)
	await _shot("crypt_overview")
	_view(mid, Vector3(0, 9, 11), Vector3(0, 0.5, 0))
	await _wait(5)
	await _shot("crypt_hub")
	var vault := inner.cell_to_world(Vector2i(13, 17))
	_view(vault, Vector3(0, 8, 9), Vector3(0, 0.5, 1))
	await _wait(5)
	await _shot("crypt_vault")
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: owl clock shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
