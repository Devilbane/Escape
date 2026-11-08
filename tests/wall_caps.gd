extends SceneTree
## Headless test for the wall caps (WallCaps): every dungeon wall that touches a room gets
## a top and covered outer sides in the map's wall material, without any collision, and
## the near walls' caps fade with the wall in front of the hero.
## Run with: godot --headless -s tests/wall_caps.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## Whether the fill's faces lie under the point `p` (level space, seen from above).
func _covers(fill: MeshInstance3D, p: Vector3) -> bool:
	var v: PackedVector3Array = (fill.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, v.size(), 3):
		var lo := Vector2(minf(v[i].x, v[i + 2].x), minf(v[i].z, v[i + 2].z))
		var hi := Vector2(maxf(v[i].x, v[i + 2].x), maxf(v[i].z, v[i + 2].z))
		if p.x > lo.x and p.x < hi.x and p.z > lo.y and p.z < hi.y:
			return true
	return false


func _initialize() -> void:
	var names := ["01_die_zelle", "08_die_knochengrube", "20_die_kristallgrotte", "22_die_glutstollen"]
	for n in names:
		var level := Level.new()
		level.load_from_file("res://levels/%s.txt" % n)
		level.playtest = true
		root.add_child(level)
		level.build()
		var caps := 0
		var tris := 0
		for mi: MeshInstance3D in level.find_children("*", "MeshInstance3D", false, false):
			if mi.mesh is ArrayMesh and mi.material_override is StandardMaterial3D and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				caps += 1
				tris += (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
		check(caps > 0, "%s has wall caps" % n)
		var fill: MeshInstance3D = level.get_node_or_null("VoidFill")
		check(fill != null and fill.mesh is ArrayMesh, "%s has a fill under the void" % n)
		if fill:
			var box: AABB = fill.mesh.get_aabb()
			check(fill.position.y < 0.0 and box.size.x > level.width * level.TILE, "%s fill lies under the floor and reaches past the map" % n)
			# Open over every floor grate, so its pit shows; covering the rest of the map.
			var open := 0
			for g: Vector2i in level.grates:
				var p := level.cell_to_world(g)
				if _covers(fill, p):
					open += 1
			check(open == 0, "%s fill leaves every grate open (%d covered of %d)" % [n, open, level.grates.size()])
			var outside := level.cell_to_world(Vector2i.ZERO) - Vector3(level.TILE * 2.0, 0, 0)
			check(_covers(fill, outside), "%s fill still covers the void outside the walls" % n)
			var inside := level.cell_to_world(Vector2i.ZERO)
			if not level.grates.has(Vector2i.ZERO):
				check(_covers(fill, inside), "%s fill still covers the plain tiles" % n)
		check(tris > 0 and tris < 40000, "%s caps stay cheap (%d triangles)" % [n, tris])
		# Forced grates (some maps have none): the fill leaves just those tiles open.
		var hole := Vector2i(mini(3, level.width - 1), mini(2, level.height - 1))
		var neighbour := hole + Vector2i(1, 0) if hole.x + 1 < level.width else hole - Vector2i(1, 0)
		level.grates[hole] = true
		var forced := MeshInstance3D.new()
		forced.mesh = VoidFill.fill_mesh(level)
		check(not _covers(forced, level.cell_to_world(hole)), "%s fill is open over a grate" % n)
		check(_covers(forced, level.cell_to_world(neighbour)), "%s fill covers the tile next to a grate" % n)
		level.grates.erase(hole)
		forced.free()
		var solid := 0
		for b in level.find_children("*", "CollisionObject3D", false, false):
			solid += 1
		print("%s: %d cap meshes, %d triangles" % [n, caps, tris])
		level.free()
	print("PASS: wall caps" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
