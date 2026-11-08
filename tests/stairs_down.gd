extends SceneTree
## Headless test for StairsDown: the stairs down are a flight of steps that
## get darker towards the bottom, not a flat black hole.
## Run with: godot --headless -s tests/stairs_down.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var last := -1.0
	for i in StairsDown.STEPS:
		var d := StairsDown.darkness(i, StairsDown.STEPS)
		check(d > last, "step %d is darker than the one above" % i)
		last = d
	check(StairsDown.darkness(0, StairsDown.STEPS) < 0.1, "the top step is lit")
	var holder := Node3D.new()
	root.add_child(holder)
	var flight := StairsDown.build(holder, Vector3.ZERO, 4.0, Vector3(1, 0, 0))
	check(flight.get_child_count() >= StairsDown.STEPS * 2, "every step has a tread and a riser")
	check(flight.get_parent() == holder, "the flight hangs in the parent")
	var tex := StairsDown.doorway_texture()
	check(tex != null and tex.get_height() > 0, "the doorway picture exists")
	if failures == 0:
		print("PASS: stairs down")
	else:
		print("FAILED: ", failures)
	quit(failures)
