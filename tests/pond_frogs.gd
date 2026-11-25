extends SceneTree
## The frogs at the water (see PondFrogs): a few on the banks and in the water of the ponds and the river, they
## move, they croak more at night, and they hibernate in winter. With SHOTS=<folder> and a display it also
## takes pictures of them.
## Run with: godot --headless --fixed-fps 60 -s tests/pond_frogs.gd

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


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Frog test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	await _season(_first("summer"))
	var lvl: Outdoor = game.level
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	await _wait(10)
	var frogs: PondFrogs = lvl.pond_frogs
	check(frogs != null, "the outdoor map has frogs")
	if frogs == null:
		quit(1)
		return
	var n := frogs._frogs.size()
	check(n >= 3 and n <= PondFrogs.MAX_FROGS, "a few frogs, not a crowd (%d)" % n)
	check(frogs.visible and not frogs.hibernating(), "the frogs are out in summer")
	# Everyone sits on the bank or swims in the water.
	var dry := 0
	var wet := 0
	for f in frogs._frogs:
		var shore := lvl.pond_shore_at(f.pos)
		if f.state == "swim":
			wet += 1
			check(shore > 0.3, "a swimming frog is in the water (%.2f)" % shore)
		else:
			dry += 1
			check(shore < 0.0 and shore > PondFrogs.BANK_FAR - 0.1, "a sitting frog is on the bank (%.2f)" % shore)
	check(dry > 0, "some frogs sit on the bank")
	# They move and hop, keep to bank and water, and croak.
	frogs.active_range = 1.0e9
	frogs._wake_near()
	var start: Array[Vector3] = []
	for f in frogs._frogs:
		start.append(f.pos)
	var states := {}
	var croaks := 0
	for i in 1500:
		frogs._process(0.1)
		for f in frogs._frogs:
			states[f.state] = true
			if f.croak_t >= 0.0 and f.croak_t < 0.11:
				croaks += 1
	var moved := 0
	for i in n:
		var f: Dictionary = frogs._frogs[i]
		if (f.pos as Vector3).distance_to(start[i]) > 0.5:
			moved += 1
		var shore := lvl.pond_shore_at(f.pos)
		if f.state != "hop":
			check(shore > BANK_FAR_SAFE, "frog %d ends on the bank or in the water (%.2f, %s)" % [i, shore, f.state])
	check(moved >= 1, "frogs hop about (%d of %d moved)" % [moved, n])
	check(states.has("hop") and states.has("swim") and states.has("sit"), "they sit, hop and swim (%s)" % str(states.keys()))
	check(croaks >= 1, "they croak (%d)" % croaks)
	# More often at night than by day, and less in autumn.
	game.day_hour = 12.0
	lvl.hour = 12.0
	lvl.night = false
	var day := frogs.croak_interval()
	lvl.hour = 23.0
	lvl.night = true
	var night := frogs.croak_interval()
	check(night.y < day.x, "at night the frogs croak more often than by day (%s, %s)" % [night, day])
	lvl.night = false
	lvl.hour = 12.0
	# Far from the hero the frogs are hidden and paused.
	frogs.active_range = 0.5
	frogs._wake_near()
	var hidden := 0
	for f in frogs._frogs:
		if not (f.node as Node3D).visible:
			hidden += 1
	check(hidden >= n - 1, "far frogs are paused and hidden (%d of %d)" % [hidden, n])
	frogs.active_range = 1.0e9
	frogs._wake_near()
	# Pictures.
	if shots != "":
		for f in frogs._frogs:
			if f.state == "sit":
				var p: Vector3 = f.pos
				await _shot("frog_bank", p + Vector3(0.5, 0.35, 0.7), p + Vector3(0, 0.08, 0))
				break
		for f in frogs._frogs:
			if f.state == "swim":
				var p: Vector3 = f.pos
				await _shot("frog_swim", p + Vector3(0.5, 0.35, 0.7), p + Vector3(0, 0.0, 0))
				break
	# Winter: hibernating, nothing to see.
	await _season(_first("winter"))
	frogs._wake_near()
	check(frogs.hibernating() and not frogs.visible, "the frogs hibernate in winter")
	await _season(_first("summer"))
	frogs._wake_near()
	check(frogs.visible, "spring brings the frogs back")
	lvl.set_ice(1.0)
	frogs._wake_near()
	check(not frogs.visible, "frozen water: the frogs are gone under")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: pond_frogs")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


const BANK_FAR_SAFE := -1.2
