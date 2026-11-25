extends SceneTree
## Headless test: the trunks to chop for timber (see WoodLogs). The woodcutter's
## yard has its trunks, windfalls lie spread over the woods, a hero who runs into
## a trunk gets timber in the bag, only a stump is left until the next morning, a
## full bag leaves it whole, a windfall gives more timber than a yard trunk, no plot may be marked over a trunk, and timber
## stacks 5 and stone blocks 3 to a bag slot.
## Run with: godot --headless --fixed-fps 60 -s tests/wood_logs.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _timber() -> int:
	return (game.player.bag as Array).count(WoodLogs.TIMBER)


func _run() -> void:
	# Stacking: 5 timber or 3 stone blocks share one slot.
	check(Items.stack_size("bauholz") == 5, "timber stacks 5 to a slot")
	check(Items.stack_size("steinblock") == 3, "stone blocks stack 3 to a slot")
	check(Items.slots_used(["bauholz", "bauholz", "bauholz", "bauholz", "bauholz", "bauholz"]) == 2, "6 timber take 2 slots")
	check(Items.slots_used(["steinblock", "steinblock", "steinblock"]) == 1, "3 stone blocks take 1 slot")
	check(Items.room_for(["bauholz", "bauholz"], 2, "bauholz") == 8, "room for 8 more timber in 2 slots holding 2")
	check(Items.room_for(["kiste", "kiste"], 2, "steinblock") == 0, "no room in a full bag")
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level
	var logs: Array = lvl.stations.filter(func(s): return s.kind == WoodLogs.KIND)
	var cutter: Array = lvl.stations.filter(func(s): return s.kind == "holzfaeller")
	var home: Vector2i = cutter[0].cell if not cutter.is_empty() else Vector2i(-99, -99)
	var yard: Array = logs.filter(func(s): return (s.cell - home).length() < 3.0)
	check(yard.size() == WoodLogs.CELLS.size(), "the woodcutter's yard has its trunks (%d)" % yard.size())
	var windfalls: Array = logs.filter(func(s): return not yard.has(s))
	check(windfalls.size() >= 10, "windfalls lie spread over the woods (%d)" % windfalls.size())
	print("windfalls at ", windfalls.map(func(s): return s.cell))
	for w in windfalls:
		check(yard.is_empty() or lvl.astar.get_id_path(yard[0].cell, w.cell).size() > 0, "the windfall at %s can be walked to" % w.cell)
	# Windfalls keep out of open grass, so building land stays free: there is
	# still a 4 x 4 plot to be had.
	var free_plot := false
	for y in range(lvl.height - 5):
		for x in range(lvl.grid[y].length() - 5):
			if Plots.problem(lvl, Rect2i(x, y, 4, 4)) == "":
				free_plot = true
	check(free_plot, "a free 4x4 plot of grass is still to be had")
	if logs.is_empty():
		_end()
		return
	check(Plots.problem(lvl, Rect2i(windfalls[0].cell, Vector2i(2, 2))) != "" if not windfalls.is_empty() else true, "no plot over a windfall")
	var trunk: Dictionary = logs[0]
	game.player.bag.clear()
	game._chop_wood(trunk)
	await create_timer(1.5).timeout
	check(_timber() == WoodLogs.TIMBER_YIELD, "chopping a trunk gives its timber (%d)" % _timber())
	check(trunk.spent, "only the stump is left")
	game._chop_wood(trunk)
	await create_timer(0.2).timeout
	check(_timber() == WoodLogs.TIMBER_YIELD, "a chopped trunk gives nothing more")
	WoodLogs.refresh(lvl, game.day + 1)
	check(not trunk.spent, "a new trunk lies there by the next day")
	# A full bag leaves the trunk whole; a bag whose timber bundle has room does not.
	game.player.bag.clear()
	while game.player.bag_used() < game.player.bag_size():
		game.player.bag.append("kiste")
	game._chop_wood(trunk)
	await create_timer(0.2).timeout
	check(not trunk.spent and _timber() == 0, "with a full bag the trunk stays whole")
	game.player.bag.clear()
	while game.player.bag_used() < game.player.bag_size() - 1:
		game.player.bag.append("kiste")
	game.player.bag.append(WoodLogs.TIMBER)
	game._chop_wood(trunk)
	await create_timer(1.5).timeout
	check(trunk.spent and _timber() == 1 + WoodLogs.TIMBER_YIELD, "timber goes onto the bundle in a full bag (%d)" % _timber())
	# The bark must face outwards (Godot draws clockwise faces), or the trunk is see-through.
	var mesh := WoodLogs.trunk_mesh(2.6, 0.3, RandomNumberGenerator.new())
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var centre := mesh.get_aabb().get_center()
	var outward := 0
	for i in range(0, verts.size(), 3):
		var at := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0 - centre
		at.x = 0.0
		if (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i]).dot(at) > 0.0:
			outward += 1
	check(outward == verts.size() / 3, "every bark face looks outwards (%d of %d)" % [outward, verts.size() / 3])
	# A windfall is a whole tree: more swings, more timber.
	if not windfalls.is_empty():
		var tree: Dictionary = windfalls[0]
		game.player.bag.clear()
		game._chop_wood(tree)
		await create_timer(3.0).timeout
		check(_timber() == WoodLogs.WINDFALL_YIELD, "a windfall gives %d timber (%d)" % [WoodLogs.WINDFALL_YIELD, _timber()])
		check(tree.spent, "the windfall is chopped up")
	_end()


func _end() -> void:
	print("PASS: wood logs" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
