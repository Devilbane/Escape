extends SceneTree
## The fish under the river's ice (see IceFish): built when the water first freezes, shown while it is
## frozen, hidden in a thaw, and they keep to the open water.
## Run with: godot --headless -s tests/ice_fish.gd

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
	game.hero_name = "Fish test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	check(lvl.ice_fish == null, "in summer there are no fish to build")
	game.ice_cover = 1.0
	lvl.set_ice(1.0)
	await _wait(5)
	var school: IceFish = lvl.ice_fish
	check(school != null, "the first frost builds the fish")
	if school == null:
		quit(1)
		return
	check(school._fish.size() >= 3, "there are fish under the ice (%d)" % school._fish.size())
	check(school.visible, "the fish show under the ice")
	var start: Array[Vector3] = []
	for f in school._fish:
		start.append(f.node.position)
	for i in 120:
		await process_frame
		school._process(0.1)
	var moved := 0
	for i in school._fish.size():
		var f: Dictionary = school._fish[i]
		var at: Vector3 = f.node.position
		if at.distance_to(start[i]) > 0.3:
			moved += 1
		check(lvl.pond_shore_at(at) > 0.5, "fish %d keeps to the water (%.2f from the bank)" % [i, lvl.pond_shore_at(at)])
	check(moved >= school._fish.size() / 2, "the fish swim (%d of %d moved)" % [moved, school._fish.size()])
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	await _wait(3)
	check(not school.visible, "the thaw hides the fish")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: ice_fish")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
