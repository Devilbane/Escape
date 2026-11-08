extends SceneTree
## Headless test for the cave styles of walls and floors (WallThemes, header
## "walls:"): bone, rock, obsidian and crystal. Each style builds on a small map,
## its walls, floor tiles, rough floor and pillars wear the style's own
## material, and the walls fade like stone ones. Every shipped map names a
## style the game knows.
## Run with: godot --headless -s tests/wall_themes.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


const MAP := "name: Stiltest\nhint: x\nsecret: normal\nwalls: %s\n" + """##########
#P...f...#
#........#
#,,,.....#
#.......E#
##########
"""


## The materials on every mesh below `node`.
func _materials(node: Node) -> Array:
	var out := []
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		if mi.material_override != null:
			out.append(mi.material_override)
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null:
				out.append(m)
	return out


func _initialize() -> void:
	check(WallThemes.names().size() == 4, "%d styles, not 4" % WallThemes.names().size())
	DirAccess.make_dir_recursive_absolute("user://karten/")
	var seen := {}
	for style in WallThemes.names():
		for surface in [WallThemes.WALL, WallThemes.FLOOR, WallThemes.ROUGH_FLOOR]:
			var m := WallThemes.material(style, surface)
			check(m.shader == WallThemes.SHADER, "%s %d has no shader" % [style, surface])
			check(m.get_shader_parameter("albedo_tex") != null, "%s %d has no kit texture" % [style, surface])
		# Walls are darker than the floor, so the two stay apart.
		var wall: Color = WallThemes.material(style, WallThemes.WALL).get_shader_parameter("base_color")
		var floor_c: Color = WallThemes.material(style, WallThemes.FLOOR).get_shader_parameter("base_color")
		check(wall.get_luminance() < floor_c.get_luminance(), "%s: the walls are not darker than the floor" % style)
		var path := "user://karten/_test_walls_%s.txt" % style
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(MAP % style)
		f.close()
		var level := Level.new()
		level.load_from_file(path)
		level.playtest = true
		root.add_child(level)
		level.build()
		check(level.wall_style == style, "%s: header not read" % style)
		var walls := 0
		var floors := 0
		for m in _materials(level):
			if m is ShaderMaterial and (m as ShaderMaterial).shader == WallThemes.SHADER:
				check(m.get_shader_parameter("style") == WallThemes.STYLES[style].id, "%s: wrong style id" % style)
				if m.get_shader_parameter("surface") == WallThemes.WALL:
					walls += 1
				else:
					floors += 1
				seen[m] = true
		check(walls > 0, "%s: no walls in the style" % style)
		check(floors > 0, "%s: no floors in the style" % style)
		check(level._near_walls.size() > 0, "%s: no near walls to fade" % style)
		var fadeable := WallFade._fadeable(level._near_walls._pieces[0].node)
		check(fadeable.any(func(e): return e.stone), "%s: the walls do not fade" % style)
		# Lights and decor of the style: wall torch, brazier, candelabra.
		var holder := Node3D.new()
		level.add_child(holder)
		var made := CaveLights.wall_torch(style, holder)
		check(made.flame != null and holder.get_child_count() > 2, "%s: the wall torch is empty" % style)
		var lamp := OmniLight3D.new()
		holder.add_child(lamp)
		var torch := {"flame": made.flame, "glow": made.glow, "light": lamp, "on": true}
		level.set_torch(torch, false)
		check(not made.flame.visible, "%s: the torch does not go out" % style)
		level.set_torch(torch, true)
		check(made.flame.visible, "%s: the torch does not burn again" % style)
		check(CaveLights.brazier(style, holder, Vector3.ZERO) != null, "%s: no brazier" % style)
		check(CaveLights.candelabra(style, holder, Vector3.ZERO, 0.0).get_child_count() > 8, "%s: no candelabra" % style)
		check(CaveLights.energy(style, 3.4) > 0.0, "%s: no light" % style)
		var relief := []
		if style == "bone":
			relief = [WallShapes.skull_mesh(), WallShapes.bone_mesh()]
		else:
			for v in WallShapes.VARIANTS:
				relief.append(WallShapes.shard_mesh(style, v))
		var shards := level.find_children("*", "MeshInstance3D", true, false).filter(func(mi): return mi.mesh in relief).size()
		check(shards > 0, "%s: no relief (shards, skulls, bones) on the walls" % style)
		check((relief[0] as ArrayMesh).get_surface_count() == 1, "%s: the relief has no surface" % style)
		level.queue_free()
	# Three variants of each style: the header names one or mixes all three.
	check(WallThemes.parse("crystal").variant == -1, "a plain style mixes the variants")
	check(WallThemes.parse("crystal 2").variant == 1 and WallThemes.parse("crystal 2").style == "crystal", "'crystal 2' is not variant 2")
	check(WallThemes.parse("bone 9").variant == 2, "variant 9 is not held to 3")
	for style in WallThemes.names():
		var plain_mat := WallThemes.material(style, WallThemes.WALL)
		for v in 3:
			var one := WallThemes.material(style, WallThemes.WALL, v)
			check(one.get_shader_parameter("variant") == v, "%s: variant %d not set" % [style, v])
		check(plain_mat.get_shader_parameter("base_b") != plain_mat.get_shader_parameter("base_color"), "%s: the variants look alike" % style)
		var dif: Color = plain_mat.get_shader_parameter("base_b")
		var org: Color = plain_mat.get_shader_parameter("base_color")
		check(absf(dif.get_luminance() - org.get_luminance()) < 0.3 * maxf(org.get_luminance(), 0.1) + 0.05, "%s: variant b is too far from the first (it would show a seam)" % style)
	# A plain map keeps the stone.
	var plain := Level.new()
	check(plain.wall_style == "", "a plain map has a style")
	plain.free()
	# Every shipped map names a known style.
	for file in DirAccess.get_files_at("res://levels/"):
		if not file.ends_with(".txt"):
			continue
		var map := LevelMap.load_file("res://levels/" + file)
		var style := ""
		for h in map.headers:
			if h[0] == "walls":
				style = WallThemes.parse(h[1]).style
		check(style == "" or WallThemes.known(style), "%s: unknown walls style '%s'" % [file, style])
	print("wall_themes: ", "ok" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
