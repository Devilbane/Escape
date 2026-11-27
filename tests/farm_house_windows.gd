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
	var layers := 0
	for s in front.mesh.get_surface_count():
		var mat := front.mesh.surface_get_material(s)
		if mat == VillageHouse.curtain_cloth():
			curtains = s
		elif mat is StandardMaterial3D and (mat as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			layers += 1
	check(curtains >= 0, "the walk-in front has curtains")
	# No see-through layer over the curtains: it flickered against them and showed as a white film.
	check(layers == 0, "no glass layer over the curtains (%d see-through surfaces)" % layers)
	# The shutters are hinged leaves that swing shut at night (see WindowLights.SHUTTER_SHADER).
	var leaves := 0
	for s in front.mesh.get_surface_count():
		if front.mesh.surface_get_material(s) == VillageHouse.shutters():
			leaves += (front.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	check(leaves > 0, "the windows have swinging shutters")
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
