extends SceneTree
## Climbing wall: every hold a climber can hang from has a foot stone under it, so the feet never stand on air,
## and the body hangs close to the rock so the hands reach the hold. Run: godot --headless -s tests/wall_holds.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var wall := WallMap.load_file("res://walls/sample_three_paths.txt")
	var b := WallBuild.new(wall)
	var spots := 0
	for r in wall.height:
		for c in wall.width:
			if wall.has_hold(c, r) and WallBuild.foot_spot(wall, c, r).x >= 0.0:
				spots += 1
	check(spots > 0, "the sample wall has holds with feet off the ground")
	var mesh := b.foot_mesh()
	check(mesh != null, "foot stones are built")
	if mesh != null:
		# One stone per spot: every stone is the same mesh, so the vertex count is a multiple of the spot count.
		var verts := (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		check(verts > 0 and verts % spots == 0, "one foot stone per hold (%d vertices for %d spots)" % [verts, spots])
		# The stones stand out of the face far enough to carry the feet (the body hangs 0.4 m in front of the face).
		var aabb := mesh.get_aabb()
		check(aabb.size.z > 0.2, "foot stones jut out of the face (%.2f m)" % aabb.size.z)
	if failures == 0:
		print("PASS")
	quit(1 if failures > 0 else 0)
