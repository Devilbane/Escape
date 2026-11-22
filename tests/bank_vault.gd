extends SceneTree
## Headless test for the bank and its vault cellar walked into on the map (see BankVault): the
## layout hangs together from the stairs, the bank stands on the map's bank block with its door
## to the north, the hero walks in, down the stairs into the vault and the surface hides, every
## locker has its bars and plate, the hero's own locker opens when they run into its bars (but
## not from the street above), no plot can be marked out over it, and with the switch off the
## bank is the old tower with its way into the cellar level again.
## Run with: godot --headless --fixed-fps 60 -s tests/bank_vault.gd
## With SHOTS=<folder> and a display it also saves pictures of the bank and the vault.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
const HERO := "Vault test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("ok   ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Bank.reload()
	Bank.rent_vault("Someone else")
	Bank.rent_vault(HERO)
	Bank.store(HERO, Items.ALL.keys()[0])
	Bank.deposit(HERO, 120)
	_check_layout()
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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


## The layout alone: every row as wide as the plot, everything reached from the stairs, a
## locker of LOCKER cells at every slot, as big as the old cellar's or bigger.
func _check_layout() -> void:
	var cells := BankVault.cells()
	var n := BankVault.PLOT.size * HouseSketch.CELLS_PER_TILE
	check(BankVault.LAYOUT.size() == n.y, "the layout has a row for every cell of the plot")
	for row: String in BankVault.LAYOUT:
		check(row.length() == n.x, "every row of the layout is as wide as the plot")
	var stairs := HouseSketch.stairs_cells(BankVault.STAIRS_TOP.x, BankVault.STAIRS_TOP.y, BankVault.STAIRS_DIR)
	check(BankVault.BANK.has_point(stairs[0]) and BankVault.BANK.has_point(stairs[1]), "the stairs go down inside the bank")
	check(cells.get(stairs[2], "") == ".", "the stairs lead down into the hall")
	var seen := {stairs[2]: true}
	var todo: Array[Vector2i] = [stairs[2]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in HouseSketch.DOWN.values():
			if cells.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				todo.append(c + d)
	check(seen.size() == cells.size(), "every locker and the aisle are reached from the stairs (%d of %d)" % [seen.size(), cells.size()])
	check(BankVault.SLOTS.size() >= 16, "at least as many lockers as the old cellar (%d)" % BankVault.SLOTS.size())
	var lockers := 0
	for slot: Vector2i in BankVault.SLOTS:
		var whole := true
		for dy in BankVault.LOCKER.y:
			for dx in BankVault.LOCKER.x:
				if cells.get(slot + Vector2i(dx, dy), "") != "U":
					whole = false
		if whole:
			lockers += 1
		var before := slot + (Vector2i(0, BankVault.LOCKER.y) if slot.y < 8 else Vector2i(0, -1))
		check(cells.get(before, "") == ".", "locker %s opens onto the aisle" % slot)
	check(lockers == BankVault.SLOTS.size(), "every locker is a room of its own cells (%d)" % lockers)
	check(BankVault.LOCKER.x * BankVault.LOCKER.y * HouseSketch.CELL * HouseSketch.CELL > Level.TILE * Level.TILE, "a locker is bigger than the old cellar's")
	var house := BankVault.sketch()
	check(house.count(HouseSketch.DOOR) == 1 and house.count(HouseSketch.WINDOW) >= 2, "the bank has a door and windows")
	check(house.count(HouseSketch.STAIRS) == 1, "stairs lead down")
	check(house.count(HouseSketch.DIG) == cells.size(), "every cell of the vault is dug")
	check(Lang.EN.has("Der Tresorkeller liegt unter der Bank: Geh hinein und die Treppe hinab."), "English for the banker's hint")


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = HERO
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var sketcher: HouseSketcher = game.house_sketcher
	var bank := BankVault.sketch()
	var hero: Player = game.player
	# Up on the map: the bank on its block, nothing of the old tower, no way into the cellar level.
	for y in range(BankVault.BANK.position.y, BankVault.BANK.end.y):
		for x in range(BankVault.BANK.position.x, BankVault.BANK.end.x):
			var tile := BankVault.PLOT.position + Vector2i(x, y) / HouseSketch.CELLS_PER_TILE
			check(level.cell_char(tile) == "b", "the bank stands on the bank's block (%s)" % tile)
	check(level.stations.filter(func(s): return s.kind == "eingang" and s.get("building", "") == "b").is_empty(), "no door into the old cellar level")
	check(not level.get_children().any(func(n): return n.has_meta("block") and level.cell_char((n.get_meta("block") as Rect2i).position) == "b" and n.name != "BankSite"), "the old tower is gone")
	check(level.doors.has("b"), "the bank has its door for errands")
	var tile0 := BankVault.PLOT.position + BankVault.BANK.position / HouseSketch.CELLS_PER_TILE
	check(not level.is_opaque(tile0), "the bank's block lets sight through (its walls stop it)")
	var why := Plots.problem(level, Rect2i(BankVault.PLOT.position + Vector2i(0, 3), Vector2i(2, 2)))
	check(why != "", "no plot can be marked out over the vault (%s)" % why)
	var view: CellarView = sketcher.cellar_view
	check(view.holes.size() >= BankVault.cells().size(), "the vault's cells are holes in the ground (%d)" % view.holes.size())
	var aisle := BankVault.floor_at(Vector2i(10, 8))
	var space := level.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(aisle.x, 5, aisle.z), Vector3(aisle.x, -10, aisle.z)))
	check(not down.is_empty() and absf(down.position.y) < 0.2, "the street over the aisle is solid to walk on (%s)" % str(down.get("position", "nothing")))
	var into := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(aisle.x, -0.5, aisle.z), Vector3(aisle.x, -10, aisle.z)))
	check(not into.is_empty() and absf(into.position.y + HouseSketch.DEPTH) < 0.1, "under it the aisle's floor lies DEPTH down (%s)" % str(into.get("position", "nothing")))
	check(not sketcher.deep.visible, "on the ground the vault is not drawn")
	# The lockers: the hero's own opens from the aisle, not from the street above.
	var own := level.stations.filter(func(s): return s.kind == BankVault.KIND)
	check(own.size() == 1, "the hero's own locker opens (%d)" % own.size())
	if own.size() == 1:
		var s: Dictionary = own[0]
		var slot: Vector2i = BankVault.SLOTS[Bank.vault_holders().find(HERO)]
		var bars := BankVault.bars_middle(slot)
		check(level.station_at(bars + BankVault.out_of(slot) * 0.2 + Vector3(0, 0.6, 0)) == s, "running into its bars opens it")
		check(level.station_at(Vector3(bars.x, 0.5, bars.z) + BankVault.out_of(slot) * 0.2).get("kind", "") != BankVault.KIND, "but not from the street above")
		var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(bars + BankVault.out_of(slot) * 1.0 + Vector3(0, 1.0, 0), bars - BankVault.out_of(slot) * 1.0 + Vector3(0, 1.0, 0)))
		check(not through.is_empty(), "the bars stop anyone walking into a locker")
	var plates := sketcher.deep.find_children("*", "Label3D", true, false)
	check(plates.size() >= BankVault.SLOTS.size(), "every locker has its name plate (%d)" % plates.size())
	check(plates.any(func(p): return (p as Label3D).text == HERO), "the hero's plate is there")
	# Walk in through the door, to the stairs and down.
	var door := bank.cell_world(BankVault.door_cell().x, BankVault.door_cell().y)
	if shots != "":
		hero.global_position = door + Vector3(-1.0, 0.1, -7.0)
		game._snap_camera()
		await _shot("bank_outside")
	hero.global_position = door + Vector3(0, 0.1, -3.0)
	hero.reset_physics_interpolation()
	await _physics(5)
	var top := BankVault.STAIRS_TOP
	var way := [door + Vector3(0, 0, -1.2), door, bank.cell_world(top.x, top.y - 1), bank.cell_world(top.x, top.y), bank.cell_world(top.x, top.y + 1),
			bank.cell_world(top.x, top.y + 2), bank.cell_world(top.x, top.y + 3), bank.cell_world(top.x, top.y + 5)]
	for p: Vector3 in way:
		for i in 90:
			hero.path.clear()
			hero.path.append(p)
			await physics_frame
			if Vector2(hero.global_position.x - p.x, hero.global_position.z - p.z).length() < 0.3:
				break
	hero.path.clear()
	await _physics(10)
	check(hero.global_position.y < -HouseSketch.DEPTH + 0.4, "the hero walked in and down the stairs (%s)" % hero.global_position)
	await _wait(10)
	check(view.active, "down in the vault the cellar view is on")
	check(sketcher.deep.visible, "down there the vault is drawn")
	check(game._under_roof(), "no weather falls into the vault")
	if shots != "":
		await _shot("vault_stairs")
		hero.global_position = BankVault.floor_at(Vector2i(8, 9)) + Vector3(0, 0.1, 0)
		game._snap_camera()
		await _shot("vault_aisle")
	# Back up: everything shows again, the vault hides.
	hero.global_position = door + Vector3(0, 0.1, -3.0)
	game._snap_camera()
	await _wait(20)
	check(not view.active and not sketcher.deep.visible, "back up the vault hides again")
	# Something put in or taken out: the lockers fill again, one station still.
	level.refresh_vaults()
	await _wait(2)
	check(level.stations.filter(func(s): return s.kind == BankVault.KIND).size() == 1, "filling the lockers again adds no second station")
	# The switch off: the old tower and the way into the cellar level.
	BankVault.on = false
	game.load_level(game._outdoor_index(), false)
	await _wait(10)
	level = game.level
	check(level.stations.any(func(s): return s.kind == "eingang" and s.get("building", "") == "b"), "switched off, the bank's door leads into the cellar level")
	check(level.get_children().any(func(n): return n.has_meta("block") and level.cell_char((n.get_meta("block") as Rect2i).position) == "b" and n.name != "BankSite"), "switched off, the old tower stands")
	check(not BankVault.covers_tile(BankVault.PLOT.position + Vector2i(1, 4)), "switched off, plots may go there")
	BankVault.on = true
	print("PASS: bank vault" if failures == 0 else "FAILED: bank vault (%d)" % failures)
	quit(1 if failures > 0 else 0)


## The game's own camera, as the player sees it.
func _shot(name: String) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.level.set_hour(12.0)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
