extends SceneTree
## Headless test for flags and banners fluttering in the wind (see FlagWind):
## every model with cloth gets its cloth cut into narrow strips and a flutter
## material, while its pole, rod, iron and shield stay as they were; the
## village's flags flutter, and the wind follows the weather like the
## windmill's sails: a breeze when clear, stronger in rain, hardly any in fog
## and wild in a storm, with a soft draught down in the dungeon.
## Run with: godot --headless --fixed-fps 60 -s tests/flag_wind.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Flag wind test"
const MODELS := {
	"flag_red": "res://assets/village/flag_red.gltf",
	"flag_blue": "res://assets/village/flag_blue.gltf",
	"SM_RedFlag": "res://assets/kit/SM_RedFlag.fbx",
	"SM_BlueFlag": "res://assets/kit/SM_BlueFlag.fbx",
	"Banner": "res://assets/lair/Banner.fbx",
	"banner_shield_brown": "res://assets/dungeon/banner_shield_brown.glb",
}


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
	if frames < 5:
		return false
	_winds()
	_models()
	_village()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: flag wind")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _winds() -> void:
	var clear := FlagWind.wind_for(Weather.CLEAR)
	check(FlagWind.wind_for(Weather.RAIN).x > clear.x, "the rain blows harder than a clear day")
	check(FlagWind.wind_for(Weather.STORM).x > FlagWind.wind_for(Weather.RAIN).x, "a storm blows hardest")
	check(FlagWind.wind_for(Weather.STORM).y > clear.y, "in a storm the cloth flaps faster")
	check(FlagWind.wind_for(Weather.FOG).x < clear.x, "the fog's air is still")
	check(FlagWind.wind_for("") == FlagWind.DRAUGHT, "down in the dungeon a draught stirs")
	check(FlagWind.DRAUGHT.x < clear.x, "the draught is softer than a breeze")
	for kind in [Weather.CLEAR, Weather.RAIN, Weather.FOG, Weather.STORM]:
		check(FlagWind.WINDS.has(kind), "a wind for the weather " + kind)


## Every model with cloth, dressed as the game dresses it.
func _models() -> void:
	check(MODELS.size() == FlagWind.SHAPES.size(), "every model with cloth is tested")
	var level := Node3D.new()
	root.add_child(level)
	for model: String in MODELS:
		var node: Node3D = load(MODELS[model]).instantiate()
		level.add_child(node)
		var shape: Dictionary = FlagWind.SHAPES[model]
		var before := {}
		var meshes := node.find_children(shape.mesh, "MeshInstance3D", true, false)
		check(meshes.size() > 0, model + " has its cloth mesh")
		for mi: MeshInstance3D in meshes:
			before[mi] = mi.mesh
		FlagWind.attach(node, model, level)
		for mi: MeshInstance3D in meshes:
			var old: Mesh = before[mi]
			var cut: Mesh = mi.mesh
			check(cut != old and cut.get_surface_count() == old.get_surface_count(), model + ": the mesh is cut, all its parts kept")
			for s in cut.get_surface_count():
				var mat := mi.get_active_material(s) as ShaderMaterial
				var flutters := mat != null and float(mat.get_shader_parameter("flutter")) > 0.0
				if s in shape.surfaces:
					check(flutters, "%s: the cloth (part %d) flutters" % [model, s])
					var tris := _triangles(cut, s)
					check(tris > _triangles(old, s), "%s: the cloth is cut into more faces" % model)
					check(_longest_strip(cut, s, shape) <= FlagWind.STEP + 0.0001, "%s: no strip of cloth is too long to bend" % model)
				else:
					check(not flutters, "%s: part %d stays still" % [model, s])
					check(_triangles(cut, s) == _triangles(old, s), "%s: part %d is not cut" % [model, s])
		# A second copy shares the cut mesh and the materials.
		var twin: Node3D = load(MODELS[model]).instantiate()
		level.add_child(twin)
		FlagWind.attach(twin, model, level)
		var a: MeshInstance3D = meshes[0]
		var b: MeshInstance3D = twin.find_children(shape.mesh, "MeshInstance3D", true, false)[0]
		check(a.mesh == b.mesh, model + ": copies share the cut mesh")
		check(a.get_active_material(shape.surfaces[0]) == b.get_active_material(shape.surfaces[0]), model + ": copies share the material")
	check(level.get_node_or_null("FlagWind") != null, "the level gets one wind for its flags")
	check(level.find_children("FlagWind", "", false, false).size() == 1, "only one wind per level")
	level.free()


func _triangles(mesh: Mesh, s: int) -> int:
	var arrays := mesh.surface_get_arrays(s)
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
	return (index.size() if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3


## The longest stretch along the cloth that one edge of a face spans.
func _longest_strip(mesh: Mesh, s: int, shape: Dictionary) -> float:
	var arrays := mesh.surface_get_arrays(s)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var reach: Vector3 = shape.reach
	var along := func(p: Vector3) -> float: return clampf((p - shape.root).dot(reach) / reach.length_squared(), 0.0, 1.0)
	var longest := 0.0
	for f in range(0, index.size(), 3):
		for e in 3:
			var d := absf(along.call(verts[index[f + e]]) - along.call(verts[index[f + (e + 1) % 3]]))
			longest = maxf(longest, d)
	return longest


func _village() -> void:
	game.hero_name = HERO
	game.day_hour = 12.0
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	var flags := 0
	for mi: MeshInstance3D in level.find_children("flag_*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0) as ShaderMaterial
		if mat and float(mat.get_shader_parameter("flutter")) > 0.0:
			flags += 1
	check(flags >= 3, "the village's flags flutter (%d)" % flags)
	var wind: FlagWind = level.get_node_or_null("FlagWind")
	check(wind != null, "the village has its wind")
	if wind == null:
		return
	level.weather = Weather.CLEAR
	for i in 120:
		wind._process(0.5)
	check(wind.wind.distance_to(FlagWind.WINDS[Weather.CLEAR]) < 0.01, "under clear skies a breeze blows")
	var phase := wind.phase
	level.weather = Weather.STORM
	wind._process(0.1)
	check(wind.wind.x < FlagWind.WINDS[Weather.STORM].x * 0.5, "the storm's wind picks up gently, not at once")
	check(wind.phase > phase, "the waves keep running through the cloth")
	for i in 120:
		wind._process(0.5)
	check(wind.wind.distance_to(FlagWind.WINDS[Weather.STORM]) < 0.01, "in a storm the flags fly wild")
	var mat: ShaderMaterial = level.find_children("flag_*", "MeshInstance3D", true, false)[0].get_active_material(0)
	check(is_equal_approx(float(mat.get_shader_parameter("wind_strength")), wind.wind.x), "the flags are told the wind")
	level.weather = Weather.FOG
	for i in 120:
		wind._process(0.5)
	check(wind.wind.x < FlagWind.WINDS[Weather.CLEAR].x, "in the fog the flags hang almost still")
