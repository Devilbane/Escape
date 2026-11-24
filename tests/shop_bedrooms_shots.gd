extends SceneTree
## Pictures of the bedrooms above the shop (see WalkIn._bedroom, _partition): the parents' room and the
## children's room with the partition wall and its doorway between them, the four beds with their sleepers.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/shop_bedrooms_shots.gd

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
	WalkIn.lock_halls = false
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
	game.hero_name = "Bedroom shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var rec: Dictionary = {}
	for r: Dictionary in lvl.walk_in.buildings:
		if r.kind == "shop":
			rec = r
	check(rec.has("partition"), "the shop has two bedrooms")
	var hero: Player = game.player
	hero.global_position = rec.ladder_top
	hero.reset_physics_interpolation()
	var roles := ["6", "3", "7", "pippi"]
	for i in roles.size():
		for w: Villager in lvl.villagers:
			if w.role == roles[i]:
				w.bed_trip = {"house": rec, "bed": rec.beds[i], "step": "in", "way": [], "t": 0.0, "clock": 0.0}
				rec.beds[i].by = w
				VillageBeds._settle(w)
				w.process_mode = Node.PROCESS_MODE_DISABLED
				w.visible = true
	await _wait(40)
	var node: Node3D = rec.node
	var inv := node.global_transform
	var wall_x: float = rec.partition.x
	var up_y: float = float(rec.top) + VillageHouse.FLOOR_LIFT
	await _shot("room_game_camera", null, Vector3.ZERO)
	hero.visible = false
	# From the ladder end, along the beds and the wall.
	await _shot("both_rooms", inv * Vector3(wall_x - 3.2, up_y + 2.3, 2.6), inv * Vector3(wall_x + 0.3, up_y + 0.6, -1.4))
	# The wall's doorway from the front, and the parents' beds behind it.
	await _shot("doorway", inv * Vector3(wall_x - 1.8, up_y + 1.5, 2.2), inv * Vector3(wall_x + 0.4, up_y + 1.1, 0.0))
	# The children's room from its far wall, the wall and the parents' room beyond.
	await _shot("children_room", inv * Vector3(wall_x - 3.0, up_y + 1.9, -1.2), inv * Vector3(wall_x + 1.0, up_y + 0.9, -1.8))
	# The parents' room looking back through the doorway.
	await _shot("parents_room", inv * Vector3(wall_x + 3.0, up_y + 1.9, -1.2), inv * Vector3(wall_x - 1.0, up_y + 0.9, -1.8))
	# A close look at the wall's planks, frame and lintel.
	await _shot("wall_close", inv * Vector3(wall_x - 1.4, up_y + 1.7, 1.9), inv * Vector3(wall_x, up_y + 1.4, 1.0))
	print("PASS: shop bedrooms shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam: Camera3D = null
	if from != null:
		cam = Camera3D.new()
		cam.fov = 60.0
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
