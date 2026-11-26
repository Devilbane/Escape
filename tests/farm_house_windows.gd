extends SceneTree
## The farm houses' windows: the walk-in houses hang curtains inside their clear panes, clear of the glass, and
## their door is locked while a farmer sleeps in them.

var failed := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	var glass := WindowLights.glass_material(Color(1.0, 0.7, 0.36))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var house := VillageHouse.build(Vector2(9, 9), rng, glass)
	root.add_child(house)
	var parts := VillageHouse.hollow(house, true)
	var front: MeshInstance3D = parts.front
	var curtains := -1
	var clear := -1
	for s in front.mesh.get_surface_count():
		var mat := front.mesh.surface_get_material(s)
		if mat == VillageHouse.curtain_cloth():
			curtains = s
		elif mat == VillageHouse.clear_glass():
			clear = s
	check(curtains >= 0 and clear >= 0, "the walk-in front has clear glass and curtains")
	if curtains >= 0 and clear >= 0:
		var cv: PackedVector3Array = front.mesh.surface_get_arrays(curtains)[Mesh.ARRAY_VERTEX]
		var gv: PackedVector3Array = front.mesh.surface_get_arrays(clear)[Mesh.ARRAY_VERTEX]
		# Every curtain hangs at least 3 cm from every pane of glass, so they never z-fight.
		var gap := 99.0
		for c in cv:
			for g in gv:
				if absf(c.y - g.y) < 0.01 and Vector2(c.x - g.x, c.z - g.z).length() < 0.3:
					gap = minf(gap, Vector2(c.x - g.x, c.z - g.z).length())
		check(gap >= 0.03, "the curtains hang clear of the glass")
	var walk_in := WalkIn.new(Node3D.new())
	var farmer := Villager.new()
	var rec := {"kind": "house", "block": Rect2i(Vector2i(43, 84), Vector2i(2, 2)), "beds": [{"by": farmer}]}
	check(not walk_in.farmer_asleep(rec), "the door is open while the farmer is up")
	farmer.bed_trip = {"step": "asleep"}
	check(walk_in.farmer_asleep(rec), "the door is locked while the farmer sleeps")
	rec.block = Rect2i(Vector2i(10, 20), Vector2i(2, 2))
	check(not walk_in.farmer_asleep(rec), "village houses are not locked this way")
	print("PASS: farm house windows" if failed == 0 else "FAILED: %d" % failed)
	quit(1 if failed else 0)
