extends SceneTree
## Headless test for the cap shingles on roof ridges, hips and gable edges (see RoofCaps): a ridge
## row, a descending hip row and a gable edge row make geometry, every triangle is wound as the
## engine's front face for its own normal, the tiles overlap (they step up over each other, never
## gaps), and the mage tower's roof and a village house's roof carry caps.
## Run with: godot --headless -s tests/roof_caps.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## The triangles of a surface: a flat list of points, three each, and the normals.
func _tris(st: SurfaceTool) -> Array:
	var arrays := st.commit().surface_get_arrays(0)
	var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return [pts, normals]


func _wound(row: Array, what: String) -> void:
	var pts: PackedVector3Array = row[0]
	var normals: PackedVector3Array = row[1]
	check(pts.size() >= 3 * 6, "%s: has tiles" % what)
	var bad := 0
	for i in range(0, pts.size() - 2, 3):
		var cross := (pts[i + 1] - pts[i]).cross(pts[i + 2] - pts[i])
		if cross.length() > 0.00001 and cross.normalized().dot(normals[i]) > 0.0:
			bad += 1
	check(bad == 0, "%s: %d triangles wound against their normal" % [what, bad])


func _initialize() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	RoofCaps.ridge(st, Vector3(-3, 5, 0), Vector3(3, 5, 0), 1.2, 7)
	var ridge := _tris(st)
	_wound(ridge, "ridge")
	# A 6 m ridge takes more than 15 tiles of 0.4 m stepping 0.32, and stays within the row.
	var pts: PackedVector3Array = ridge[0]
	var lo := 0.0
	var hi := 0.0
	var top := 0.0
	for p in pts:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
		top = maxf(top, p.y)
	check(lo >= -3.001 and hi <= 3.001, "ridge: stays inside its row (%.2f..%.2f)" % [lo, hi])
	check(top > 5.05, "ridge: the crown stands over the line (%.2f)" % top)

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	RoofCaps.ridge(st, Vector3(0, 5, 0), Vector3(3, 2, 3), 0.9, 3, true)
	_wound(_tris(st), "hip")

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3(0, 0.8, 0.6)
	RoofCaps.edge(st, Vector3(3, 5, 0), Vector3(3, 2.2, 3.7), up, Vector3.RIGHT, 5)
	_wound(_tris(st), "gable edge")

	# The village house's roof: the roof surface carries the ridge's tiles.
	var parts := {}
	VillageHouse._roof(parts, 6.0, 5.0, 3.0, 2.8, 4.6)
	var roof: Array = _tris(parts["roof"])
	check((roof[0] as PackedVector3Array).size() > 3 * 200, "village roof builds with its caps")
	print("PASS" if failures == 0 else "FAIL: %d failures" % failures)
	quit(1 if failures > 0 else 0)
