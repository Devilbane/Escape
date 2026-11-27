extends SceneTree
## The special spots of the climbing wall (tar, edelweiss, door): their ingredients exist, each spot builds a textured 3D scene,
## the door's target survives saving, and the sample wall has them on holds the climber can reach.
## Run: godot --headless -s tests/wall_spots.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for kind in ["tar", "edelweiss", "door", "secret"]:
		check(WallMap.MARKERS.has(kind), "%s is a marker" % kind)
		var spot := WallSpots.build(kind, 7)
		check(spot != null and spot.get_child_count() > (1 if kind == "secret" else 3), "%s builds a scene with parts" % kind)
		if kind == "secret" and spot != null:
			var slab := spot.get_node_or_null("Pivot/Slab") as Node3D
			check(slab != null, "the hidden door is a slab of rock on a pivot")
			check(bool(WallMap.MARKERS.secret.get("hidden", false)), "the hidden door has no sign")
			spot.free()
			continue
		if spot != null:
			var textured := 0
			for c in spot.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
					textured += 1
			check(textured == spot.get_child_count(), "every part of %s is a mesh" % kind)
			spot.free()
	for kind in WallSpots.GATHER:
		var id: String = WallSpots.GATHER[kind].id
		check(Crafting.INGREDIENTS.has(id), "ingredient %s of %s exists" % [id, kind])
		check(int(WallSpots.GATHER[kind].count) >= 1, "%s gives at least one" % kind)
	var hidden := WallBuild.new(WallMap.load_file("res://walls/sample_three_paths.txt")).secret_mesh(9, 2)
	check(hidden != null and hidden.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null, "the hidden door is made of the wall's own weathered stones")
	check(WallSpots.build("camp", 1) == null, "a kind without a scene gives none")
	var wall := WallMap.load_file("res://walls/sample_three_paths.txt")
	var found := {}
	for cell in wall.markers:
		var kind: String = wall.markers[cell]
		if kind in ["tar", "edelweiss", "door"]:
			found[kind] = true
			check(wall.has_hold(cell.x, cell.y), "%s at %s is on a hold" % [kind, cell])
	check(found.size() == 3, "the sample wall has tar, edelweiss and a door")
	check(not WallPlacements.door_of(wall).is_empty(), "the sample wall's door leads somewhere")
	# Every rest place has a ledge of the wall's own stones, three squares wide; a wall without a camp has none.
	var camps: Array[Vector2i] = []
	for cell in wall.markers:
		if wall.markers[cell] == "camp":
			camps.append(cell)
	check(not camps.is_empty(), "the sample wall has rest places")
	var builder := WallBuild.new(wall)
	var ledges := builder.camp_mesh()
	check(ledges != null and ledges.get_aabb().size.x >= WallBuild.CAMP_LEDGE_WIDTH, "the rest places have a ledge as wide as three squares")
	for cell in camps:
		var spot := WallBuild.foot_spot(wall, cell.x, cell.y)
		var box := ledges.get_aabb()
		check(box.position.x <= spot.x - WallBuild.CAMP_LEDGE_WIDTH * 0.5 + 0.4 or camps.size() > 1, "the ledge reaches 1.5 squares left of the feet")
	var bare := WallMap.parse(wall.to_text())
	for cell in camps:
		bare.set_marker(cell.x, cell.y, "")
	check(WallBuild.new(bare).camp_mesh() == null, "no rest place, no ledge")
	var again := WallMap.parse(wall.to_text())
	check(again.door == wall.door and again.markers.size() == wall.markers.size(), "the door and the markers survive saving")
	print("PASS" if failures == 0 else "FAILED %d" % failures)
	quit(1 if failures > 0 else 0)
