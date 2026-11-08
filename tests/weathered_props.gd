extends SceneTree
## Headless test for the weathered props of the village (see WeatheredProps
## and VillageProps): the old KayKit props (barrels, crates, lumber, stone
## heaps, rocks, pumpkins, tents) wear the weathered material; the forge, the
## street lamps, the food pedestal and the workbenches are built of a few
## merged meshes, not a box per part; the lamps' panes glow at night only;
## and the Builder's faces point outwards.
## Run with: godot --headless --fixed-fps 60 -s tests/weathered_props.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _weathered(mi: MeshInstance3D) -> bool:
	var m := mi.material_override as ShaderMaterial
	return m != null and m.shader == WeatheredProps.SHADER


## The meshes standing within `reach` metres of `at` (on the ground plane).
func _meshes_near(lvl: Node3D, at: Vector3, reach: float) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in lvl.get_children():
		if child is MeshInstance3D and Vector2(child.position.x - at.x, child.position.z - at.z).length() <= reach:
			out.append(child)
	return out


func _run() -> void:
	_check_builder()
	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level

	# The KayKit props, wherever they stand, are weathered.
	var props := 0
	var plain := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		var model := mi.get_parent()
		while model and model != lvl and not WeatheredProps.MODELS.has(_model_name(model)):
			model = model.get_parent()
		if model == null or model == lvl:
			continue
		props += 1
		# The boulders at the dragon's lair wear the lair's old stone instead.
		var aged := mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader == AgedStone.SHADER
		# Flags keep their weathering inside the flutter materials of FlagWind (per surface).
		var fluttering := mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0) is ShaderMaterial
		if not _weathered(mi) and not aged and not fluttering:
			plain += 1
	check(props > 30, "the village has its barrels, crates, rocks and pumpkins (%d)" % props)
	check(plain == 0, "every old prop is weathered (%d still plain)" % plain)

	# The forge: a few meshes, mostly the one weathered mesh.
	var smith := {}
	for s in lvl.stations:
		if s.kind == "schmied":
			smith = s
	check(not smith.is_empty(), "Gorm stands at his forge")
	if not smith.is_empty():
		var forge_at: Vector3 = lvl.cell_to_world(smith.cell + Vector2i(-1, 0))
		var near := _meshes_near(lvl, forge_at, 1.9)
		var merged := near.filter(func(mi): return _weathered(mi) and (mi as MeshInstance3D).mesh.get_faces().size() > 900)
		check(merged.size() >= 1, "the forge is one weathered mesh of many parts")
		check(near.size() <= 6, "the forge draws in a few meshes (%d)" % near.size())

	# The workbenches: each bench with its tools is one weathered mesh.
	for s in lvl.stations:
		if s.kind != "werkbank":
			continue
		var near := _meshes_near(lvl, s.pos, 0.3)
		var merged := near.filter(func(mi): return _weathered(mi))
		check(merged.size() == 1, "the %s bench is one weathered mesh (%d)" % [s.craft, merged.size()])

	# The pedestal of hewn stone under the food basket.
	check(not lvl._basket.is_empty(), "the pedestal with the food basket stands")
	if not lvl._basket.is_empty():
		var top: Vector3 = lvl._basket.pos
		var pedestal := _meshes_near(lvl, Vector3(top.x, 0, top.z), 0.1).filter(func(mi): return _weathered(mi))
		check(pedestal.size() == 1, "the pedestal is one weathered mesh")
		if pedestal.size() == 1:
			var box: AABB = pedestal[0].mesh.get_aabb()
			check(absf(box.end.y - Outdoor.PEDESTAL_HEIGHT) < 0.05, "the pedestal's top is where the basket stands (%.2f)" % box.end.y)
		for mi: MeshInstance3D in (lvl._basket.food as Node3D).find_children("*", "MeshInstance3D", true, false):
			check(_weathered(mi), "the food is no longer waxy")

	# The street lamps: one weathered mesh each, panes that glow at night.
	check(not lvl._lamps.is_empty(), "the village has street lamps")
	if not lvl._lamps.is_empty():
		var lamp: Vector3 = lvl._lamps[0].position - Vector3(0, 2.6, 1.1)
		var post := _meshes_near(lvl, lamp, 0.05).filter(func(mi): return _weathered(mi))
		check(post.size() == 1, "a lamp is one weathered mesh")
		check(lvl._pane_mat != null and lvl._window_mats.has(lvl._pane_mat), "the lanterns' panes are lit with the windows")
		lvl.set_hour(23.0)
		check(lvl._pane_mat.emission_energy_multiplier > 1.0, "the panes glow at night")
		lvl.set_hour(12.0)
		check(lvl._pane_mat.emission_energy_multiplier < 0.1, "the panes are dark by day")

	if failures == 0:
		print("PASS: weathered_props")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## The model a placed KayKit node was loaded from, by its scene file.
func _model_name(node: Node) -> String:
	return node.scene_file_path.get_file().get_basename() if node.scene_file_path != "" else ""


## Every face the Builder lays points away from the middle of a box.
func _check_builder() -> void:
	var b := WeatheredProps.Builder.new()
	b.box(Vector3.ZERO, Vector3(1, 1, 1), Color.WHITE)
	b.cylinder(Vector3(3, 0, 0), 0.5, 0.3, 1.0, Color.WHITE)
	var holder := Node3D.new()
	var mi := b.finish(holder)
	var faces := mi.mesh.get_faces()
	var outward := 0
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var c: Vector3 = faces[i + 1]
		var d: Vector3 = faces[i + 2]
		var middle := Vector3(0, 0.5, 0) if a.x < 1.5 else Vector3(3, 0.5, 0)
		# Clockwise seen from outside: the right-hand normal points inwards.
		var n := (c - a).cross(d - a)
		if n.dot((a + c + d) / 3.0 - middle) < 0.0:
			outward += 1
	check(outward == faces.size() / 3, "the Builder's faces are wound to face outwards (%d of %d)" % [outward, faces.size() / 3])
	holder.free()
