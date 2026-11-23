extends SceneTree
## Checks the grass, flowers and mossy stones at the foot of the buildings (WallFoot): they grow
## along the foot of the walls and only there, never in front of a door or where the ground is not
## open (the temple's front gets a row of mossy stones); they follow the seasons (straw-coloured grass and fewer flowers in autumn, low grass and
## no flowers in winter, green again in spring); and they stay cheap: few batches, no shadows, not
## drawn from far away. In the village: every kind grows, no grass or flower on paving, nothing
## inside a building or before a door.
## Run with: godot --headless -s tests/wall_foot.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_village()
	return false


## A plain box house, 8 x 6 m, standing on the ground round the origin, door in the south.
func _box_house() -> void:
	var house := Node3D.new()
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 5, 6)
	walls.mesh = box
	walls.position = Vector3(0, 2.5, 0)
	house.add_child(walls)
	root.add_child(house)
	var tris := AgedStone.triangles(house)
	var door := Vector3(0, 0, 3.5)
	for look: String in WallFoot.LOOKS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var out := {}
		# The ground east of x = 3 is not open (paved, say); stones may lie there.
		var open := func(at: Vector3, stone: bool) -> bool: return stone or at.x < 3.0
		WallFoot.grow(tris, Vector3.ZERO, 0.0, [door], rng, out, open, look)
		var total := 0
		for kind: String in WallFoot.KINDS:
			for xf: Transform3D in out[kind].xforms:
				total += 1
				var p := xf.origin
				# Outside the walls, at most a reach (and a stone's half) out from them.
				var gap := maxf(absf(p.x) - 4.0, absf(p.z) - 3.0)
				var reach: float = WallFoot.LOOKS[look].reach
				check(gap > -0.05 and gap < reach + 0.5, "%s: %s at %s grows at the foot of a wall (%.2f m out)" % [look, kind, p, gap])
				check(absf(p.y) < 0.2, "%s: %s at %s stands on the ground" % [look, kind, p])
				check(Vector2(p.x - door.x, p.z - door.z).length() > WallFoot.DOOR_CLEAR - 0.6, "%s: %s at %s keeps clear of the door" % [look, kind, p])
				if kind != "stone":
					check(p.x < 3.0, "%s: %s at %s only on open ground" % [look, kind, p])
		check(total > 0, "%s: the box house grows a fringe" % look)
		if look == "overgrown":
			check(out.grass.xforms.size() > out.stone.xforms.size(), "overgrown: more grass than stones")
		if look == "mossy":
			check(out.stone.xforms.size() > out.flower.xforms.size(), "mossy: more stones than flowers")
	house.queue_free()


## A fringe with every kind, dressed for each season.
func _seasons() -> void:
	var grown := {}
	for kind: String in ["grass", "flower", "stone"]:
		grown[kind] = {"xforms": [], "colours": []}
		for i in 60:
			grown[kind].xforms.append(Transform3D(Basis(), Vector3(i * 0.3, 0, 0)))
			grown[kind].colours.append(WallFoot.GRASS[0] if kind == "grass" else WallFoot.FLOWER_COLOURS[i % 5])
	var node := WallFoot.node(grown)
	root.add_child(node)
	var spring := Weather.YEAR_DAYS - Weather.WINTER_DAYS + Weather.WINTER_DAYS + 1
	var summer := Weather.SPRING_DAYS + 2
	var autumn_start := Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS
	var autumn_end := autumn_start + IvySeasons.TURN_DAYS + 1
	var winter := Weather.YEAR_DAYS - Weather.WINTER_DAYS + 1
	WallFoot.apply(node, summer)
	check(_sum(node, "straw") == 0 and _sum(node, "shown") == 60, "summer: green grass, every flower")
	WallFoot.apply(node, autumn_start + 1)
	var straw_early := _sum(node, "straw")
	var flowers_early := _sum(node, "shown")
	WallFoot.apply(node, autumn_end)
	check(_sum(node, "straw") > straw_early and _sum(node, "straw") > 45, "autumn: the grass turns to straw day by day (%d, then %d of 60)" % [straw_early, _sum(node, "straw")])
	check(_sum(node, "shown") < flowers_early and _sum(node, "shown") < 25, "autumn: the flowers go day by day (%d, then %d of 60)" % [flowers_early, _sum(node, "shown")])
	WallFoot.apply(node, winter)
	check(_sum(node, "shown") == 0 and not _child(node, "Flower").visible, "winter: no flowers")
	check(_sum(node, "straw") == 60, "winter: all the grass is pale")
	WallFoot.bury(node, 1.0)
	check(not _child(node, "Grass").visible, "snow lies: the grass is buried")
	WallFoot.bury(node, 0.0)
	check(_child(node, "Grass").visible, "snow gone: the grass is back")
	WallFoot.apply(node, spring if Weather.is_spring(spring) else summer)
	check(_sum(node, "straw") == 0 and _sum(node, "shown") == 60, "spring: green grass and flowers again")
	for child in node.get_children():
		var mmi := child as MultiMeshInstance3D
		check(mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % mmi.name)
		check(mmi.visibility_range_end > 0.0, "%s is not drawn from far away" % mmi.name)
	node.queue_free()


func _sum(node: Node3D, meta: String) -> int:
	var n := 0
	for child in node.get_children():
		n += int(child.get_meta(meta, 0))
	return n


func _child(node: Node3D, prefix: String) -> Node3D:
	for child in node.get_children():
		if child.name.begins_with(prefix):
			return child
	return null


func _village() -> void:
	_box_house()
	_seasons()
	if game.state == game.State.TITLE:
		game._start_playing()
	for i in 10:
		await process_frame
	game.load_level(game._outdoor_index(), false)
	for i in 10:
		await process_frame
	var lvl: Outdoor = game.level
	check(lvl.wall_foot != null, "the village has a fringe at the foot of its buildings")
	if lvl.wall_foot != null:
		var counts := {}
		for child in lvl.wall_foot.get_children():
			var kind: String = child.get_meta("kind")
			for xf: Transform3D in child.get_meta("grown")[0]:
				counts[kind] = int(counts.get(kind, 0)) + 1
				var p := xf.origin
				if kind != "stone" and not lvl._in_forecourt(p):
					check(not lvl._paved_at(p), "no %s on paving at %s" % [kind, p])
				check(lvl._fringe_ground(p, true), "the %s at %s grows on open ground, outside every building" % [kind, p])
				for e: Dictionary in lvl._entrances:
					var d: Vector3 = e.door
					check(Vector2(d.x - p.x, d.z - p.z).length() > 0.5, "the %s at %s keeps clear of the door at %s" % [kind, p, d])
		for kind: String in WallFoot.KINDS:
			check(int(counts.get(kind, 0)) > 20, "the village grows %s at its walls' feet (%d)" % [kind, int(counts.get(kind, 0))])
			check(int(counts.get(kind, 0)) <= WallFoot.CAP, "at most %d of %s" % [WallFoot.CAP, kind])
		# Out in the country, the dragon's lair wears the wild look at the foot of its arch.
		if lvl.doors.has("E"):
			var near := 0
			for child in lvl.wall_foot.get_children():
				for xf: Transform3D in child.get_meta("grown")[0]:
					if xf.origin.distance_to(lvl.doors["E"]) < 8.0:
						near += 1
			check(near > 10, "the lair's entrance is overgrown at its foot (%d pieces)" % near)
		# The temple's wide front is lined with mossy stones, its steps kept free.
		if lvl.doors.has("s"):
			var stones := 0
			for child in lvl.wall_foot.get_children():
				if child.get_meta("kind") == "stone":
					for xf: Transform3D in child.get_meta("grown")[0]:
						if xf.origin.distance_to(lvl.doors["s"]) < 7.0:
							stones += 1
			check(stones > 10, "mossy stones lie along the temple's front (%d)" % stones)
		# Cheap: a batch per kind and stretch of village, not one per building.
		check(lvl.wall_foot.get_child_count() < 100, "the fringe is drawn in few batches (%d)" % lvl.wall_foot.get_child_count())
		print("fringe: %s in %d batches" % [counts, lvl.wall_foot.get_child_count()])
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: wall foot")
	quit(1 if failures > 0 else 0)
