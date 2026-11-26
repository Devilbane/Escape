extends SceneTree
## Headless test for the slime patches on the sewers' floors (see SewerSlime): they lie on the
## walkway and in the chambers, never in the hidden den, their outline is ragged (neither square nor
## round), a spot in one is slime underfoot (a squelch, a slightly slower pace) and a spot outside
## is plain stone.
## Run with: godot --headless --fixed-fps 60 -s tests/sewer_slime.gd
## With SHOTS=<folder> and a display it also saves pictures.

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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Slime test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var cells := Sewers.cells()
	var patches := SewerSlime.patches()
	check(patches.size() >= 20, "slime lies about the sewers (%d patches)" % patches.size())
	var chambers := 0
	for p: Dictionary in patches:
		var c := Sewers.cell_at(p.pos)
		check(cells.get(c, "") in ["w", "r"], "a patch lies on the walkway or in a chamber (%s)" % c)
		check(not Spooknortz.hides(c), "none in the hidden den (%s)" % c)
		if cells.get(c, "") == "r":
			chambers += 1
	check(chambers >= 5, "the chambers have their share (%d)" % chambers)
	# Foot on a patch: slime. Far above it, or in the open air: not.
	var wet := 0
	for p: Dictionary in patches:
		var pos: Vector3 = p.pos
		if SewerSlime.at(pos + Vector3(0, 0.1, 0)):
			wet += 1
	check(wet >= patches.size() - 2, "the middle of a patch is slime (%d of %d)" % [wet, patches.size()])
	check(not SewerSlime.at(Vector3(pos_x(patches), 3.0, pos_z(patches))), "no slime up on the street")
	# The outline is ragged: the share of a patch's square that is slime is far from a square's and a disc's.
	# Sizes: every class is there, patches stay in their class's range, and every class is drawn at
	# about the same pixels per metre, so a big puddle is as sharp as a small one.
	var per_class := [0, 0, 0]
	for p: Dictionary in patches:
		var cls: Dictionary = SewerSlime.CLASSES[p.kind]
		per_class[p.kind] += 1
		check(p.size >= cls.size.x and p.size <= cls.size.y, "a patch keeps to its size class (%.1f m)" % p.size)
		check(float(cls.tile) / p.size >= SewerSlime.PIXELS_PER_METRE_MIN, "a patch of %.1f m is drawn sharply (%d px)" % [p.size, cls.tile])
	check(per_class[0] > 0 and per_class[1] > 0 and per_class[2] >= Sewers.ROOMS.size(), "small, medium and large patches all lie about (%s)" % str(per_class))
	var p0: Dictionary = patches[0]
	var inside := 0
	var total := 0
	for ix in 40:
		for iz in 40:
			var d := Vector3((ix / 39.0 - 0.5) * p0.size, 0.0, (iz / 39.0 - 0.5) * p0.size)
			var turned := Vector2(d.x, d.z).rotated(float(p0.turn))
			total += 1
			if SewerSlime.at(p0.pos + Vector3(turned.x, 0.1, turned.y)):
				inside += 1
	var share := float(inside) / total
	check(share > 0.08 and share < 0.62, "a patch fills a ragged part of its square (%.2f)" % share)
	# Underfoot.
	var spot: Vector3 = patches[0].pos
	check(Surfaces.ground(level, spot + Vector3(0, 0.1, 0)) == Surfaces.SLIME, "the ground in a patch is slime")
	check(Surfaces.pace_at(level, spot + Vector3(0, 0.1, 0)) < 1.0 and Surfaces.pace_at(level, spot + Vector3(0, 0.1, 0)) > 0.7, "slime slows only a little")
	check(Surfaces.step_sound(Surfaces.SLIME).begins_with("slime_squelch_"), "a step in slime squelches")
	check(Surfaces.step_ground(level, spot + Vector3(0, 0.1, 0)) == Surfaces.SLIME, "no snow crunch over slime")
	for i in 4:
		check(ResourceLoader.exists("res://assets/sounds/slime_squelch_%d.wav" % i), "squelch %d exists" % i)
	# Drawn.
	game.player.global_position = Sewers.floor_at(Sewers.cell_at(patches[0].pos)) + Vector3(0, 0.1, 0)
	game._snap_camera()
	await _wait(20)
	var mesh: MeshInstance3D = level.find_child("SlimePatches", true, false)
	var verts := 0
	if mesh != null:
		for k in mesh.mesh.get_surface_count():
			verts += mesh.mesh.surface_get_array_len(k)
	check(mesh != null and verts == patches.size() * 6, "the patches are one mesh, a surface per size class (%d vertices)" % verts)
	check(game.player.speed > 0.0, "the hero is down there")
	if shots != "":
		var near := Sewers.cell_at(patches[0].pos)
		for spec: Array in [["slime_a", patches[0].pos], ["slime_b", patches[patches.size() / 2].pos], ["slime_c", patches[patches.size() - 1].pos]]:
			game.player.global_position = spec[1] + Vector3(0, 0.1, 0)
			game._snap_camera()
			await _wait(20)
			await _shot(spec[0])
		print("near ", near)
	print("FAIL count: ", failures) if failures else print("PASS")
	quit(1 if failures else 0)


func pos_x(patches: Array) -> float:
	return (patches[0].pos as Vector3).x


func pos_z(patches: Array) -> float:
	return (patches[0].pos as Vector3).z


func _shot(name: String) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.level.set_hour(12.0)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
