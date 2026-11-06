extends SceneTree
## Headless test for the glowing ember cracks ("~") of the ember tunnels
## below mine 3 (see EmberCracks): they are drawn as one rough, uneven shape
## over the whole floor, with no square tile showing, and cracks on
## neighbouring tiles run together into one crack. They stay solid.
## Run with: godot --headless --fixed-fps 60 -s tests/lava_cracks.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

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
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	game._title.visible = false
	game._fade.color.a = 0.0
	game._message.text = ""
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _calm() -> void:
	for e in game.level.enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED
			e.visible = false


func _enter(building: String) -> void:
	game.state = game.State.PLAYING
	game.go_inside(building)
	for i in 600:
		await process_frame
		if game.level.theme == "glut" and game.state == game.State.PLAYING and i > 10:
			break
	await _wait(10)
	_calm()


func _cracks() -> Array:
	var found := []
	for y in game.level.height:
		for x in game.level.grid[y].length():
			if game.level.cell_char(Vector2i(x, y)) == "~":
				found.append(Vector2i(x, y))
	return found


## Puts the hero on `cell` and the camera close, looking at the cracks.
func _look_from(cell: Vector2i, zoom: float) -> void:
	game.player.global_position = game.level.cell_to_world(cell)
	game.player.reset_physics_interpolation()
	game._zoom = zoom
	game._zoom_target = zoom


func _run() -> void:
	game.hero_name = "Lava test"
	game.escaped = true
	game.day = 3
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _enter("mine3b")
	check(game.level.theme == "glut", "the hero is in the ember tunnels")
	var cracks := _cracks()
	check(cracks.size() > 4, "the ember tunnels have cracks")

	var meshes: Array = game.level.get_tree().get_nodes_in_group(EmberCracks.GROUP)
	meshes = meshes.filter(func(n): return game.level.is_ancestor_of(n))
	check(meshes.size() == EmberCracks.LAYERS.size(), "the cracks of a floor are one mesh per layer, not a box per tile")
	# No square of the old kind is left on a crack tile.
	var boxes := 0
	for n in game.level.get_children():
		if n is MeshInstance3D and n.mesh is BoxMesh:
			var c: Vector2i = game.level.world_to_cell(n.position)
			if cracks.has(c) and (n.mesh as BoxMesh).size.x > Level.TILE * 0.7:
				boxes += 1
	check(boxes == 0, "no square slab frames a crack")

	# The glowing shape of a crack is uneven: its edge is not where a square
	# would be. And between two neighbouring cracks it glows all the way.
	var level: Level = game.level
	for c in cracks:
		check(EmberCracks.heat(level, level.cell_to_world(c)) > EmberCracks.GLOW, "the middle of crack %s glows" % c)
	var joined := 0
	var pairs := 0
	for c in cracks:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cracks.has(c + d):
				pairs += 1
				var ok := true
				for k in 9:
					var t := k / 8.0
					var p: Vector3 = level.cell_to_world(c).lerp(level.cell_to_world(c + d), t)
					if EmberCracks.heat(level, p) <= EmberCracks.GLOW:
						ok = false
				joined += 1 if ok else 0
	check(pairs > 0 and joined == pairs, "neighbouring cracks run together (%d of %d)" % [joined, pairs])
	# The edge of a lone crack's glow wanders: its reach differs by direction.
	var reaches := []
	var lone: Vector2i = cracks[0]
	for c in cracks:
		var alone := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				alone = alone and (Vector2i(dx, dy) == Vector2i.ZERO or not cracks.has(c + Vector2i(dx, dy)))
		if alone:
			lone = c
			break
	for a in 16:
		var dir := Vector3(cos(a * TAU / 16.0), 0, sin(a * TAU / 16.0))
		var r := 0.0
		while r < Level.TILE and EmberCracks.heat(level, level.cell_to_world(lone) + dir * r) > EmberCracks.GLOW:
			r += 0.05
		reaches.append(r)
	check(reaches.max() - reaches.min() > Level.TILE * 0.12, "the edge of a crack is rough, not round or square")
	check(reaches.max() < Level.TILE * 0.85, "a crack's glow stays near its tile")

	# Still too hot to cross.
	var solid := {}
	for shape in level._walls_body.get_children():
		if shape is CollisionShape3D and cracks.has(level.world_to_cell(shape.position)):
			solid[level.world_to_cell(shape.position)] = true
	check(solid.size() == cracks.size(), "every crack is still solid")

	if shots != "":
		_look_from(Vector2i(10, 6), 0.45)
		await _shot("lava_cracks_close")
		_look_from(Vector2i(14, 6), 0.0)
		await _shot("lava_cracks_wide")

	if failures == 0:
		print("lava cracks: all checks passed")
	quit(1 if failures > 0 else 0)
