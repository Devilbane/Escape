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
#P.......#
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
		level.queue_free()
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
				style = h[1]
		check(style == "" or WallThemes.known(style), "%s: unknown walls style '%s'" % [file, style])
	print("wall_themes: ", "ok" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
