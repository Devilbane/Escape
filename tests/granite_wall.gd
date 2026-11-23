extends SceneTree
## Headless test for the look of the village wall and its gate (see Granite, GateWood, RoundedBox):
## - the granite stones are hewn, rounded and chipped (many triangles, not a box), about the size of
##   the stonemason's block, closed and with outward normals, and the stone shapes differ;
## - the wall's stones and the gate posts use the granite shader, the gate's leaves are made of
##   several aged boards with their own grain plus merged iron fittings, not a flat box;
## - a hurt brick still swaps the shade (darker, greener) of its stones.
## Run with: godot --headless -s tests/granite_wall.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


## Whether every triangle faces away from the middle of the mesh and every normal is a unit vector.
func _closed_and_outward(mesh: ArrayMesh, middle: Vector3) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() % 3 != 0 or v.size() != n.size():
		return false
	for i in n.size():
		if absf(n[i].length() - 1.0) > 0.01 or n[i].dot(v[i] - middle) < -0.05:
			return false
	for t in range(0, idx.size(), 3):
		# Godot winds triangles clockwise as seen from the front.
		var face := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		var centre := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		if face.dot(centre - middle) > 0.0:
			return false
	return true


func _run() -> void:
	var middle := Vector3(0, StoneBlock.HEIGHT * 0.5, 0)
	var seen := {}
	for variant in Granite.VARIANTS:
		var mesh := Granite.block_mesh(variant)
		var box := mesh.get_aabb()
		check(mesh.surface_get_array_len(0) > 60, "granite %d has more than a box's corners" % variant)
		check(box.size.x > 1.45 and box.size.x < 1.6, "granite %d is a block long: %s" % [variant, box.size])
		check(box.size.y > 0.7 and box.size.y < 0.8, "granite %d is a block high" % variant)
		check(box.size.z > 0.7 and box.size.z < 0.8, "granite %d is a block thick" % variant)
		check(absf(box.position.y) < 0.03, "granite %d stands on the ground" % variant)
		check(_closed_and_outward(mesh, middle), "granite %d is closed, with outward normals" % variant)
		var arrays := mesh.surface_get_arrays(0)
		seen[arrays[Mesh.ARRAY_VERTEX][5]] = true
	check(seen.size() > 2, "the granite stones are not all alike")
	var wall := WallBrick.new()
	root.add_child(wall)
	check(wall._stones.size() == WallBrick.STONES.size(), "the wall has all its stones")
	for s in wall._stones:
		var mat := s.material_override as ShaderMaterial
		check(mat != null and mat.shader == Granite.SHADER, "a wall stone is granite")
	var before := wall._stones[0].material_override
	wall.hp = 400
	wall._refresh()
	check(wall._stones[0].material_override != before, "a hurt stone changes its shade")
	var gate := WallBrick.new()
	gate.gate = true
	gate.shut = true
	root.add_child(gate)
	check(gate._leaves.size() == 2, "a gate has two leaves")
	for leaf in gate._leaves:
		var boards := 0
		var iron := 0
		for c in leaf.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			check(not (mi.mesh is BoxMesh), "no flat box in a leaf")
			if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader == GateWood.SHADER:
				boards += 1
			elif mi.material_override is StandardMaterial3D:
				iron += 1
		check(boards >= GateWood.PLANKS, "a leaf is made of several boards (%d)" % boards)
		check(iron == 1, "a leaf has its iron fittings in one mesh")
	for s in gate._stones:
		check((s.material_override as ShaderMaterial).shader == Granite.SHADER, "a gate post is granite")
	var iron_mesh := GateWood.iron_mesh(1.0, WallBrick.HINGE, WallBrick.HINGE / GateWood.PLANKS)
	check(iron_mesh.surface_get_array_len(0) > 200, "the iron has straps, hinge eyes and nails")
	if failures == 0:
		print("PASS: granite wall")
	quit(1 if failures > 0 else 0)
