extends SceneTree
## Building plots (see Plots): the rules, the fee, the deed book and the clerk on the map.

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	Homes.reload()
	var level := Outdoor.new()
	level.load_from_file("res://levels/11_die_freiheit.txt")
	# Find a free grass rectangle outside the village on the real map.
	var found := Rect2i()
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	check(found.size != Vector2i.ZERO, "the map has room for a 3 x 3 plot")
	check(Plots.problem(level, Rect2i(found.position, Vector2i(1, 3))) == "small", "a plot needs two tiles a side")
	check(Plots.problem(level, Rect2i(found.position, Vector2i(9, 3))) == "big", "a plot is at most eight tiles a side")
	check(Plots.problem(level, Rect2i(0, 0, 3, 3)) == "ground", "forest is no building land")
	check(Plots.fee(found) == 9 * Plots.FEE_PER_TILE, "the fee grows with the area")
	check(Plots.rect_between(Vector2i(5, 7), Vector2i(3, 9)) == Rect2i(3, 7, 3, 3), "the corners may come in any order")
	check(not Plots.has_plot("Tester"), "nobody owns a plot at first")
	check(Plots.register(level, "Tester", found) == "", "a free plot can be registered")
	check(Plots.plot_of("Tester") == found, "the deed is kept")
	check(Plots.owner_at(found.position) == "Tester", "the land has an owner")
	check(Plots.problem(level, found) == "taken", "a registered plot is taken")
	check(Plots.register(level, "Tester", Rect2i(found.position + Vector2i(40, 0), Vector2i(3, 3))) == "have", "one plot a hero")
	Plots.reload()
	check(Plots.plot_of("Tester") == found, "the deed survives a reload")
	Plots.release("Tester")
	check(not Plots.has_plot("Tester"), "a plot can be given back")
	# The clerk stands on the map.
	var clerks := 0
	for line in level.grid:
		clerks += line.count("¢")
	check(clerks == 1, "one land registry clerk on the map")
	check(Villager.ROLES.has("¢"), "the clerk has a role")
	level.free()
	if failures == 0:
		print("PASS: plots")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
