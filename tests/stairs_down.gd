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
	# The flight runs away from the open floor, never along a wall.
	var lvl := Level.new()
	var rows: Array[String] = ["###", "#.#", "#>#", "###"]
	lvl.grid = rows
	lvl.height = 4
	check(lvl.stairs_down_dir(Vector2i(1, 2)) == Vector2(0, 1), "open floor to the north: the flight runs south, into the wall")
	var wide: Array[String] = ["######", "#.>..#", "######"]
	lvl.grid = wide
	lvl.height = 3
	check(lvl.stairs_down_dir(Vector2i(2, 1)) == Vector2(-1, 0), "the longer open side (east) wins: the flight runs west")
	lvl.free()
	# Every setting has a look of its own, and the wall style wins over the mine setting.
	check(StairsDown.look("", "") == StairsDown.LOOKS[""], "a plain dungeon gets the plain stone")
	check(StairsDown.look("crystal", "kristall") != StairsDown.look("rock", "kupfer"), "crystal and rock stairs differ")
	check(StairsDown.look("", "glut") == StairsDown.LOOKS["glut"], "a mine setting without a wall style gets its own look")
	check(StairsDown.look("bone", "uralt") == StairsDown.LOOKS["bone"], "the wall style wins over the mine setting")
	for name: String in StairsDown.LOOKS:
		var look: Dictionary = StairsDown.LOOKS[name]
		check(look.has_all(["stone", "bottom", "rim", "rough", "glow", "gloss"]), "look '%s' is complete" % name)
		var rough_holder := Node3D.new()
		root.add_child(rough_holder)
		var built := StairsDown.build(rough_holder, Vector3(3, 0, 5), 4.0, Vector3(0, 0, -1), look)
		check(built.get_child_count() >= StairsDown.STEPS * 2, "'%s' builds every step" % name)
		rough_holder.queue_free()
	for style: String in WallThemes.names():
		check(StairsDown.LOOKS.has(style), "every wall style (%s) has stairs of its own" % style)
	if failures == 0:
		print("PASS: stairs down")
	else:
		print("FAILED: ", failures)
	quit(failures)
