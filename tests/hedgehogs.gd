extends SceneTree
## Headless test for the hedgehogs (see Hedgehog, WoodsLife): some live in the woods and
## some in the village, they sleep curled up by day, snuffle about at night, roll up when the
## hero comes close, unroll when the hero has gone, and hibernate in winter.
## Run with: godot --headless --fixed-fps 60 -s tests/hedgehogs.gd

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


func _set_hour(hour: float) -> void:
	game.day_hour = hour
	game._tick_clock(0.0)


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await process_frame
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	_set_hour(12.0)
	lvl.night = false
	game.season_shift = 100
	var woods: WoodsLife = lvl.woods
	check(woods != null, "the woods have wildlife")
	if woods == null:
		_finish()
		return
	var hogs := woods.hedgehogs
	check(hogs.size() >= 3 and hogs.size() <= WoodsLife.MAX_HEDGEHOGS, "a few hedgehogs (%d)" % hogs.size())
	var village := 0
	for h: Hedgehog in hogs:
		check(lvl.is_open(lvl.world_to_cell(h.global_position)), "a hedgehog stands on open ground")
		if lvl._in_village(lvl.world_to_cell(h.tree.pos)) or lvl._in_village(h.tree.cell):
			village += 1
	check(village >= 1, "some hedgehogs live in the village (%d)" % village)
	check(village < hogs.size(), "some hedgehogs live in the woods")
	if hogs.is_empty():
		_finish()
		return
	var hog: Hedgehog = hogs[0]
	for h: Hedgehog in hogs:
		if not h.is_village():
			hog = h
			break
	var far := hog.global_position + Vector3(60, 0, 0)

	# By day it sleeps in a ball.
	hero.global_position = far
	for i in 90:
		await physics_frame
	check(hog.state == "sleep", "it sleeps by day (%s)" % hog.state)

	# At dusk it comes out and snuffles about.
	_set_hour(21.0)
	lvl.night = true
	var out := false
	for i in 60 * 6:
		await physics_frame
		out = out or hog.state in ["snuffle", "walk"]
	check(out, "it comes out at night")
	check(not hog.is_curled() or hog.state == "snuffle", "it is on its feet at night (%s)" % hog.state)

	# It rolls up when the hero comes close, and stays so while the hero stays.
	hero.global_position = hog.global_position + Vector3(Hedgehog.SHY * 0.5, 0, 0)
	await physics_frame
	await physics_frame
	check(hog.state == "curl", "it rolls up when the hero comes close (%s)" % hog.state)
	for i in 60 * 5:
		hero.global_position = hog.global_position + Vector3(Hedgehog.SHY * 0.5, 0, 0)
		await physics_frame
	check(hog.state == "curl", "it stays rolled up while the hero is near (%s)" % hog.state)
	check(hog._curl > 0.95, "a round ball (%.2f)" % hog._curl)

	# And unrolls again once the hero has gone.
	hero.global_position = hog.global_position + Vector3(60, 0, 0)
	for i in 60 * 6:
		await physics_frame
	check(hog.state in ["snuffle", "walk"], "it unrolls once the hero has gone (%s)" % hog.state)

	# In autumn a hedgehog that lives near the village's apple trees fetches an apple: it waits under
	# the tree, an apple falls, it scurries under it, the apple sticks on its back and it carries
	# it to its hoard.
	game.season_shift = Weather.YEAR_DAYS - Weather.WINTER_DAYS - 3
	game._tick_clock(0.0)
	var keeper: Hedgehog
	for h: Hedgehog in hogs:
		if h.apple_tree != Vector3.INF:
			keeper = h
	check(keeper != null and keeper.hoard != null, "a village hedgehog keeps an apple hoard")
	if keeper != null and keeper.hoard != null:
		var before := keeper.hoard.count
		check(before == AppleHoard.START, "the hoard starts with a few apples (%d)" % before)
		keeper._pause = 0.0
		keeper._apple = null
		keeper._begin("snuffle", 0.0)
		# Starts close to the tree (on the first open tile 3 to 8 m from it).
		var c0 := lvl.world_to_cell(keeper.apple_tree)
		var found := false
		for r in range(1, 4):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var c := c0 + Vector2i(dx, dy)
					var w := lvl.cell_to_world(c)
					if not found and lvl.is_open(c) and Vector2(w.x - keeper.apple_tree.x, w.z - keeper.apple_tree.z).length() > 3.0:
						keeper.global_position = Vector3(w.x, 0.0, w.z)
						found = true
		check(found, "an open spot near the apple tree")
		check(keeper._go_to_tree(), "it finds the way to the apple tree")
		var seen := {}
		var checked_back := false
		for i in 60 * 160:
			hero.global_position = keeper.global_position + Vector3(30, 0, 0)
			await physics_frame
			seen[keeper.state] = true
			if keeper.state == "carry" and not checked_back:
				checked_back = true
				check(keeper._apple != null and keeper._apple.get_parent() == keeper._tilt, "the apple sticks on its back")
			if keeper.hoard.count > before:
				break
		for st in ["to_tree", "wait", "falling", "startle", "carry", "stash"]:
			check(seen.has(st), "the run goes through %s" % st)
		check(keeper.hoard.count == before + 1, "it adds the apple to its hoard (%d)" % keeper.hoard.count)
		check(keeper._apple == null, "it no longer carries the apple")

	# A village hedgehog is about by day and does not curl up when the hero comes close.
	game.season_shift = 100
	game._tick_clock(0.0)
	_set_hour(12.0)
	lvl.night = false
	var local: Hedgehog
	for h: Hedgehog in hogs:
		if h.is_village():
			local = h
	check(local != null, "there is a village hedgehog")
	if local != null:
		local.state = "sleep"
		hero.global_position = local.global_position + Vector3(60, 0, 0)
		var up := false
		for i in 60 * 6:
			await physics_frame
			up = up or local.state in ["snuffle", "walk"]
		check(up, "a village hedgehog is about by day")
		for i in 60 * 3:
			hero.global_position = local.global_position + Vector3(1.0, 0, 0)
			await physics_frame
			check(local.state != "curl", "a village hedgehog does not curl up near the hero (%s)" % local.state)
			if local.state == "curl":
				break

	# In winter it hibernates: curled up even at night.
	game.season_shift = Weather.YEAR_DAYS - 3
	game._tick_clock(0.0)
	hero.global_position = hog.global_position + Vector3(30, 0, 0)
	for i in 60 * 6:
		await physics_frame
	check(hog.state == "sleep", "it hibernates in winter (%s)" % hog.state)
	_finish()


func _finish() -> void:
	if failures == 0:
		print("PASS")
	else:
		print("FAILED: %d" % failures)
	quit(failures)
