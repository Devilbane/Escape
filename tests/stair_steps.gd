extends SceneTree
## Headless test: the footsteps on wooden stairs (StairSteps).
## - Every step sound up and down exists, the two ways differ, and no sound comes twice in a row.
## - A flight's steps end before the screen goes dark on the town-house stairs, and down is quicker.
## - On built stairs (HouseFloors) walking along the flight is "up" for stairs up and "down" for the
##   stairs into a cellar, the other way round when walking back; standing still or off the stairs
##   gives no stair step.
## Run with: godot --headless -s tests/stair_steps.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for way in ["up", "down"]:
		for k in StairSteps.SOUNDS:
			var path := "res://assets/sounds/stair_%s_%d.wav" % [way, k]
			check(ResourceLoader.exists(path), "%s exists" % path)
	check(StairSteps.sound(true).begins_with("stair_up_"), "a step up sounds like going up")
	check(StairSteps.sound(false).begins_with("stair_down_"), "a step down sounds like going down")
	var last := ""
	for i in 40:
		var s := StairSteps.sound(true)
		check(s != last, "no step up repeats right away (%s)" % s)
		last = s
	check(StairSteps.UP_TIMES.size() >= 2 and StairSteps.DOWN_TIMES.size() >= 2, "a flight is several steps")
	check(StairSteps.UP_TIMES.back() < 0.45 and StairSteps.DOWN_TIMES.back() < 0.45, "the steps end before the fade")
	check(StairSteps.DOWN_TIMES.back() < StairSteps.UP_TIMES.back(), "going down is quicker than going up")
	check(StairSteps.STEP_DB > -14.0, "a hollow stair is a touch louder than a floor")

	# Built stairs: a flight up leading east from lattice cell (0, 0), and stairs down into a
	# cellar leading south from (5, 0).
	var floors := HouseFloors.new()
	for i in 2:
		floors._nodes[Vector3i(i, 0, HouseFloors.UPPER)] = {"y": 0.0, "step": Vector2i(1, 0), "index": i, "rise": HouseSketch.STOREY_HEIGHT}
		floors._nodes[Vector3i(5, i, HouseFloors.CELLAR)] = {"y": 0.0, "step": Vector2i(0, 1), "index": i, "rise": -HouseSketch.DEPTH}
	floors._nodes[Vector3i(3, 0, HouseFloors.GROUND)] = {"y": 0.0}
	var up_spot := HouseFloors.centre(Vector2i(0, 0)) + Vector3(0, 0.8, 0)
	check(StairSteps.on_stairs(floors, up_spot, Vector3(2, 0, 0)) == 1, "walking along a flight up climbs")
	check(StairSteps.on_stairs(floors, up_spot, Vector3(-2, 0, 0)) == -1, "walking back down a flight up descends")
	check(StairSteps.on_stairs(floors, up_spot, Vector3.ZERO) == 0, "standing still on the stairs makes no step")
	var down_spot := HouseFloors.centre(Vector2i(5, 1)) + Vector3(0, -1.9, 0)
	check(StairSteps.on_stairs(floors, down_spot, Vector3(0, 0, 2)) == -1, "walking along cellar stairs descends")
	check(StairSteps.on_stairs(floors, down_spot, Vector3(0, 0, -2)) == 1, "walking back out of a cellar climbs")
	check(StairSteps.on_stairs(floors, HouseFloors.centre(Vector2i(3, 0)), Vector3(2, 0, 0)) == 0, "a flat floor is no stairs")
	check(StairSteps.on_stairs(null, up_spot, Vector3(2, 0, 0)) == 0, "no houses, no stairs")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
