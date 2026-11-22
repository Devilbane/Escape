extends SceneTree
## Pictures of a villager's house from inside (see WalkIn._furnish_house): the ground floor with its
## table, shelf and stores, and a villager on the ladder up to the floor above (see VillageBeds),
## low on the rungs and with the head through the hatch.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/villager_ladder_shots.gd

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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Ladder shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var houses: Array = lvl.walk_in.buildings.filter(func(r): return r.kind == "house")
	check(not houses.is_empty(), "the village has houses")
	var rec: Dictionary = houses[0]
	var way: Array[Vector3] = lvl.walk_in.door_points(rec)
	var hero: Player = game.player
	hero.global_position = way[1].lerp(rec.node.global_position, 0.25)
	hero.reset_physics_interpolation()
	await _wait(30)
	var v: Villager = lvl.villagers[0]
	v.global_position = rec.ladder
	v.bed_trip = {"house": rec, "bed": {}, "step": "in", "way": [], "t": 0.0, "clock": 0.0}
	VillageBeds._start_climb(v, v.bed_trip, true)
	for t: float in [1.0, 1.7]:
		v.process_mode = Node.PROCESS_MODE_INHERIT
		v.bed_trip.t = 0.0
		VillageBeds._climb(v, v.bed_trip, t)
		v.process_mode = Node.PROCESS_MODE_DISABLED
		var name := "climb_%d" % int(t * 10)
		await _shot(name + "_room", null, Vector3.ZERO)
		var push: Vector3 = rec.ladder_push
		var side := Vector3(-push.z, 0, push.x)
		var at: Vector3 = (rec.ladder_edge as Vector3) + Vector3(0, 1.6, 0)
		hero.visible = false
		await _shot(name + "_close", at - push * 3.2 + side * 1.6 + Vector3(0, 1.4, 0), at - push * 0.6)
		hero.visible = true
	# The room alone, from the game's camera and from the doorway.
	v.visible = false
	hero.visible = false
	await _shot("room", null, Vector3.ZERO)
	var mid: Vector3 = (rec.node as Node3D).global_position + Vector3(0, 1.0, 0)
	await _shot("room_doorway", way[0] + Vector3(0, 2.6, 0), mid)
	# Upstairs: the hero at the top of the ladder, a villager asleep in a bed.
	hero.visible = true
	hero.global_position = rec.ladder_top
	hero.reset_physics_interpolation()
	var sleeper: Villager = lvl.villagers[1]
	sleeper.bed_trip = {"house": rec, "bed": rec.beds[0], "step": "in", "way": [], "t": 0.0, "clock": 0.0}
	rec.beds[0].by = sleeper
	VillageBeds._settle(sleeper)
	sleeper.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(30)
	check(lvl.walk_in.hero_upstairs_in(rec), "the hero is upstairs")
	sleeper.visible = true
	await _shot("upstairs", null, Vector3.ZERO)
	var up_mid: Vector3 = (rec.node as Node3D).global_position + Vector3(0, 4.5, 0)
	hero.visible = false
	await _shot("upstairs_close", up_mid + Vector3(0, 2.5, 4.5), up_mid - Vector3(0, 1.0, 0.5))
	# A window from outside, with its shutters.
	hero.visible = true
	hero.global_position = way[0] + Vector3(0, 0.2, 6.0)
	hero.reset_physics_interpolation()
	await _wait(30)
	var shape: Dictionary = (rec.node as Node3D).get_meta("shape")
	var fx: float = VillageHouse._window_spots(float(shape.w), float(shape.door_x))[0]
	var pane := (rec.node as Node3D).global_transform * Vector3(fx, VillageHouse.PLINTH + 1.6, float(shape.d) * 0.5)
	await _shot("window", pane + (rec.node as Node3D).global_transform.basis * Vector3(0.6, 0.4, 2.6), pane)
	var upper_pane := (rec.node as Node3D).global_transform * Vector3(0, VillageHouse.PLINTH + VillageHouse.GROUND + 1.3, float(shape.d) * 0.5 + VillageHouse.JETTY)
	await _shot("upper_windows", upper_pane + (rec.node as Node3D).global_transform.basis * Vector3(0, 0.4, 5.5), upper_pane)
	print("PASS: villager ladder shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## A picture from the game's camera (`from` null) or from `from` looking at `at`.
func _shot(name: String, from, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam: Camera3D = null
	if from != null:
		cam = Camera3D.new()
		cam.fov = 55.0
		root.add_child(cam)
		cam.global_position = from
		cam.look_at(at)
		cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	if cam != null:
		cam.queue_free()
		game.camera.make_current()
