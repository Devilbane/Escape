extends SceneTree
## Street lamps (see Outdoor._build_lantern): every lamp on a map tile reaches its arm and lantern
## towards the nearest walkway, never away from it, and a lamp right beside a walkway stands at its edge.

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	HouseFurniture.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_run()
	print("PASS: street lamps" if failures == 0 else "FAILED: street lamps (%d)" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _run() -> void:
	var level: Outdoor = game.level
	check(level.lamp_spots.size() >= 10, "the village has its street lamps (%d)" % level.lamp_spots.size())
	var turned := 0
	for spot: Dictionary in level.lamp_spots:
		var way: Vector3 = spot.walkway
		if way == Vector3.ZERO:
			continue
		var arm: Vector3 = spot.arm
		var dir := way.normalized()
		check(arm.dot(dir) > 0.99, "the lamp at %s reaches towards its walkway %s, not %s" % [spot.foot, dir, arm])
		if arm.dot(Vector3(0, 0, 1)) < 0.99:
			turned += 1
		if absf(way.x) + absf(way.z) == 1.0:
			var home := level.cell_to_world(level.world_to_cell(spot.foot))
			check((spot.foot - home).dot(dir) > 0.5, "the lamp at %s stands at the edge of the walkway beside it" % spot.foot)
	check(turned > 0, "some lamps turn their arm")
