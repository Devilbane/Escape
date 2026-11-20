extends SceneTree
## Headless test: built stairs in a house of the hero's own (stairs down into a
## cellar and stairs up to a floor slab) look like the wooden steps of the town
## houses on Weavers' Lane (see WoodStairs.build_flight): a flight of steps in
## the stairs' wood, while the hero still walks a smooth ramp (see
## HouseSketcher._ramp), and walks up out of the cellar onto a floor laid at
## their top. Run with: godot --headless --fixed-fps 60 -s tests/house_stairs_shots.gd
## With SHOTS=<folder> and a display it also saves pictures of both stairs.

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
	if shots != "":
		game._title.visible = false
	game.hero_name = "Stairs test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
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
	# A wooden cellar of two cells with stairs down to it from the west.
	plan.floor_surface = "wood"
	plan.wall_surface = "wood"
	plan.sketch_dig(plan.cells_between(Vector2i(3, 1), Vector2i(3, 2)))
	check(plan.sketch_stairs(1, 1, "e"), "stairs down are sketched")
	# A wooden floor on the ground where the stairs come up (it stands FLOOR_RISE over the grass).
	plan.ceiling_surface = "wood"
	plan.sketch_cover([[0, 0], [0, 1], [0, 2], [1, 0], [1, 2]])
	# A floor slab with stairs up to it.
	plan.sketch_roof(plan.cells_between(Vector2i(4, 4), Vector2i(5, 5)), HouseSketch.SLAB, 0)
	check(plan.sketch_upstairs(2, 4, "e"), "stairs up are sketched")
	plan.deposit(HouseSketch.STONE, 400)
	plan.deposit(HouseSketch.TIMBER, 400)
	plan.order()
	for i in 300:
		if not sketcher.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(2)
	var flights: Array[Node] = sketcher._solid.get_children().filter(func(n): return n is Node3D and not (n is MeshInstance3D) and n.get_child_count() > 0 and n.get_child(0) is MeshInstance3D and n.has_meta("ymin"))
	check(flights.size() == 2, "both stairs are a flight of steps (%d)" % flights.size())
	for flight: Node3D in flights:
		check(flight.get_child_count() >= 2 * 9, "a flight has nine steps or more, each a block and a tread (%d)" % flight.get_child_count())
		var mat: StandardMaterial3D = (flight.get_child(1) as MeshInstance3D).material_override
		check(mat.albedo_texture == WoodStairs.texture(), "the treads are the town houses' stair boards")
	check(sketcher._solid.get_children().filter(func(n): return n is MeshInstance3D and (n.material_override as StandardMaterial3D) != null \
			and (n.material_override as StandardMaterial3D).albedo_color == HouseSketcher.PLANK_COLOR).is_empty(), "no plain plank ramp is drawn any more")
	# The hero still walks a smooth ramp: halfway down the stairs is halfway down.
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var half := plan.node_world(2, 1) + Vector3(0, 0, HouseSketch.CELL * 0.5)
	var q := PhysicsRayQueryParameters3D.create(half + Vector3(0, 5, 0), half + Vector3(0, -10, 0))
	await _wait(2)
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and absf(hit.position.y - half.y + HouseSketch.DEPTH * 0.5) < 0.2, "the ramp still runs halfway down at the stairs' middle (%s)" % str(hit.get("position", "-")))
	# Up from the cellar floor, over the stairs and onto the floor at their top.
	var hero: Player = game.player
	for e in game.level.enemies:
		if is_instance_valid(e):
			e.queue_free()
	hero.godmode = true
	hero.controllable = true
	hero.global_position = plan.cell_world(3, 1) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	hero.reset_physics_interpolation()
	await _wait(20)
	var landing := plan.cell_world(0, 1)
	Input.action_press("ui_left")
	for i in 600:
		await process_frame
		if hero.global_position.x < landing.x:
			break
	Input.action_release("ui_left")
	check(hero.global_position.x < landing.x and absf(hero.global_position.y - landing.y - HouseSketch.FLOOR_RISE) < 0.1,
			"the hero walks up the cellar stairs onto the ground floor's floor (at %s, the floor's middle at %s)" % [hero.global_position, landing])
	var down := plan.node_world(2, 1) + Vector3(0, 0, HouseSketch.CELL * 0.5)
	var up := plan.node_world(3, 4) + Vector3(0, 0, HouseSketch.CELL * 0.5)
	game.player.global_position = plan.node_world(1, 6) + Vector3(-6, 0, 6)
	await _shot("stairs_down", down + Vector3(-1.5, 3.2, 5.0), down + Vector3(0.6, -1.6, 0))
	await _shot("stairs_down_top", down + Vector3(-3.5, 3.6, 0.6), down + Vector3(1.0, -1.8, 0))
	await _shot("stairs_up", up + Vector3(-2.5, 2.6, 6.0), up + Vector3(0.4, 1.4, 0))
	await _shot("stairs_up_side", up + Vector3(0.3, 2.0, 7.0), up + Vector3(0.3, 1.5, 0))
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house stairs shots" if failures == 0 else "FAILED: %d" % failures)
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
