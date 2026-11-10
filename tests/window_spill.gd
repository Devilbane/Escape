extends SceneTree
## Headless test for the light lit windows throw on the ground (see WindowSpill):
## a house gets one pool per window, in front of it, and the shader compiles.
## Run with: godot --headless -s tests/window_spill.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var glass := StandardMaterial3D.new()
	var house := VillageHouse.build(Vector2(8, 7), rng, glass)
	var panes: Array = house.get_meta("windows")
	var outs: Array = house.get_meta("window_outs")
	check(not panes.is_empty(), "the house has windows")
	check(panes.size() == outs.size(), "every window knows which way it faces")
	var mat := WindowSpill.material(Color(1.0, 0.7, 0.36), 2.6)
	WindowSpill.attach(house, mat)
	var spill := house.get_node_or_null("WindowSpill") as MeshInstance3D
	check(spill != null, "the house gets a spill mesh")
	if spill:
		var verts: PackedVector3Array = spill.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(verts.size() == panes.size() * 6, "one pool (two triangles) per window")
		for v in verts:
			check(v.y < 0.1 and v.y > 0.0, "pools lie on the ground")
		var first: Vector3 = panes[0]
		var out: Vector3 = outs[0]
		var mid := Vector3.ZERO
		for i in 6:
			mid += verts[i] / 6.0
		check((mid - first).dot(out) > 0.5, "the first pool lies in front of its window")
	check(WindowSpill.SHADER.contains("fog_disabled"), "pools ignore fog (an additive quad would show as a white band)")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
