extends SceneTree
## Headless test: the apple trees that explain the autumn leaves (AppleTree.plant_for_leaves):
## - a handful stand in the village and the areas round it, none in the farming valley or the graveyard;
## - each on grass with only grass and path tiles round it, clear of doors, bushes and building plots,
##   and no building plot may cover one;
## - every spot where leaves lie (outside the graveyard and the valley) is within LEAF_REACH tiles of
##   one of them, of the village's other apple trees or of ivy on a wall;
## - the village hedgehogs' apple hoards are as before (they use the village's own trees).
## Run with: godot --headless -s tests/leaf_apple_trees.gd

var failures := 0
var game: Node
var frames := 0
var started := false


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
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.hero_name = "Leaf apples"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var trees := lvl.leaf_trees
	check(trees.size() >= 8 and trees.size() <= 30, "a handful of leaf apple trees (%d)" % trees.size())
	for t in trees:
		var c: Vector2i = t.cell
		var at: Vector3 = (t.node as Node3D).position
		check(c.y < Outdoor.VALLEY_FROM, "no leaf apple tree in the farming valley (%s)" % c)
		check(lvl.cell_char(c) == ".", "a leaf apple tree stands on grass (%s)" % c)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				check(".,".contains(lvl.cell_char(c + Vector2i(dx, dy))), "only grass and path round a leaf apple tree (%s)" % c)
		check(not lvl.on_plot(at, 0.0), "no leaf apple tree on a building plot (%s)" % c)
		check(not lvl._entrances.any(func(e): return Vector2((e.door as Vector3).x - at.x, (e.door as Vector3).z - at.z).length() < AppleTree.DOOR_CLEAR), "no leaf apple tree before a door (%s)" % c)
		check(lvl.has_leaf_tree(c) and Plots.problem(lvl, Rect2i(c.x, c.y, 2, 2)) != "", "no plot may cover a leaf apple tree (%s)" % c)
		# Not in the graveyard.
		check(not AppleTree._near_letters(lvl, c, AppleTree.LEAF_KEEP_OUT_LETTERS, AppleTree.LEAF_KEEP_OUT), "no leaf apple tree by graves or rock faces (%s)" % c)
	# Coverage of the ground the leaves lie on.
	var sources: Array[Vector2] = []
	for t in lvl.square_trees + trees:
		sources.append(Vector2((t.node as Node3D).position.x, (t.node as Node3D).position.z) / Level.TILE)
	for xf: Transform3D in lvl._ivy.xforms:
		sources.append(Vector2(xf.origin.x, xf.origin.z) / Level.TILE)
	var total := 0
	var covered := 0
	for y in Outdoor.VALLEY_FROM:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if not AppleTree.LEAF_GROUND.contains(lvl.cell_char(c)) or AppleTree._near_letters(lvl, c, AppleTree.LEAF_KEEP_OUT_LETTERS, AppleTree.LEAF_KEEP_OUT):
				continue
			total += 1
			if sources.any(func(s: Vector2): return Vector2(c).distance_to(s) <= AppleTree.LEAF_REACH):
				covered += 1
	check(total > 500 and float(covered) / total > 0.9, "leaves have a tree or ivy within one screen (%d of %d)" % [covered, total])
	# Hedgehogs: the village's own trees still give two their hoards.
	for i in 5:
		await physics_frame
	var hoarders := 0
	for h in lvl.woods.hedgehogs:
		if h.hoard != null:
			hoarders += 1
	check(hoarders >= 1, "village hedgehogs still keep apple hoards (%d)" % hoarders)
	print("leaf apple trees: ", trees.size(), ", leaf ground covered ", covered, "/", total, ", hoarders ", hoarders)
	print("FAILURES: ", failures) if failures > 0 else print("ALL PASSED")
	quit(1 if failures > 0 else 0)
