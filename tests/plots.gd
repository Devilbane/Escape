extends SceneTree
## Building plots (see Plots): the rules, the fee, the deed book and the clerk on the map.

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## A free 3 x 3 plot on the map that touches none of `avoid` (or an empty rect).
func _free_after(level: Outdoor, near: Rect2i, avoid: Array) -> Rect2i:
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if r.position.distance_to(near.position) < 6.0:
				continue
			if avoid.any(func(a): return a.grow(1).intersects(r)):
				continue
			if Plots.problem(level, r) == "":
				return r
	return Rect2i()


## A 2 x 2 stretch of scree.
func _scree(level: Outdoor) -> Rect2i:
	for y in range(level.height - 2):
		for x in range(level.grid[y].length() - 2):
			var r := Rect2i(x, y, 2, 2)
			if Plots.problem(level, r, Plots.MINING) == "":
				return r
	return Rect2i()


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
	# More than one plot: each is numbered within its area.
	var second := _free_after(level, found, [found])
	check(second.size != Vector2i.ZERO, "the map has room for a second plot")
	check(Plots.register(level, "Tester", second) == "", "a hero may own a second plot")
	check(Plots.plot_of("Tester") == found, "the house stays on the first plot")
	check(Plots.plots_of("Tester").size() == 2, "both deeds are the hero's")
	check(Plots.homes().filter(func(d): return d.owner == "Tester").size() == 1, "only the first plot carries a house")
	var deeds := Plots.plots_of("Tester")
	check(deeds[0].n == 1 and deeds[0].kind == Plots.LAND, "the first plot of its area is number 1")
	if deeds[0].area == deeds[1].area:
		check(deeds[1].n == 2, "a further plot in the same area gets the next number")
	else:
		check(deeds[1].n == 1, "the first plot of another area is number 1 there")
	check(Plots.area_of(level, found).begins_with("land:") and Plots.area_of(level, found).length() > 5, "an area is named by a point of the compass")
	check(Plots.area_of(level, Rect2i(Vector2i(int(level.village_centre().x) + 12, int(level.village_centre().y)), Vector2i(2, 2))) == "land:e", "east of the village is the east")
	check(Plots.area_of(level, Rect2i(Vector2i(int(level.village_centre().x), int(level.village_centre().y) - 12), Vector2i(2, 2))) == "land:n", "north of the village is the north")
	var other := _free_after(level, found, [found, second])
	check(other.size != Vector2i.ZERO and Plots.register(level, "Other", other) == "", "another hero may own a plot too")
	check(Plots.plots_of("Tester").size() == 2, "a plot of another hero is not mine")
	Plots.release("Other")
	# Mining plots lie on scree, not on grass.
	check(Plots.problem(level, found, Plots.MINING) == "ground", "a meadow is no mining ground")
	var scree := _scree(level)
	check(scree.size != Vector2i.ZERO, "the map has scree for a mining plot")
	if scree.size != Vector2i.ZERO:
		check(Plots.problem(level, scree) == "ground", "scree is no building land")
		check(Plots.register(level, "Tester", scree, Plots.MINING) == "", "a mining plot can be registered")
		check(Plots.plot_of("Tester") == found, "a mining plot is no house plot")
		check(Plots.plots_of("Tester").size() == 3, "the mining plot is a deed of the hero")
		check(Plots.homes().filter(func(d): return d.owner == "Tester").size() == 1, "a mining plot carries no house")
	# The Crown grants only so many.
	while not Plots.at_limit("Tester"):
		var extra := _free_after(level, found, Plots.all().map(func(d): return d.rect))
		if extra.size == Vector2i.ZERO or Plots.register(level, "Tester", extra) != "":
			break
	check(Plots.at_limit("Tester"), "a hero can own up to the limit")
	check(Plots.register(level, "Tester", Rect2i(found.position + Vector2i(40, 0), Vector2i(3, 3))) == "have", "no more than the limit")
	Plots.reload()
	check(Plots.plot_of("Tester") == found, "the deed survives a reload")
	check(Plots.plots_of("Tester")[1].n >= 1, "the numbers survive a reload")
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
