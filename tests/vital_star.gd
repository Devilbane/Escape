extends SceneTree
## Headless test: the blood star of a vital blow (see VitalStrike._ring).
## - The star has STAR_POINTS spikes, each a triangle fan slice, spikes longer
##   than the dents between them.
## - It wobbles: the mesh differs from one moment to the next, yet stays
##   within the wobble bounds so it remains a readable star.
## - Shown at an impact, it adds one short-lived node that frees itself and
##   never outlives the effect.
## Run with: godot --headless --fixed-fps 60 -s tests/vital_star.gd

var failures := 0
var frames := 0
var level: Node3D


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	level = Node3D.new()
	root.add_child(level)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_test()
	return false


func _farthest(mesh: ArrayMesh) -> float:
	var far := 0.0
	for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		far = maxf(far, (v as Vector3).length())
	return far


func _test() -> void:
	var a := VitalStrike.star_mesh(0.0)
	var b := VitalStrike.star_mesh(0.05)
	var verts: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(verts.size() == VitalStrike.STAR_POINTS * 2 * 3, "one triangle per spike side")
	check(_farthest(a) > VitalStrike.STAR_INNER * 1.5, "the spikes reach well beyond the dents")
	check(_farthest(a) <= VitalStrike.STAR_OUTER * (1.0 + VitalStrike.STAR_WOBBLE) + 0.001, "the wobble stays bounded")
	check(a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "the star wobbles over time")
	check(VitalStrike.STAR_COLOR.r > 0.5 and VitalStrike.STAR_COLOR.g < 0.15 and VitalStrike.STAR_COLOR.b < 0.15, "the star is blood red")
	var before := level.get_child_count()
	VitalStrike._ring(level, Vector3.ZERO)
	check(level.get_child_count() == before + 1, "showing the star adds one node")
	await create_timer(VitalStrike.RING_TIME + 0.3, true, false, true).timeout
	check(level.get_child_count() == before, "the star frees itself")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
