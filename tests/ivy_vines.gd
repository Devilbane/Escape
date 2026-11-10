extends SceneTree
## Checks the village's ivy rules on a synthetic house (a box with a prism roof): every vine carries
## leaves, woody stems and at least one bunch of grapes, grapes are red or blue (both turn up),
## nothing grows in the doorway, and AgedStone.IVY_DENSITY really sets how many vines there are.
## Run with: godot --headless -s tests/ivy_vines.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _house() -> Node3D:
	var house := Node3D.new()
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 5, 6)
	walls.mesh = box
	walls.position = Vector3(0, 2.5, 0)
	house.add_child(walls)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(8.4, 2.5, 6.4)
	roof.mesh = prism
	roof.position = Vector3(0, 6.25, 0)
	house.add_child(roof)
	root.add_child(house)
	return house


func _grow(density: float, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tris := AgedStone.triangles(_house())
	var leaves := {"xforms": [], "colours": []}
	var door := Vector3(0, 0, 3.4)
	AgedStone.grow_ivy(tris, Vector3.ZERO, 0.0, [door], rng, leaves, 7, false, [], 0.0, 0.0, 1.0, false, 0, density)
	# The village always sweeps the doorways last (see Outdoor.build).
	AgedStone.clear_doors(leaves, [{"door": door, "out": Vector3.BACK}])
	return leaves


var ran := false


func _process(_delta: float) -> bool:
	if not ran:
		ran = true
		_run()
	return false


func _run() -> void:
	var door := Vector3(0, 0, 3.4)
	var reds := 0
	var blues := 0
	var vines := {1.0: 0, 2.0: 0}
	for density: float in vines:
		for seed_value in [1, 2, 3, 4]:
			var leaves := _grow(density, seed_value)
			var list: Array = leaves.get("vines", [])
			vines[density] += list.size()
			for v: Dictionary in list:
				check(v.leaves > 0 and v.stems > 0 and v.grapes > 0, "every vine has leaves, stems and a grape (%s)" % [v])
			check((leaves.get("grapes", []) as Array).size() == (leaves.get("grape_colours", []) as Array).size(), "one colour per bunch")
			for c: Color in leaves.get("grape_colours", []):
				if c.r > c.b:
					reds += 1
				else:
					blues += 1
			for x: Transform3D in leaves.xforms + leaves.get("grapes", []):
				var near := Vector2(x.origin.x - door.x, x.origin.z - door.z).length() < AgedStone.DOOR_SWEEP
				check(not (near and x.origin.y < AgedStone.DOOR_CLEAR.y), "the doorway stays clear (%s)" % [x.origin])
	check(vines[1.0] > 0, "density 1 grows vines")
	check(vines[2.0] > vines[1.0], "a higher IVY_DENSITY grows more vines (%d vs %d)" % [vines[2.0], vines[1.0]])
	check(reds > 0 and blues > 0, "grapes come in red and blue (%d red, %d blue)" % [reds, blues])
	check(_grow(0.0, 1).xforms.is_empty(), "density 0 grows no ivy")
	print("vines at density 1: %d, at density 2: %d; grapes: %d red, %d blue" % [vines[1.0], vines[2.0], reds, blues])
	print("PASS: ivy vines" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
