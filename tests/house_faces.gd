extends SceneTree
## Headless test for the village houses (see VillageHouse): every face of a
## house is wound so that Godot draws its outside (front faces run clockwise,
## seen from the side their normal points to). Wound the other way, the
## camera saw the far insides of every beam and wall instead: the houses
## looked grey and black, the door step sank into the grass, and the insides
## flickered through each other where they met (the bottom of the upper floor
## through the beam under it, the bottom of the step through the ground).
## Run with: godot --headless -s tests/house_faces.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var glass := StandardMaterial3D.new()
	for seed in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var room := Vector2(rng.randf_range(6.0, 9.0), rng.randf_range(6.0, 9.0))
		_check_house(VillageHouse.build(room, rng, glass), "house (seed %d)" % seed)
		_check_house(VillageHouse.build_narrow(Vector2(4.0, 7.0), seed + 1, rng, glass), "town house (seed %d)" % seed)
	print("PASS: house faces" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Counts the triangles whose winding shows their inside to the camera.
func _check_house(house: Node3D, what: String) -> void:
	var total := 0
	var inside_out := 0
	for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0, verts.size(), 3):
				var a := verts[i]
				var winding := (verts[i + 1] - a).cross(verts[i + 2] - a)
				if winding.length() < 1e-8:
					continue
				var normal := normals[i] + normals[i + 1] + normals[i + 2]
				total += 1
				# Clockwise seen from the front: the winding's cross product
				# points away from the side the face is seen from.
				if winding.dot(normal) > 0.0:
					inside_out += 1
	check(total > 0, "%s has no faces" % what)
	check(inside_out == 0, "%s: %d of %d faces show their inside" % [what, inside_out, total])
	house.free()
