extends SceneTree
## Headless test: townsfolk footsteps (TownsfolkSteps).
## - Quieter than the hero's own walking steps, and a run louder than a stroll.
## - Every ground gives a step sound that exists; stone and wood differ.
## - Far from the camera nothing is heard, and a crowd is capped per moment.
## Run with: godot --headless -s tests/townsfolk_steps.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	check(TownsfolkSteps.WALK_DB < -17.0, "a townsperson's stroll is quieter than the hero's walk")
	check(TownsfolkSteps.RUN_DB > TownsfolkSteps.WALK_DB, "a run is louder than a stroll")
	check(TownsfolkSteps.STRIDE_RUN > TownsfolkSteps.STRIDE_WALK, "a run strides further than a stroll")
	for kind: String in Surfaces.PACE:
		if kind == Surfaces.PUDDLE:
			continue
		var s := TownsfolkSteps.sound_at(null, Vector3.ZERO, false)
		check(s[0] is String and not String(s[0]).is_empty(), "a step sound exists")
		var sound := Surfaces.step_sound(kind)
		check(sound.begins_with("step_"), "ground %s gives a step sound (%s)" % [kind, sound])
	check(Surfaces.step_sound(Surfaces.WOOD).begins_with("step_wood_"), "planks knock")
	check(Surfaces.step_sound(Surfaces.GRASS).begins_with("step_grass_"), "grass swishes")
	var cam := Vector3.ZERO
	check(not TownsfolkSteps.allowed(cam, Vector3(TownsfolkSteps.HEARD_FROM + 1.0, 0, 0), 1.0), "far steps are not played")
	var heard := 0
	for i in 20:
		if TownsfolkSteps.allowed(cam, Vector3(5, 0, 0), 10.0):
			heard += 1
	check(heard == TownsfolkSteps.MAX_PER_WINDOW, "a crowd is capped (%d heard)" % heard)
	check(TownsfolkSteps.allowed(cam, Vector3(5, 0, 0), 10.0 + TownsfolkSteps.STEP_WINDOW + 0.01), "the cap lifts in the next window")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
