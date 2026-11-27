extends SceneTree
## The property register at the Crown clerk (see PropertyRegister, PropertyWindow, PlotOffice): every plot is
## numbered within its area, houses show their floor areas, mining ground is listed, a hero may own several plots,
## and the rented town house goes back once the hero has a plot with a bed and a storage piece on it. The two
## windows keep one size whether the register is empty or long, in both languages.
## Run with: godot --headless -s tests/property_register.gd

const HERO := "Register test"

var failures := 0
var game: Node
var frames := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	Homes.reload()
	HouseSketch.reload()
	HouseFurniture.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## A free 3 x 3 plot that touches none of `avoid`.
func _free(level: Outdoor, avoid: Array) -> Rect2i:
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if not avoid.any(func(a): return a.grow(2).intersects(r)) and Plots.problem(level, r) == "":
				return r
	return Rect2i()


func _scree(level: Outdoor) -> Rect2i:
	for y in range(level.height - 2):
		for x in range(level.grid[y].length() - 2):
			var r := Rect2i(x, y, 2, 2)
			if Plots.problem(level, r, Plots.MINING) == "":
				return r
	return Rect2i()


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _size() -> Vector2:
	return (game.menus._panel as Control).size


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _test() -> void:
	game.hero_name = HERO
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	root.size = Vector2i(1280, 720)
	var level: Outdoor = game.level
	Lang.language = "en"
	Lang._apply()
	check(Menus.fixed_size(PropertyWindow.KIND) == PropertyWindow.SIZE, "the register window has a fixed size")
	check(Menus.fixed_size(PlotOffice.KIND) != Vector2.ZERO, "the land registry has a fixed size")

	# Empty: every section says so.
	var empty_office := await _open(PlotOffice.KIND)
	var empty_list := await _open(PropertyWindow.KIND)
	check(PropertyRegister.count(HERO, level) == 0, "nothing on record at first")
	game.menus.close()

	# Land, a house, mining ground and a rented house.
	var first := _free(level, [])
	var second := _free(level, [first])
	check(Plots.register(level, HERO, first) == "" and Plots.register(level, HERO, second) == "", "two plots are registered")
	var scree := _scree(level)
	check(scree.size != Vector2i.ZERO and Plots.register(level, HERO, scree, Plots.MINING) == "", "a mining plot is registered")
	check(Homes.claim(HERO, 1), "the hero has the elder's house")
	var land := PropertyRegister.rows("land", HERO, level)
	check(land.size() == 2, "two plots are listed")
	check(land[0].title == "Plot 1" and land[0].tag == "House stands here", "the first plot carries the house (%s)" % land[0].title)
	check(land[0].detail.contains("3 x 3 tiles, 144 m²"), "its size is given in tiles and square metres (%s)" % land[0].detail)
	var d0: Dictionary = Plots.plots_of(HERO)[0]
	var d1: Dictionary = Plots.plots_of(HERO)[1]
	check(land[1].title == ("Plot 2" if d0.area == d1.area else "Plot 1"), "the second plot is numbered within its area (%s)" % land[1].title)
	check(land[0].detail.begins_with("Meadows in the "), "an area is named (%s)" % land[0].detail)
	var mining := PropertyRegister.rows(Plots.MINING, HERO, level)
	check(mining.size() == 1 and mining[0].title == "Mining plot 1" and mining[0].detail.begins_with("Mountains in the "), "the mining plot is listed (%s)" % [mining])
	var rented := PropertyRegister.rows("rented", HERO, level)
	check(rented.size() == 1 and rented[0].title == "House no. 1" and rented[0].detail.contains("a bed") and rented[0].detail.contains("a storage piece"), "the rented house says what is lacking (%s)" % [rented])
	check(PropertyRegister.rows("house", HERO, level).is_empty(), "no house yet")
	Lang.language = "de"
	Lang._apply()
	check(PropertyRegister.rows("land", HERO, level)[0].title == "Grundstück 1", "the German title")
	Lang.language = "en"
	Lang._apply()

	# The house's floor areas.
	var plan := HouseSketch.of(HERO, first)
	for x in range(1, 4):
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.COVER, "state": HouseSketch.BUILT, "surface": "wood"}
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(x, 1, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
	plan.pieces[HouseSketch.key_of(1, 1, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": HouseSketch.BUILT, "floor": "", "wall": ""}
	var areas := PropertyRegister.house_areas(plan)
	check(areas == {"ground": 24, "cellar": 4, "roof": 24}, "a house of 3 x 2 cells: 24 m² ground floor, 4 m² cellar, 24 m² roof (%s)" % [areas])
	# A pitched roof is no ground to stand on, a floor with a slab over it is no roof, a sketch counts for nothing.
	plan.pieces.erase(HouseSketch.key_of(3, 2, HouseSketch.CELL_ORIENT))
	plan.pieces[HouseSketch.key_of(3, 2, "rx")] = {"kind": HouseSketch.SADDLE, "state": HouseSketch.BUILT}
	plan.pieces[HouseSketch.key_of(1, 1, HouseSketch.CELL_ORIENT, 1)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	plan.pieces[HouseSketch.key_of(2, 1, HouseSketch.CELL_ORIENT, 1)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.SKETCH}
	areas = PropertyRegister.house_areas(plan)
	check(areas.roof == 20, "a pitched roof does not count, the upper roof replaces the floor under it (%s)" % [areas])
	plan.save(HERO)
	var houses := PropertyRegister.rows("house", HERO, level)
	check(houses.size() == 1 and houses[0].tag == "Covered" and houses[0].detail == "Ground floor 24 m², cellar 4 m², walkable roof 20 m²", "the house row (%s)" % [houses])

	# A long register: both windows keep their size.
	var full_office := await _open(PlotOffice.KIND)
	var full_list := await _open(PropertyWindow.KIND)
	await _shot("register")
	await _open(PlotOffice.KIND)
	await _shot("registry")
	await _open(PropertyWindow.KIND)
	check(full_office == empty_office, "the land registry keeps its size (%s, %s)" % [empty_office, full_office])
	check(full_list == empty_list, "the register keeps its size (%s, %s)" % [empty_list, full_list])
	Lang.language = "de"
	Lang._apply()
	check(await _open(PropertyWindow.KIND) == full_list, "and in German")
	check(await _open(PlotOffice.KIND) == full_office, "the land registry too in German")
	Lang.language = "en"
	Lang._apply()
	game.menus.close()

	# The rented house goes back once the hero has a plot with a bed and a storage piece on it.
	check(not PropertyRegister.settled(HERO) and PropertyRegister.leave_rental(HERO) == 0, "no bed, no storage: the house stays rented")
	var store := HouseFurniture.of(HERO)
	store.add("bett")
	store.add("truhe")
	check(store.place(plan, "bett", 0, 1, 1, 0) == "", "the bed is put down")
	store.save(HERO)
	check(Homes.house_of(HERO) == 1, "a bed alone does not end the rent")
	check(PropertyRegister.missing(HERO).size() == 1, "only storage is lacking")
	check(store.place(plan, "truhe", 0, 3, 1, 0) == "", "the chest is put down")
	store.save(HERO)
	check(PropertyRegister.settled(HERO), "plot, bed and storage make a home")
	check(Homes.house_of(HERO) == 0 and Homes.owner_of(1) == "", "the rented house was given back")
	check(not game._may_enter_house(1), "the empty house cannot be taken again")
	check(PropertyRegister.rows("rented", HERO, level).is_empty(), "nothing is rented any more")
	# The furniture itself stays: a second hero without a home can still rent it.
	check(Homes.claim("Newcomer", 1), "the house is free for a newcomer")
	Homes.release(1)

	# Another hero's plots stay out of the list.
	check(PropertyRegister.count("Stranger", level) == 0, "a stranger owns nothing")

	Plots.release(HERO)
	check(PropertyRegister.count(HERO, level) == 0, "released plots leave the register")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: property register")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Opens a window and returns the size of its frame.
func _open(kind: String) -> Vector2:
	game.menus.open(kind)
	await _wait()
	return _size()


## With SHOTS=<folder> and a display: saves the open window as a picture.
func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
