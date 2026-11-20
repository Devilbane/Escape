extends SceneTree
## Headless test for the climbing rules (see Climbing).
## Run with: godot --headless -s tests/climbing.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	check(Climbing.can_climb(HouseSketch.DEPTH, Climbing.MIN_LEVEL), "a level 1 hero can climb out of a cellar pit")
	check(Climbing.seconds(2.6, 10) < Climbing.seconds(2.6, 1), "a higher level climbs faster")
	check(Climbing.reach(10) > Climbing.reach(1), "a higher level reaches higher")
	check(Climbing.chance(1, 0) > 0.3 and Climbing.chance(1, 0) < 0.7, "level 1 needs a few tries")
	check(Climbing.chance(1, 3) >= 1.0, "a few slips in a row always lead to a success")
	check(Climbing.chance(20, 0) > Climbing.chance(1, 0), "skill makes a try likelier")
	print("climbing: ", "ok" if failures == 0 else "%d failed" % failures)
	quit(1 if failures > 0 else 0)
