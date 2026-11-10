extends SceneTree
## The village's windows go out one by one between WindowLights.OFF_FROM and
## OFF_TO, glass and ground light together; the clock reaches both materials.

var failed := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	var glass := WindowLights.glass_material(Color(1.0, 0.7, 0.36))
	var spill := WindowSpill.material(Color(1.0, 0.7, 0.36), 2.6)
	for mat: ShaderMaterial in [glass, spill]:
		check(mat.shader.code.contains("window_lit"), "a material knows which windows are lit")
		check(mat.shader.code.contains("UV2 + MODEL_MATRIX"), "a material finds its window's place")
		mat.set_shader_parameter("hour", 23.0)
		check(is_equal_approx(float(mat.get_shader_parameter("hour")), 23.0), "the clock reaches the material")
	check(WindowLights.OFF_TO + WindowLights.FADE <= 23.0, "every window is dark by 23:00")
	check(WindowLights.OFF_FROM < WindowLights.OFF_TO, "windows go out over a stretch of time")
	check(WindowLights.key(Vector3(1, 2, 3)) == WindowLights.key(Vector3(1, 2, 3)), "a pane's place is stable")
	check(WindowLights.key(Vector3(1, 2, 3)) != WindowLights.key(Vector3(1, 2, 4)), "panes differ by place")
	var house := VillageHouse.build(Vector2(8, 6), RandomNumberGenerator.new(), glass)
	WindowSpill.attach(house, spill)
	var found := false
	for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(s) == glass:
				found = (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size() > 0
	check(found, "the glass of a house carries its panes' places")
	if failed == 0:
		print("PASS: window lights")
	quit(1 if failed > 0 else 0)
