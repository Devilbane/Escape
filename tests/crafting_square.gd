extends SceneTree
## Headless test for the crafting square in the village: beside Gorm's forge
## on the market square stand a bench for every craft (fine metalwork, gem
## cutting, alchemy) and the hero's storage chest, all close together, each
## opens its window, and the hero's house is still reachable from the square.
## Run with: godot --headless --fixed-fps 60 -s tests/crafting_square.gd

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


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	var smith := {}
	var benches := {}
	var chests := []
	for s in lvl.stations:
		if s.kind == "schmied":
			smith = s
		elif s.kind == "werkbank":
			benches[s.craft] = s
		elif s.kind == "lager":
			chests.append(s)
	check(not smith.is_empty(), "Gorm stands at his forge")
	for craft in ["feinschmieden", "edelsteinschleifen", "alchemie"]:
		check(benches.has(craft), "a bench for %s stands on the square" % craft)
		if benches.has(craft):
			var b: Dictionary = benches[craft]
			check(lvl.astar.is_point_solid(b.cell), "the %s bench blocks its tile" % craft)
			check(b.cell.distance_to(smith.cell) <= 6.0, "the %s bench is close to Gorm's forge" % craft)
			check(lvl.station_at(b.pos) == b, "running into the %s bench finds it" % craft)
	# One chest in the house, one on the square.
	var square_chest := {}
	for s in chests:
		if lvl.cell_char(s.cell) == CraftingSquare.CHEST:
			square_chest = s
	check(chests.size() == 2 and not square_chest.is_empty(), "the hero's chest is on the square too")
	if not square_chest.is_empty():
		check(square_chest.cell.distance_to(smith.cell) <= 6.0, "the chest is close to the forge")
		# Every bench and the chest can be walked up to from the square.
		var fountain := Vector2i(-1, -1)
		for y in lvl.height:
			for x in lvl.width:
				if lvl.cell_char(Vector2i(x, y)) == "F":
					fountain = Vector2i(x, y) + Vector2i(0, 1)
		for s in benches.values() + [square_chest]:
			var stand: Vector2i = s.cell + Vector2i(1, 0)
			check(not lvl.astar.is_point_solid(stand) and lvl.astar.get_id_path(fountain, stand).size() > 0, "the %s can be reached from the square" % s.get("craft", "chest"))
		# The way from the house door onto the square is still open.
		var door: Vector2i = lvl._door_cell + Vector2i(0, 1)
		check(lvl.astar.get_id_path(door, fountain).size() > 0, "the house is still reachable from the square")

	# The windows.
	game.lore.clear()
	game.menus.bench = "edelsteinschleifen"
	game.menus.open("werkbank")
	check(game.menus.current == "werkbank", "the gem cutter's wheel opens its window")
	check(game.lore.has(CraftingSquare.LEARN), "the compendium tells about the crafting square")
	game.menus.close()
	game.menus.bench = ""
	game.menus.open("lager")
	check(game.menus.current == "lager", "the chest on the square opens the storage")
	game.menus.close()
	check(Lang.EN.has(CraftingSquare.LEARN), "the square has its English text")
	for b in CraftingSquare.BENCHES.values():
		for key in ["name", "sign", "prompt", "craft_line", "text"]:
			check(Lang.EN.has(b[key]), "English for \"%s\"" % b[key])

	if failures == 0:
		print("PASS: crafting_square")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
