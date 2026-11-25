extends SceneTree
## Leaves and sticks drift down the whole river (see RiverFlow): every waypoint lies on water, every stretch
## carries seasonal leaves, and the little river from the outfall has its own.
## Run with: godot --headless -s tests/river_flow.gd

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
	game.hero_name = "River flow"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var off_water := 0
	for i in RiverFlow.WAYPOINTS.size():
		var p := RiverFlow.WAYPOINTS[i]
		if not RiverFlow.WATER.contains(lvl.cell_char(Vector2i(int(p.x), int(p.y)))):
			off_water += 1
			print("not on water: ", p)
		if i > 0:
			var q := RiverFlow.WAYPOINTS[i - 1]
			for k in 9:
				var m := q.lerp(p, k / 8.0)
				if not RiverFlow.WATER.contains(lvl.cell_char(Vector2i(int(m.x), int(m.y)))):
					off_water += 1
	check(off_water == 0, "the river's flow stays on the water (%d points off it)" % off_water)
	var flows := 0
	for n in lvl.get_children():
		if n is StreamFlow and n.name.begins_with("RiverFlow"):
			flows += 1
			check((n as StreamFlow).seasonal and (n as StreamFlow)._sticks != null, "every stretch has seasonal leaves and sticks")
	check(flows == RiverFlow.WAYPOINTS.size() - 1, "a flow on every stretch of the river (%d)" % flows)
	var outfall := lvl.find_child("OutfallLeaves", true, false) as StreamFlow
	check(outfall != null and outfall.seasonal, "the river below the outfall carries leaves too")
	game.delete_save(game.save_path())
	print("PASS: river_flow" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
