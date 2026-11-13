extends SceneTree
## Headless test for the coloured light the temple's windows throw outside (see ChapelSpill).
## Run with: godot --headless -s tests/chapel_spill.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	var mesh := ChapelSpill.build_mesh()
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(verts.size() == ChapelSpill.WINDOWS.size() * ChapelSpill.COLOURS.size() * 6, "every window gets one pool per colour")
	for v in verts:
		check(v.y > 0.0 and v.y < 0.5, "pools lie on the ground")
	var mat := ChapelSpill.material(2.6)
	check(mat.shader.code.contains("fog_disabled"), "pools stay visible in fog")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
