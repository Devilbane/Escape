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
	# The storage chest is not on the square any more: it stands in the hero's own house.
	check(chests.is_empty(), "no storage chest stands on the square")
	check(not CraftingSquare.LETTERS.contains("$"), "the square has no chest letter")
	var fountain := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == "F":
				# The paved cell south-east of it (the benches stand beside it, the trees off its corners).
				fountain = Vector2i(x, y) + Vector2i(1, 1)
	for s in benches.values():
		var stand: Vector2i = s.cell + Vector2i(1, 0)
		check(not lvl.astar.is_point_solid(stand) and lvl.astar.get_id_path(fountain, stand).size() > 0, "the %s can be reached from the square" % s.get("craft", "bench"))
	# The way from the town houses on Weavers' Lane onto the square is still open.
	var door: Vector2i = lvl.world_to_cell(lvl.doors["^1"])
	check(lvl.astar.get_id_path(door, fountain).size() > 0, "the town houses are still reachable from the square")

	# The windows.
	game.lore.clear()
	game.menus.bench = "edelsteinschleifen"
	game.menus.open("werkbank")
	check(game.menus.current == "werkbank", "the gem cutter's wheel opens its window")
	check(game.lore.has(CraftingSquare.LEARN), "the compendium tells about the crafting square")
	game.menus.close()
	game.menus.bench = ""
	check(Lang.EN.has(CraftingSquare.LEARN), "the square has its English text")
	for b in CraftingSquare.BENCHES.values():
		for key in ["name", "sign", "prompt", "craft_line", "text"]:
			check(Lang.EN.has(b[key]), "English for \"%s\"" % b[key])

	if failures == 0:
		print("PASS: crafting_square")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
