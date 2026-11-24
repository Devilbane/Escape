extends SceneTree
## The river's spring (see Waterfall): the fall stands at its notch in the cliff, the causeway of path tiles
## leads through the pool to it from the shore, the water lies on the rock, and the ice and snow of winter show.
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
	# The causeway: the shore tile south of the pool leads to the porch over the path tiles only.
	var shore := notch + Vector2i(0, Waterfall.CAUSEWAY + 1)
	check(lvl.is_open(shore), "the shore at the causeway's foot is open ground")
	var path: PackedVector2Array = lvl.astar.get_point_path(shore, notch)
	check(path.size() == Waterfall.CAUSEWAY + 2, "the causeway runs straight through the pool (%d steps)" % path.size())
	for k in Waterfall.CAUSEWAY:
		check(lvl.cell_char(notch + Vector2i(0, 1 + k)) == ",", "causeway tile %d is a path tile" % k)
	for dx in [-1, 1]:
		check(lvl.cell_char(notch + Vector2i(dx, 1)) == "≈", "the pool lies beside the causeway")
	# The water lies on the rock, not in the air or under it.
	var here := fall.global_position
	var rock := Mountains.surface_at(lvl, here.x, here.z + Waterfall.SHELF_BACK_V - 3.0)
	check(rock != INF and rock > 2.0, "the cliff above the notch is mesh rock (height %.1f)" % rock)
	check(fall.find_children("*", "MeshInstance3D", true, false).size() > 20, "the fall has its rocks and its water")
	# Winter: icicles, ice at the foot and the shelf's snow appear, the spray stops.
	fall.set_ice(0.0)
	fall.set_snow(0.0)
	check(not fall._icicles.visible and not fall._snow_caps.visible, "in summer there are no icicles and no snow")
	lvl.set_ice(1.0)
	lvl.set_snow(1.0)
	check(fall._icicles.visible and fall._ice_foot.visible and fall._snow_caps.visible, "in winter the fall is frozen and snowed on")
	for puff in fall._sprays:
		check(not puff.emitting, "the spray stops when the fall is frozen")
	lvl.set_ice(0.0)
	lvl.set_snow(0.0)
	check(not fall._icicles.visible and fall._sprays[0].emitting, "the thaw sets the water running again")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: waterfall")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
