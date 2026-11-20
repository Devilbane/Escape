extends SceneTree
## A ballista on the hero's plot (see HouseSketch.BALLISTA, HouseBallista and
## HouseSketcher): planned on the ground or on a flat roof, never indoors, under
## a roof or in a hole, at most MAX_BALLISTAE; built after its roof and kept in
## the books. Built, it turns to the nearest slime within reach, shoots a bolt
## that costs it life, winds up again, and leaves slimes out of reach alone.
## Run with: godot --headless --fixed-fps 60 -s tests/house_ballista.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_plan()
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _test_plan() -> void:
	var h := HouseSketch.new()
	h.plot = Rect2i(10, 10, 4, 4)
	check(h.problem_ballista(2, 2, 0) == "", "a ballista fits in the garden")
	check(h.sketch_ballista(2, 2, 0), "and is planned there")
	check(h.problem_ballista(2, 2, 0) == "taken", "one ballista to a square")
	check(h.problem_ballista(9, 9, 0) == "outside", "not outside the plot")
	check(h.problem_ballista(5, 5, 1) == "ballista no roof", "on the upper level only on a flat roof")
	h.sketch_roof(h.cells_between(Vector2i(5, 5), Vector2i(6, 6)), HouseSketch.SLAB, 0)
	check(h.ballista_storey(5, 5) == 1 and h.ballista_storey(2, 2) == 0, "a click picks the roof where there is one")
	check(h.problem_ballista(5, 5, 0) == "under roof", "not indoors under the roof")
	check(h.sketch_ballista(5, 5, 1), "a ballista on the flat roof")
	h.sketch_roof([[6, 6, "rx"]], HouseSketch.SADDLE, 1)
	check(h.problem_ballista(6, 6, 1) == "under roof", "not under a saddle roof")
	check(h.problem_roof(2, 2, 0) == "taken" and h.problem_dig(2, 2) == "taken", "no roof over it and no hole under it")
	check(h.erase_above(5, 5, 0) == "ballista", "the roof under a ballista stays until it is gone")
	check(h.sketch_ballista(0, 0, 0), "a third ballista")
	check(h.problem_ballista(1, 0, 0) == "many", "but not a fourth")
	h.undo()
	check(h.ballista_at(0, 0, 0).is_empty(), "undo takes a ballista back")
	check(HouseSketch.cost_of({"kind": HouseSketch.BALLISTA}) == {"bauholz": 6, "steinblock": 2}, "it costs timber and stone")
	h.deposit("steinblock", 20)
	h.deposit("bauholz", 30)
	h.ordered = true
	var order := []
	for i in 20:
		var r := h.build_next()
		if r.is_empty() or r.has("why"):
			break
		order.append(r.kind)
	check(order.find("slab") < order.rfind("ballista") and order.count("ballista") == 2, "the roof before the ballista on it: %s" % [order])
	h.save("ballista_test_hero")
	HouseSketch.reload()
	var again := HouseSketch.of("ballista_test_hero", h.plot)
	check(again.count(HouseSketch.BALLISTA, HouseSketch.BUILT) == 2, "ballistae are kept in the books")
	check(again.erase_above(2, 2, 0) == "" and again.ballista_at(2, 2, 0).state == HouseSketch.DEMOLISH, "the eraser marks a built ballista for taking down")


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game.hero_name = "Ballista test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var found := Rect2i()
	for y in range(lvl.height - 5):
		for x in range(lvl.grid[y].length() - 5):
			var r := Rect2i(x, y, 4, 4)
			if Plots.problem(lvl, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(lvl, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sketcher: HouseSketcher = game.house_sketcher
	var plan := sketcher.plan
	sketcher.enter()
	var bar_width: float = sketcher._bar.get_combined_minimum_size().x
	sketcher.select_tool(HouseSketcher.TOOL_BALLISTA)
	var spot := plan.cell_world(1, 1)
	sketcher.hover(spot)
	check(sketcher._status.text.begins_with(Lang.t("Balliste: Sie schießt auf Schleime bis %d m weit (der Kreis).").get_slice("%", 0)), "the ghost tells the reach")
	sketcher.mouse(spot, true, MOUSE_BUTTON_LEFT)
	sketcher.mouse(spot, false, MOUSE_BUTTON_LEFT)
	check(plan.ballista_at(1, 1, 0).get("state", "") == HouseSketch.SKETCH, "a click plans a ballista")
	check(bar_width <= 1280.0, "the tool bar still fits the screen (%d px)" % bar_width)
	plan.deposit("steinblock", 2)
	plan.deposit("bauholz", 6)
	plan.ordered = true
	check(sketcher.work_once(), "the hero builds it")
	check(plan.ballista_at(1, 1, 0).state == HouseSketch.BUILT, "it is built")
	var guns := sketcher.ballistae()
	check(guns.size() == 1, "one ballista stands on the map")
	if guns.size() != 1:
		_end()
		return
	var gun: HouseBallista = guns[0]
	check(gun._ring.visible, "the blueprint shows its reach")
	sketcher.leave()
	check(not gun._ring.visible, "and hides it again")
	# Only our slimes about, the hero far off.
	for e in lvl.enemies:
		if is_instance_valid(e):
			check(not HouseBallista.aims_at(e) or SlimeCoat.is_slime(e), "it aims at slimes only (%s)" % e.kind)
			e.dead = true
			e.global_position = Vector3(0, -50, 0)
	lvl.player.global_position = gun.global_position + Vector3(0, 0, 60)
	var far := lvl.spawn_slime("schleim", gun.global_position + Vector3(HouseBallista.RANGE + 6, 0, 0), {})
	await _wait(30)
	check(gun.target == null and gun.shots == 0, "a slime out of reach is left alone")
	var near := lvl.spawn_slime("schleim", gun.global_position + Vector3(-9, 0, 4), {})
	near.rated_level = Enemy.fit_level(near.kind, near._stats, near.hardening, 20, SlimeGrowth.MAX_LEVEL)
	SlimeGrowth.blob_up(near)
	near.hp = near.max_hp()
	var life := near.hp
	var bolt := HouseBallista.damage_for(near)
	await _wait(150)
	check(gun.target == near, "it aims at the slime in reach")
	check(gun.shots >= 1, "and shoots")
	check(near.hp <= life - bolt, "the bolt costs it life (%d -> %d, a bolt %d)" % [life, near.hp, bolt])
	# From one shot to the next it winds up for RELOAD seconds.
	var first := gun.shots
	var waited := 0
	while gun.shots == first and waited < 400:
		await _wait(1)
		waited += 1
	var between := 0
	while gun.shots == first + 1 and between < 400:
		await _wait(1)
		between += 1
	check(absi(between - int(HouseBallista.RELOAD * 60)) <= 3, "one bolt every %.1f s (%d frames apart)" % [HouseBallista.RELOAD, between])
	check(bolt * 12 >= life, "a Blob falls to about ten bolts (%d life, %d a bolt)" % [life, bolt])
	far.queue_free()
	_end()


func _end() -> void:
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house ballista" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
