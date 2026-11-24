extends SceneTree
## Headless test: down in a house cellar the surface hides and the cellar sits in earth
## (see CellarView); climbing out brings the surface back.
## Run with: godot --headless --fixed-fps 60 -s tests/cellar_view.gd
## With SHOTS=<folder> and a display it also saves pictures (the surface left showing
## for comparison, then the earth round the cellar).

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


func _shown(nodes: Array) -> int:
	var n := 0
	for node in nodes:
		if is_instance_valid(node) and node.is_visible_in_tree():
			n += 1
	return n


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Cellar view test"
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
	plan.deposit("steinblock", 400)
	plan.deposit("bauholz", 200)
	plan.sketch_dig(plan.cells_between(Vector2i(3, 2), Vector2i(7, 7)))
	plan.sketch_stairs(1, 3, "e")
	plan.ordered = true
	for i in 200:
		sketcher.work_once()
	await _wait(5)
	var view: CellarView = sketcher.cellar_view
	check(not view.holes.is_empty(), "the cellar view knows the dug cells")
	# Up on the ground: the surface shows, no earth.
	var surface: Array = []
	for child in game.level.get_children():
		if child is Node3D and child != sketcher and child != game.house_furnisher and child.visible:
			surface.append(child)
	var people: Array = game.level.get_children().filter(func(n): return n is Villager or n is Animal or n is FarmAnimal)
	var pit_middle := plan.cell_world(5, 5)
	game.player.global_position = plan.node_world(0, 0) + Vector3(-3, 0, -3)
	await _wait(5)
	check(not view.active, "on the ground the surface shows")
	if shots != "":
		view.process_mode = Node.PROCESS_MODE_DISABLED
		game.player.global_position = pit_middle + Vector3(0, -HouseSketch.DEPTH + 0.05, 0)
		game._snap_camera()
		await _shot("cellar_before")
		view.process_mode = Node.PROCESS_MODE_INHERIT
	# Down in the cellar.
	game.player.global_position = pit_middle + Vector3(0, -HouseSketch.DEPTH + 0.05, 0)
	game._snap_camera()
	await _wait(20)
	check(view.active, "down in the cellar the view is on")
	check(view.pit.size() >= 30, "the whole cellar is the pit (%d cells)" % view.pit.size())
	# What stands in the cellar's own opening (a word floating over it) may show.
	surface = surface.filter(func(n): return not CellarView.in_cells(view.pit, n.global_position))
	check(_shown(surface) == 0, "nothing of the surface shows (%d of %d)" % [_shown(surface), surface.size()])
	# In autumn the fallen leaves on the ground and the falling ones stay out of sight down here.
	game.level.surface_life.set_autumn(true)
	game.level.surface_life.visible = true
	await _wait(25)
	check(not game.level.surface_life.is_visible_in_tree(), "the ground litter stays hidden from the cellar")
	check(not game._leaves.visible, "the falling leaves stay out of the cellar")
	check(_shown(people) == 0, "no villager or animal up on the ground shows")
	var earth := view.get_node_or_null("CellarEarth")
	check(earth != null and earth.is_visible_in_tree(), "earth lies round the cellar")
	check(earth != null and earth.get_child_count() > 20, "stones and roots lie in the earth")
	check(earth != null and SnowCover.bare(earth), "no snow settles on the earth round the cellar")
	check(game._under_roof(), "no weather falls into the cellar")
	# The earth is open over every dug cell and closed elsewhere.
	if earth != null:
		var faces: PackedVector3Array = (earth.get_child(0) as MeshInstance3D).mesh.get_faces()
		var over_pit := 0
		for i in range(0, faces.size(), 3):
			var c := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			for r: Rect2 in view.pit:
				if r.grow(-0.05).has_point(Vector2(c.x, c.z)):
					over_pit += 1
		check(over_pit == 0, "the earth leaves the cellar open (%d faces over it)" % over_pit)
		# Behind the walls it reaches down below where a wall under a cellar ceiling stops, so
		# no sky shows through between the two (it showed as a white line along the rim).
		var deepest := 0.0
		for f in faces:
			deepest = minf(deepest, f.y)
		check(deepest <= -HouseSketcher.CEILING_GAP - 0.1, "the earth reaches down behind the walls (%.2f m)" % deepest)
	# The pet comes down too and shows.
	if game.pet != null and is_instance_valid(game.pet):
		game.pet.global_position = pit_middle + Vector3(1, -HouseSketch.DEPTH + 0.05, 0)
		await _wait(20)
		check(game.pet.is_visible_in_tree(), "a pet down in the cellar shows")
	if shots != "":
		await _shot("cellar_after")
		game.zoom_by(10.0)
		await _wait(60)
		await _shot("cellar_after_close")
		game.zoom_by(-10.0)
		game.player.global_position = plan.cell_world(3, 6) + Vector3(0, -HouseSketch.DEPTH + 0.05, 0)
		game._snap_camera()
		await _wait(60)
		await _shot("cellar_after_corner")
	# Things come and go up on the surface while the hero is down there (an effect spent, a
	# footprint gone): the view forgets what was freed, and climbing out never hangs. (Its books
	# once held the freed nodes themselves, and walking them on the way out went round for ever.)
	var spot := plan.node_world(0, 0) + Vector3(-6, 0, -6)
	for round in 40:
		var made := []
		for i in 150:
			var thing := MeshInstance3D.new()
			game.level.add_child(thing)
			thing.global_position = spot + Vector3(i % 10, 0, i / 10)
			made.append(thing)
		view._hide_surface()
		for i in range(0, made.size(), 2):
			made[i].free()
	view._hide_surface()
	var freed := 0
	for id in view._hidden:
		if not id is int or instance_from_id(id) == null:
			freed += 1
	check(freed == 0, "the view keeps nothing that was freed (%d)" % freed)
	for thing in game.level.get_children():
		if thing is MeshInstance3D and thing.mesh == null:
			thing.queue_free()
	await _wait(2)
	# Back up on the ground everything shows again.
	var left_at := Time.get_ticks_msec()
	game.player.global_position = plan.node_world(0, 0) + Vector3(-3, 0, -3)
	game._snap_camera()
	await _wait(20)
	check(not view.active, "out of the cellar the view is off")
	check(Time.get_ticks_msec() - left_at < 10000, "climbing out takes no time at all (%d ms)" % (Time.get_ticks_msec() - left_at))
	# (The pictures turn the clock to noon, and lamps and candles go out by themselves then.)
	if shots == "":
		check(_shown(surface) == surface.size(), "the surface shows again (%d of %d)" % [_shown(surface), surface.size()])
	check(view.get_node_or_null("CellarEarth") == null, "the earth is gone")
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: cellar view" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The game's own camera, as the player sees it.
func _shot(name: String) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.level.set_hour(12.0)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
