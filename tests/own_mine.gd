extends SceneTree
## Headless test for the walk-in mine (see OwnMine): a claim post on the hero's mining plot, a mine opened over a
## prospecting mark (one per plot), going down to the mine floor with its face, the window at the face (hammer,
## fire in hard rock, support, haul), the way back up to the plot, and English for every text.
## Run with: godot --headless --fixed-fps 60 -s tests/own_mine.gd

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
	MineClaims.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames >= 5 and not started and "state" in game:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _mark(cell: Vector2i, rock: String) -> Dictionary:
	var s := {"cell": [cell.x, cell.y], "source": "berg", "main": rock, "main_pct": 70, "second": "", "second_pct": 0,
			"trace_pct": 8, "traces": [{"id": "rost", "pct": 8}], "noise": "basalt", "noise_pct": 2, "anomaly": "", "anomaly_pct": 0}
	if rock == "basalt":
		s.noise = "gneis"
	var m := Prospecting.mark_from(s)
	m["file"] = "11_die_freiheit.txt"
	return m


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Mine test"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var rect := Rect2i()
	for y in range(lvl.height - 2):
		for x in range(lvl.grid[y].length() - 2):
			var r := Rect2i(x, y, 2, 2)
			if rect.size == Vector2i.ZERO and Plots.problem(lvl, r, Plots.MINING) == "":
				rect = r
	check(rect.size != Vector2i.ZERO, "found scree for a mining plot")
	check(Plots.register(lvl, game.hero_name, rect, Plots.MINING) == "", "mining plot registered")
	game.load_level(game._outdoor_index(), false)
	await _wait(10)
	lvl = game.level
	var post := {}
	for s: Dictionary in lvl.stations:
		if s.kind == OwnMine.POST:
			post = s
	check(not post.is_empty(), "a claim post stands on the plot")
	check(game.interiors.has(OwnMine.ID), "the mine floor is a known building")
	check(Menus.fixed_size(OwnMine.KIND) != Vector2.ZERO, "the window has a fixed size")

	# No sample yet: no mine.
	game.prospecting.marks = []
	OwnMine.use_post(game, post)
	check(not MineClaims.has_mine(rect), "no mine without a mark on the plot")
	check(game.level == lvl, "the hero stays outside")

	# A mark of basalt (soft): the mine opens and the hero goes down.
	game.prospecting.marks = [_mark(rect.position, "basalt")]
	OwnMine.use_post(game, post)
	check(MineClaims.has_mine(rect), "the mine is opened over the mark")
	await _wait(120)
	check(game.level.building == OwnMine.ID, "the hero stands in the mine")
	var face := {}
	for s: Dictionary in game.level.stations:
		if s.kind == OwnMine.FACE:
			face = s
	check(not face.is_empty(), "the mine has a face")
	game.menus.open(OwnMine.KIND)
	check(game.menus.current == OwnMine.KIND, "the window at the face opens")
	game.menus.close()

	# Work: hammer, support, haul.
	var mine := MineClaims.on_plot(rect)
	check(not MineWork.is_hard(mine), "basalt is soft")
	OwnMine._work(game.menus, "hammer")
	OwnMine._work(game.menus, "hammer")
	check(int(MineClaims.on_plot(rect).advances) == 2, "two advances by hammer are stored")
	OwnMine._work(game.menus, "hammer")
	check(int(MineClaims.on_plot(rect).advances) == 2, "the third waits for a support")
	game.player.bag.append(OwnMine.TIMBER)
	OwnMine._support(game.menus)
	check(int(MineClaims.on_plot(rect).supports) == 1 and not game.player.bag.has(OwnMine.TIMBER), "a support costs timber")
	OwnMine._haul(game.menus)
	check(float(MineClaims.on_plot(rect).stock_mass) > 0.0, "a bucket reaches the stockpile")

	# Cart: timber builds it, and it carries more.
	game.player.bag.append(OwnMine.TIMBER)
	OwnMine._build_cart(game.menus)
	check(not bool(MineClaims.on_plot(rect).get("cart", false)), "a cart needs its timber")
	for i in MineWork.CART_TIMBER:
		game.player.bag.append(OwnMine.TIMBER)
	OwnMine._build_cart(game.menus)
	check(bool(MineClaims.on_plot(rect).get("cart", false)) and game.player.bag.count(OwnMine.TIMBER) == 1, "the cart is built and costs its timber")
	var before_stock := float(MineClaims.on_plot(rect).stock_mass)
	OwnMine._work(game.menus, "hammer")
	OwnMine._haul(game.menus)
	check(float(MineClaims.on_plot(rect).stock_mass) - before_stock >= MineWork.CART_LOAD - 0.001, "the cart takes a whole advance's rock up")

	# Out again, to the plot.
	game._leave_building(true)
	await _wait(120)
	check(game.level is Outdoor, "back on the open map")
	var away: float = game.player.global_position.distance_to(game.level.cell_to_world(rect.position + rect.size / 2))
	check(away < Level.TILE * 3.0, "the hero comes out beside the post (%.1f m away)" % away)

	# The stamp mill and the trough on the plot.
	var mill := {}
	for st: Dictionary in game.level.stations:
		if st.kind == OwnMine.MILL:
			mill = st
	check(not mill.is_empty(), "a stamp mill stands on the plot")
	check(Menus.fixed_size(OwnMine.MILL_KIND) != Vector2.ZERO, "the mill window has a fixed size")
	var stock_mass := float(MineClaims.on_plot(rect).stock_mass)
	check(stock_mass > 0.0, "there is rock on the stockpile")
	OwnMine.use_mill(game, mill)
	check(game.menus.current == OwnMine.MILL_KIND, "the mill window opens")
	game.menus.close()
	OwnMine._stamp(game.menus)
	check(float(MineClaims.on_plot(rect).stock_mass) == 0.0 and float(MineClaims.on_plot(rect).pulp_mass) == stock_mass, "stamping turns the stockpile into pulp")
	var wash_before: float = float(MineClaims.on_plot(rect).pulp_mass)
	OwnMine._wash(game.menus)
	check(float(MineClaims.on_plot(rect).pulp_mass) == wash_before, "washing needs a bucket of water")
	game.player.bag.append(OwnMine.WATER)
	OwnMine._wash(game.menus)
	check(float(MineClaims.on_plot(rect).pulp_mass) == 0.0, "washing empties the pulp")

	# One mine per plot.
	check(MineClaims.open(game.hero_name, rect, game.prospecting.marks) == "have", "a second mine on the plot is refused")

	# English.
	for key in OwnMine_keys():
		check(Lang.EN.has(key), "English for: " + key.substr(0, 40))
	MineClaims.release(game.hero_name)
	Plots.release(game.hero_name)
	if failures == 0:
		print("PASS: own mine")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func OwnMine_keys() -> Array:
	var out := []
	var src := FileAccess.get_file_as_string("res://scripts/own_mine.gd")
	var re := RegEx.new()
	re.compile('Lang\\.t\\("((?:[^"\\\\]|\\\\.)*)"\\)')
	for m in re.search_all(src):
		out.append(m.get_string(1).replace("\\n", "\n"))
	return out
