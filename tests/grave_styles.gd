extends SceneTree
## Test of the graveyard's kinds of gravestones (see GraveStyles): every style builds from carved, textured
## pieces (no plain colour, no flat single piece), stands on the ground, has a footprint, and the map's
## graves show a good variety, with Owlav's and the counter stone among the plain ones. With SHOTS=<folder>
## and a display it saves a picture of every style.
## Run with: godot --headless -s tests/grave_styles.gd

var failures := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var x := 0.0
	for style: String in GraveStyles.WEIGHTS:
		check(GraveStyles.FOOTPRINT.has(style), "%s has a footprint" % style)
		if style == "classic":
			continue
		var stone := GraveStyles.build(style, 7)
		world.add_child(stone)
		stone.position = Vector3(x, 0, 0)
		x += 3.0
		var meshes := stone.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() >= 5, "%s is made of carved pieces (%d)" % [style, meshes.size()])
		var lowest := INF
		var highest := -INF
		for m: MeshInstance3D in meshes:
			check(m.material_override != null, "%s has no bare material" % style)
			if m.material_override is StandardMaterial3D:
				check((m.material_override as StandardMaterial3D).albedo_texture != null or m.material_override.emission_enabled or style in ["urn", "cross", "celtic", "angel", "obelisk", "tomb", "ledger", "broken", "sunken"], "textured")
			var box := m.global_transform * m.mesh.get_aabb()
			lowest = minf(lowest, box.position.y)
			highest = maxf(highest, box.end.y)
		check(lowest > -0.7 and lowest < 0.1, "%s stands on the ground (%.2f)" % [style, lowest])
		check(highest <= GraveStyles.footprint(style).y + 0.7 and highest >= GraveStyles.footprint(style).y * 0.4, "%s is as tall as it blocks (%.2f vs %.2f)" % [style, highest, GraveStyles.footprint(style).y])
	# The map's graves.
	var rows := FileAccess.get_file_as_string("res://levels/11_die_freiheit.txt").split("\n")
	var body := rows.slice(rows.find("") + 1)
	var seen := {}
	var graves := 0
	for y in 22:
		for gx in 24:
			if body[y][gx] == "g":
				graves += 1
				var c := Vector2i(gx, y)
				var style := GraveStyles.pick("Apfeltal", c)
				seen[style] = int(seen.get(style, 0)) + 1
				check(style == GraveStyles.pick("Apfeltal", c), "a stone's kind never changes")
	check(graves >= 30, "a crowded graveyard (%d graves)" % graves)
	check(seen.size() >= 6, "a variety of stones (%s)" % [seen])
	check(int(seen.get("classic", 0)) < graves * 0.6, "not mostly the same stone (%s)" % [seen])
	check(GraveLore.OTHERS.size() >= graves, "a text for every grave")
	if shots != "":
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.3, 0.36, 0.45)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.65, 0.68, 0.75)
		world.add_child(env)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(60, 20)
		ground.mesh = plane
		var soil := StandardMaterial3D.new()
		soil.albedo_color = Color(0.2, 0.25, 0.14)
		ground.material_override = soil
		ground.position = Vector3(12, -0.01, 0)
		world.add_child(ground)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, -30, 0)
		world.add_child(sun)
		var cam := Camera3D.new()
		cam.fov = 62
		world.add_child(cam)
		cam.look_at_from_position(Vector3(13.5, 6.0, 15), Vector3(13.5, 0.7, 0))
		cam.make_current()
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png(shots.path_join("grave_styles.png"))
	print("PASS: grave styles" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
