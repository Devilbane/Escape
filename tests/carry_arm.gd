extends SceneTree
## Headless test: the arm that carries a torch or a lamp (CarryArm, HandLamp).
## - The arm reaches forward and rocks only a few degrees with the steps (twice a walk cycle).
## - A lamp hangs upright whichever way its bearer faces, at the bearer's scale.
## - Villagers are mixed: some carry a lamp and some a torch.
## Run with: godot --headless -s tests/carry_arm.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in 101:
		var a := CarryArm.angles(i / 100.0, CarryArm.ROCK_RUN)
		lo = Vector2(minf(lo.x, a.x), minf(lo.y, a.y))
		hi = Vector2(maxf(hi.x, a.x), maxf(hi.y, a.y))
	check(lo.x > CarryArm.REACH - 6.0 and hi.x < CarryArm.REACH + 6.0, "the raise only rocks a few degrees")
	check(lo.y > CarryArm.BEND - 6.0 and hi.y < CarryArm.BEND + 6.0, "the bend only rocks a few degrees")
	check(CarryArm.REACH > 75.0 and CarryArm.BEND < 25.0, "the arm reaches out nearly straight in front, the light well clear of the body")
	var still := CarryArm.angles(0.37, 0.0)
	check(is_equal_approx(still.x, CarryArm.REACH) and is_equal_approx(still.y, CarryArm.BEND), "no rock when standing")
	var steps := 0
	var prev := CarryArm.angles(0.0, 3.0).x - CarryArm.REACH
	for i in range(1, 201):
		var cur := CarryArm.angles(i / 200.0, 3.0).x - CarryArm.REACH
		if prev < 0.0 and cur >= 0.0:
			steps += 1
		prev = cur
	check(steps == 2, "two rocks in a cycle, one a step (%d)" % steps)
	check(CarryArm.carries_in("Walking_A") and CarryArm.carries_in("Idle") and not CarryArm.carries_in("Cheer"), "it carries in walks and idle only")
	for yaw in [0.0, 1.0, 2.5, -2.0]:
		var b := HandLamp.hanging(yaw, 1.2, 0.7)
		check(absf(b.y.normalized().y) > 0.99, "the lamp hangs upright (yaw %.1f)" % yaw)
		check(is_equal_approx(b.get_scale().x, 1.2), "the lamp keeps the bearer's scale")
	for yaw in [0.0, 1.7, -2.4]:
		var up := HandLamp.held_up(yaw, 1.0)
		check(up.y.normalized().y > 0.98, "a held torch keeps its flame up (yaw %.1f)" % yaw)
	var lamps := 0
	var torches := 0
	for role: String in Villager.ROLES:
		var v := Villager.new()
		v.role = role
		if v.carries_lamp():
			lamps += 1
		else:
			torches += 1
		v.free()
	check(lamps > 0 and torches > 0, "some villagers carry lamps, some torches (%d/%d)" % [lamps, torches])
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
