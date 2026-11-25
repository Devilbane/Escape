extends SceneTree
## Ferns and needle trees (see Fern): a fern is a low rosette, the spruce a slim cone about three times
## as tall as it is wide in several sizes, besides a few pines with open crowns, both light enough to draw by the hundred, with a far model
## of the same outline that is much lighter still. In Apfeltal the forest is spruces, no pine is left, the
## stand west of the road is all spruces, and ferns grow in the shade along the forest's edge, on
## forest tiles only and never on a building plot.

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_run()
	print("PASS: fern" if failures == 0 else "FAILED: fern (%d)" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _triangles(mesh: ArrayMesh) -> int:
	return Fern.triangles(mesh)


func _run() -> void:
	# The models.
	var fern := Fern.fern_mesh(0)
	var box := fern.get_aabb()
	check(box.size.y < box.size.x * 0.6 and box.size.x > 1.5, "a fern is a low, wide rosette (%s)" % box)
	check(_triangles(fern) <= 300, "a fern is light (%d triangles)" % _triangles(fern))
	check(Fern.fern_mesh(0) == fern, "a fern's mesh is built once and shared")
	var heights := []
	for v in Fern.NEEDLE_LOOKS.size():
		var tree := Fern.needle_tree_mesh(v)
		var b := tree.get_aabb()
		var ratio := b.size.y / maxf(b.size.x, b.size.z)
		var kind := int(Fern.NEEDLE_LOOKS[v].z)
		if kind == Fern.SPRUCE:
			check(ratio > 1.3 and ratio < 3.6, "spruce %d is a slim cone (%.2f times as tall as wide)" % [v, ratio])
		elif kind == Fern.PINE:
			check(ratio > 1.0 and ratio < 3.0, "pine %d is taller than wide (%.2f times as tall as wide)" % [v, ratio])
		else:
			check(ratio > 0.6 and ratio < 1.5, "the broad pine %d is about as wide as tall (%.2f)" % [v, ratio])
		check(b.position.y > -0.01, "spruce %d stays above the ground (%.2f)" % [v, b.position.y])
		check(_triangles(tree) <= 4500, "spruce %d is light to draw (%d triangles)" % [v, _triangles(tree)])
		heights.append(Fern.needle_height(v))
		var far := Fern.needle_tree_mesh(v, true)
		var fb := far.get_aabb()
		check(absf(fb.size.y - b.size.y) < 0.4 and absf(fb.size.x - b.size.x) < 0.6, "far spruce %d has the same outline (%s, %s)" % [v, fb.size, b.size])
		check(_triangles(far) * 4 <= _triangles(tree), "far spruce %d is much lighter (%d triangles)" % [v, _triangles(far)])
	check(heights.max() - heights.min() > 1.5, "the spruces differ in height (%s)" % [heights])

	# In Apfeltal.
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	check(level.level_name == Outdoor.SPRUCE_MAP, "the open-air map is Apfeltal")
	var spruces := 0
	var others := 0
	var pines := 0
	var ferns := 0
	for key in level._plants:
		var name: String = key[0]
		for xf: Transform3D in level._plants[key]:
			var at := xf.origin
			if name.begins_with("fern:"):
				ferns += 1
				check(level.cell_char(level.world_to_cell(at)) == "#", "a fern grows on the forest floor (%s)" % at)
			elif name.begins_with("spruce:"):
				spruces += 1
			elif name.begins_with("tree_pine") or name.begins_with("tree_single") or name.begins_with("trees_"):
				pines += 1
			elif level.in_spruce_patch(at) and name.begins_with("tree"):
				others += 1
	check(spruces >= 2500, "the forests are full of spruces (%d)" % spruces)
	check(pines == 0, "no pine or kit leaf tree is left, only spruces (%d)" % pines)
	check(others == 0, "every tree of the stand is a spruce (%d others)" % others)
	check(ferns >= 60 and ferns == level.fern_count, "ferns grow along the forest's edge (%d)" % ferns)
	check(level.edge_fillers >= 50, "spruces close the gaps along the forest's edge (%d)" % level.edge_fillers)
	print("ferns: %d, spruces: %d, closing edge gaps: %d" % [ferns, spruces, level.edge_fillers])
	# A plot clears them.
	var found := Rect2i()
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	if found.size != Vector2i.ZERO:
		level.clear_plot(found)
		for key in level._plants:
			if (key[0] as String).begins_with("fern:"):
				for xf: Transform3D in level._plants[key]:
					check(not level.on_plot(xf.origin, 0.0), "no fern on a building plot")
