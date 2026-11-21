extends SceneTree
## The apple tree of the garden (see AppleTree): Ilse sells a seedling, it is planted only in the
## garden on the day it goes down, it grows through seedling, sapling, young and full-grown tree
## by the seasons since then, keeps its age when moved and in the books, blossoms in spring, bears
## apples in summer and autumn that the hero picks into the bag once a season, and is bare in winter.

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
	HouseSketch.reload()
	HouseFurniture.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_run()
	print("PASS: apple tree" if failures == 0 else "FAILED: apple tree (%d)" % failures)
	quit(1 if failures > 0 else 0)
	return true


## The first season day of the year in `season`.
func _first(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d
	return -1


## How many of a part (see AppleTree.build: "apples", "leaves" (clumps), "single_leaves", "blossom", "limbs") the tree of
## `piece` has on `day`.
func _parts(piece: Dictionary, day: int, part: String) -> int:
	var model := Node3D.new()
	AppleTree.build(model, piece, day)
	var n: int = model.get_meta(part, 0)
	model.free()
	return n


func _tree(furniture: HouseFurniture) -> Dictionary:
	for p in furniture.placed:
		if p.kind == AppleTree.KIND:
			return p
	return {}


func _run() -> void:
	var season := AppleTree.season_days()
	var spring := _first(Weather.SPRING)
	var summer := _first(Weather.SUMMER)
	var autumn := _first(Weather.AUTUMN)
	var winter := _first(Weather.WINTER)
	check(spring >= 0 and summer >= 0 and autumn >= 0 and winter >= 0, "the year has four seasons")
	# Growth by the seasons since planting.
	var year := Weather.YEAR_DAYS
	var young := {"planted": summer - year}
	var old := {"planted": summer - 2 * year}
	check(AppleTree.stage({"planted": summer}, summer) == AppleTree.SEEDLING, "a new tree is a seedling")
	check(AppleTree.stage({"planted": summer - season}, summer) == AppleTree.SAPLING, "after a season it is a sapling")
	check(AppleTree.stage({"planted": summer - year + 1}, summer) == AppleTree.SAPLING, "all its first year a sapling")
	check(AppleTree.stage(young, summer) == AppleTree.YOUNG, "in its second year a young tree")
	check(AppleTree.stage(old, summer) == AppleTree.MATURE, "from its third year full-grown")
	check(AppleTree.stage({"planted": summer + 5}, summer) == AppleTree.SEEDLING, "a date ahead never makes it older or breaks it")
	# Apples: summer and autumn, on a tree old enough, once a season.
	check(AppleTree.apples({"planted": summer - season}, summer) == 0, "a sapling bears no apples")
	check(AppleTree.apples(young, summer) == AppleTree.APPLES[AppleTree.YOUNG] and AppleTree.APPLES[AppleTree.YOUNG] > 0, "a young tree bears a few apples")
	check(AppleTree.apples(old, summer) > AppleTree.apples(young, summer), "a full-grown tree bears more")
	check(AppleTree.apples(old, autumn) > 0, "apples hang in autumn too")
	check(AppleTree.apples(old, spring + 2 * year) == 0 and AppleTree.apples(old, winter) == 0, "no apples in spring or winter")
	var picked := {"planted": old.planted, "picked": AppleTree.season_index(summer)}
	check(AppleTree.apples(picked, summer) == 0, "a picked tree is bare for the season")
	check(AppleTree.apples(picked, autumn) > 0, "it bears again in autumn")
	check(AppleTree.days_to_fruit({"planted": summer}, summer) == 4 * season, "a seedling says when it first bears")
	# Its looks: blossom in spring, apples on the model, bare in winter.
	check(_parts(old, spring + 2 * year, "blossom") > 0, "a grown tree blossoms in spring")
	check(_parts({"planted": spring}, spring, "blossom") == 0, "a seedling does not blossom")
	check(_parts(old, summer, "apples") == AppleTree.apples(old, summer) * AppleTree.HANGING, "the apples hang on the model, more than a picking brings in")
	check(_parts(old, winter, "leaves") == 0 and _parts(old, summer, "leaves") > 0, "leaves in summer, bare in winter")
	check(_parts(old, winter, "limbs") > _parts({"planted": winter}, winter, "limbs"), "a grown tree has branches")
	check(_parts(old, summer, "limbs") >= 60 and _parts(old, summer, "leaves") >= 40, "a full-grown tree has plenty of branches, all in leaf (%d limbs, %d clumps)" % [_parts(old, summer, "limbs"), _parts(old, summer, "leaves")])
	check(_parts(old, summer, "single_leaves") >= 30 * _parts(old, summer, "leaves"), "the clumps are made of single leaves, not balls (%d leaves)" % _parts(old, summer, "single_leaves"))
	for when in [summer, autumn]:
		var crown := Node3D.new()
		AppleTree.build(crown, old, when)
		var leaves := crown.get_node("Leaves") as MeshInstance3D
		var tris := (leaves.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		check(tris == 2 * int(crown.get_meta("single_leaves")), "the crown is leaves only, no ball inside a clump (%d triangles for %d leaves)" % [tris, crown.get_meta("single_leaves")])
		crown.free()
	var model := Node3D.new()
	AppleTree.build(model, old, summer)
	check(model.has_node("Ground") and not model.has_node("Soil"), "the tree stands in a patch of grass ringed with stones, not on a disc of earth")
	check(model.get_child_count() <= 5, "a tree is a handful of meshes (%d)" % model.get_child_count())
	model.free()
	# In autumn a share of the leaves is still green among the turned ones.
	var fall := Node3D.new()
	AppleTree.build(fall, old, autumn)
	var colours: PackedColorArray = (fall.get_node("Leaves") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var green := 0
	for i in range(0, colours.size(), 6):
		if colours[i].g > colours[i].r:
			green += 1
	var share := float(green) / float(colours.size() / 6)
	check(share > 0.2 and share < 0.45, "some leaves stay green in autumn (%d%%)" % roundi(share * 100))
	fall.free()

	# In the game: a plot, a seedling bought from Ilse and planted in the garden.
	game.hero_name = "Apple test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var level: Outdoor = game.level
	# The village's apple trees: round the fountain and more in the gardens, none in a doorway or
	# beside a path.
	var gardens := level.square_trees.filter(func(t): return t.get("garden", false))
	check(gardens.size() >= 6, "apple trees grow in the village's gardens (%d)" % gardens.size())
	for t in gardens:
		var c: Vector2i = t.cell
		check(level.near_village(c) and level.cell_char(c) == ".", "a garden tree stands on the village's grass (%s)" % c)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				check(".#_§".contains(level.cell_char(c + Vector2i(dx, dy))), "nothing but grass round a garden tree (%s)" % c)
		var at: Vector3 = (t.node as Node3D).position
		check(not level._entrances.any(func(e): return Vector2((e.door as Vector3).x - at.x, (e.door as Vector3).z - at.z).length() < AppleTree.DOOR_CLEAR), "no garden tree in front of a door (%s)" % c)
	# One in the grass pocket west of the square, framed by paths: at the corner its four tiles share.
	var pockets := level.square_trees.filter(func(t): return t.get("pocket", false))
	check(pockets.size() >= 1, "an apple tree stands in the grass pocket by the square (%d)" % pockets.size())
	for t in pockets:
		var c: Vector2i = t.cell
		for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]:
			check(level.cell_char(c + d) in [".", "l"], "a pocket tree stands on grass (%s)" % (c + d))
		var mid: Vector3 = (level.cell_to_world(c) + level.cell_to_world(c + Vector2i.ONE)) * 0.5
		check((t.node as Node3D).position.distance_to(mid) < AppleTree.POCKET_LAMP_STEP * 1.5, "the pocket tree stands at the pocket's middle (%s)" % c)
	var found := Rect2i()
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var plan: HouseSketch = game.house_sketcher.plan
	var garden: Array = HouseFurniture.SECTIONS.filter(func(s): return s[0] == "garten")
	check(AppleTree.KIND in garden[0][3] and HouseFurniture.in_garden(AppleTree.KIND), "Ilse sells the apple tree in the garden")
	game.coins = 2000
	game.trader_role = "µ"
	game.menus.open("raumausstatter")
	game.menus._buy_furniture(AppleTree.KIND)
	game.menus.close()
	check(HouseFurniture.of(game.hero_name).count(AppleTree.KIND) == 1, "the seedling waits in the store")
	level.set_season(summer + 3 * year)
	var furnisher: HouseFurnisher = game.house_furnisher
	furnisher.enter()
	furnisher.select(AppleTree.KIND)
	furnisher.click(HouseFurniture.centre(plan, AppleTree.KIND, 0, 1, 1, 0))
	var tree := _tree(HouseFurniture.of(game.hero_name))
	check(not tree.is_empty() and int(tree.get("planted", -1)) == level.season_day, "the tree is planted today (%s)" % tree)
	# Moving it keeps its age.
	furnisher.turn_placed(furnisher.furniture.placed.find(_tree(furnisher.furniture)))
	check(int(_tree(HouseFurniture.of(game.hero_name)).get("planted", -1)) == level.season_day, "a turned tree keeps its age")
	furnisher.leave()
	# Two years on, in the books: it bears.
	var books := HouseFurniture.of(game.hero_name)
	_tree(books).planted = level.season_day - 2 * year
	books.save(game.hero_name)
	HouseFurniture.reload()
	check(int(_tree(HouseFurniture.of(game.hero_name)).planted) == level.season_day - 2 * year, "the tree's age is kept in the books")
	furnisher.refresh()
	var stations := level.stations.filter(func(s): return s.kind == AppleTree.STATION)
	check(stations.size() == 1, "the tree is a station")
	if stations.is_empty():
		return
	check(AppleTree.station_prompt(game, stations[0]).contains(str(AppleTree.APPLES[AppleTree.MATURE])), "its prompt offers the apples: %s" % AppleTree.station_prompt(game, stations[0]))
	var before: int = game.player.bag.count(AppleTree.APPLE)
	game._use_station(stations[0])
	check(game.player.bag.count(AppleTree.APPLE) == before + AppleTree.APPLES[AppleTree.MATURE], "the apples go into the bag")
	var after := _tree(HouseFurniture.of(game.hero_name))
	check(int(after.get("picked", -1)) == AppleTree.season_index(level.season_day), "the harvest is kept in the books")
	check(AppleTree.apples(after, level.season_day) == 0, "a picked tree is bare until the next season")
	check(furnisher._has_trees, "the furnisher knows a tree grows")
	# Picked up into the store it is a seedling again.
	var store := HouseFurniture.of(game.hero_name)
	store.pick_up(store.placed.find(_tree(store)))
	check(store.count(AppleTree.KIND) == 1 and _tree(store).is_empty(), "a tree picked up waits as a seedling")
