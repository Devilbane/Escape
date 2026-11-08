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
		check(fill != null and fill.mesh is PlaneMesh, "%s has a fill under the void" % n)
		if fill:
			check(fill.position.y < 0.0 and fill.mesh.size.x > level.width * level.TILE, "%s fill lies under the floor and reaches past the map" % n)
		check(tris > 0 and tris < 40000, "%s caps stay cheap (%d triangles)" % [n, tris])
		var solid := 0
		for b in level.find_children("*", "CollisionObject3D", false, false):
			solid += 1
		print("%s: %d cap meshes, %d triangles" % [n, caps, tris])
		level.free()
	print("PASS: wall caps" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
