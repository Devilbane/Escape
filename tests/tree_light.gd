extends SceneTree
## Headless test: the trees outside are lit by the lanterns, fires and
## torches near them, like the rest of the scenery. The renderer lights each
## drawn batch with at most rendering/limits/opengl/max_lights_per_object
## lights, so the trees are batched per patch of the map (Outdoor._plant)
## and no batch may be touched by more lights than that.
## Run with: godot --headless --fixed-fps 60 -s tests/tree_light.gd
## With SHOTS=<folder> and a display it also saves a night screenshot there.

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
	seed(5)
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
	game.day_hour = 23.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(30)
	var lvl: Node = game.level
	var limit: int = ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object")
	var batches := []
	for mmi: MultiMeshInstance3D in lvl.find_children("*", "MultiMeshInstance3D", true, false):
		var mat := mmi.material_override as ShaderMaterial
		if mat and mat.shader == Outdoor.TREE_SHADER:
			batches.append(mmi)
	check(batches.size() > 10, "the trees come in many batches (%d)" % batches.size())
	var lights := []
	for l: OmniLight3D in game.find_children("*", "OmniLight3D", true, false):
		if l.is_visible_in_tree() and l.light_energy > 0.0:
			lights.append(l)
	check(lights.size() > limit, "there are more lights than one batch can take (%d)" % lights.size())
	var worst := 0
	var lit := 0
	var plants: Dictionary = lvl._plants
	for key in plants:
		var box := _bounds(lvl, key[0], plants[key])
		var touching := 0
		for l: OmniLight3D in lights:
			var p := l.global_position
			var nearest := p.clamp(box.position, box.end)
			if nearest.distance_to(p) < l.omni_range:
				touching += 1
		worst = maxi(worst, touching)
		if touching > 0:
			lit += 1
	print("tree batches %d, lights %d, most lights on one batch %d" % [batches.size(), lights.size(), worst])
	check(worst <= limit, "no tree batch is touched by more lights than it can be lit by (%d of %d)" % [worst, limit])
	check(lit > 0, "some trees stand in a lantern's light (%d batches)" % lit)
	if shots != "":
		await _shot(lvl, lights)
	game.delete_save(game.save_path())
	print("PASS: tree light" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Where one batch's trees stand (from the level's own list, as the
## headless renderer keeps no multimesh transforms).
func _bounds(lvl: Node, model: String, where: Array) -> AABB:
	var shape: AABB = lvl._aabb_of(model)
	var box := AABB()
	for i in where.size():
		var b: AABB = (where[i] as Transform3D) * shape
		box = b if i == 0 else box.merge(b)
	return box


## A look at the tree nearest to a lantern or fire, at night.
func _shot(lvl: Node, lights: Array) -> void:
	var best := INF
	var tree := Vector3.ZERO
	var lamp := Vector3.ZERO
	for key in lvl._plants:
		for t: Transform3D in lvl._plants[key]:
			for l: OmniLight3D in lights:
				var d := t.origin.distance_to(l.global_position)
				if d < best:
					best = d
					tree = t.origin
					lamp = l.global_position
	var at := (tree + Vector3(lamp.x, 0, lamp.z)) * 0.5
	if lvl.fog:
		lvl.fog.visible = false
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.player.global_position = Vector3(at.x, game.player.global_position.y, at.z) + Vector3(0, 0, 6)
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = at + Vector3(0, 12, 16)
	cam.look_at(at + Vector3(0, 2, 0))
	cam.make_current()
	await _wait(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join("tree_light.png"))
