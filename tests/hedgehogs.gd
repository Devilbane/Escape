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

	# In winter it hibernates: curled up even at night.
	game.season_shift = Weather.YEAR_DAYS - 3
	game._tick_clock(0.0)
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
