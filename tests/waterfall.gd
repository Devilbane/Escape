extends SceneTree
## The river's spring (see Waterfall): the fall stands at its notch in the cliff, the pool in front of it
## has no path across, the water lies on the rock, and the ice and snow of winter show.
## Run with: godot --headless -s tests/waterfall.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Spring test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	var notch := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == "∩":
				notch = Vector2i(x, y)
	check(notch.x >= 0, "the map has the spring's notch")
	var fall: Waterfall = lvl.waterfall
	check(fall != null, "the waterfall is built")
	if fall == null or notch.x < 0:
		quit(1)
		return
	check(lvl.is_open(notch), "the notch's porch can be walked")
	# No path leads to the porch: the pool lies in front of it, in summer open water, solid to walk on only frozen.
	for k in 4:
		check(lvl.cell_char(notch + Vector2i(0, 1 + k)) == "≈", "pool tile %d in front of the porch is water, no path" % k)
	var porch_south := notch + Vector2i(0, 1)
	check(lvl.astar.is_point_solid(porch_south), "in summer the water in front of the porch cannot be walked")
	var shore := notch + Vector2i(0, SpringCave.SHORE_TILES)
	check(lvl.is_open(shore), "the shore in front of the pool is open ground")
	check(lvl.astar.get_point_path(shore, notch).is_empty(), "in summer there is no way from the shore to the porch")
	# Frozen, the river can be crossed to the porch.
	game.ice_cover = 1.0
	lvl.set_ice(1.0)
	await _wait(3)
	check(not lvl.astar.is_point_solid(porch_south), "in winter the frozen pool in front of the porch can be walked")
	check(not lvl.astar.get_point_path(shore, notch).is_empty(), "in winter there is a way over the ice to the porch")
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	# The water lies on the rock, not in the air or under it.
	var here := fall.global_position
	var rock := Mountains.surface_at(lvl, here.x, here.z + Waterfall.SHELF_BACK_V - 3.0)
	check(rock != INF and rock > 2.0, "the cliff above the notch is mesh rock (height %.1f)" % rock)
	check(fall.find_children("*", "MeshInstance3D", true, false).size() > 20, "the fall has its rocks and its water")
	# Winter: icicles, ice at the foot and the shelf's snow appear, the spray stops.
	fall.set_ice(0.0)
	fall.set_snow(0.0)
	check(not fall._icicles.visible and not fall._snow_caps.visible, "in summer there are no icicles and no snow")
	game.ice_cover = 1.0
	lvl.set_ice(1.0)
	lvl.set_snow(1.0)
	check(fall._icicles.visible and fall._ice_foot.visible and fall._snow_caps.visible, "in winter the fall is frozen and snowed on")
	for puff in fall._sprays:
		check(not puff.emitting, "the spray stops when the fall is frozen")
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	lvl.set_snow(0.0)
	check(not fall._icicles.visible and fall._sprays[0].emitting, "the thaw sets the water running again")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: waterfall")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
