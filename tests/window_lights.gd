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
	# The daily cycle of every window: shutters and curtains each have a fixed time of their own, drawn
	# independently, in the morning and in the evening; shut all night, open all day.
	var curtains_first := 0
	var shutters_first := 0
	var closes: Dictionary = {}
	for i in 40:
		var key := Vector2(3.0 + i * 1.7, 11.0 - i * 2.3)
		check(WindowLights.shutters_shut(key, 12.0) < 0.01 and WindowLights.curtains_shut(key, 12.0) < 0.01, "by day shutters and curtains stand open (%d)" % i)
		check(WindowLights.shutters_shut(key, 23.5) > 0.99 and WindowLights.curtains_shut(key, 23.5) > 0.99, "late in the evening both are shut (%d)" % i)
		check(WindowLights.shutters_shut(key, 3.0) > 0.99 and WindowLights.curtains_shut(key, 3.0) > 0.99, "both stay shut through the night (%d)" % i)
		check(WindowLights.shutters_shut(key, 8.5) < 0.01 and WindowLights.curtains_shut(key, 8.5) < 0.01, "both are open by 8:30 (%d)" % i)
		var curtains_at := -1.0
		var shutters_at := -1.0
		var h := 16.0
		while h < 22.0:
			if curtains_at < 0.0 and WindowLights.curtains_shut(key, h) > 0.5:
				curtains_at = h
			if shutters_at < 0.0 and WindowLights.shutters_shut(key, h) > 0.5:
				shutters_at = h
			h += 0.01
		check(curtains_at > 17.5 and shutters_at > 17.5, "both close in the evening (%d: %.2f, %.2f)" % [i, curtains_at, shutters_at])
		if curtains_at < shutters_at:
			curtains_first += 1
		else:
			shutters_first += 1
		closes[snappedf(shutters_at, 0.1)] = true
		# The same key gives the same times again: fixed, nothing random per day.
		check(is_equal_approx(WindowLights.sched(key), WindowLights.sched(key)) and WindowLights.sched(key) != WindowLights.sched_shutters(key), "the two draws differ (%d)" % i)
		var s_open := -1.0
		var c_open := -1.0
		h = 5.0
		while h < 9.0:
			if s_open < 0.0 and WindowLights.shutters_shut(key, h) < 0.5:
				s_open = h
			if c_open < 0.0 and WindowLights.curtains_shut(key, h) < 0.5:
				c_open = h
			h += 0.01
		check(s_open > 5.9 and c_open > 6.2, "both open in the morning (%d: %.2f, %.2f)" % [i, s_open, c_open])
	check(curtains_first > 5 and shutters_first > 5, "the order is not fixed: curtains first %d, shutters first %d" % [curtains_first, shutters_first])
	check(closes.size() > 8, "the shutters close at many different times (%d)" % closes.size())
	# The mage's tower: its windows close one after another, 0.5 s (0.01 h) apart, curtains first, then the
	# shutters; in the morning the shutters open first, then the curtains, in the same order.
	var key := Vector2(40.0, 40.0)
	for rank in range(1, 9):
		var c := _first(func(h: float) -> bool: return WindowLights.curtains_shut(key, h, rank) > 0.5, 18.0, 21.0)
		var c_next := _first(func(h: float) -> bool: return WindowLights.curtains_shut(key, h, rank + 1) > 0.5, 18.0, 21.0)
		var s := _first(func(h: float) -> bool: return WindowLights.shutters_shut(key, h, rank) > 0.5, 18.0, 21.0)
		check(c_next > c and c_next - c < 0.03, "magic curtain %d closes just before the next (%.3f, %.3f)" % [rank, c, c_next])
		check(s > c + 0.2, "the shutters of window %d close after the curtains (%.2f, %.2f)" % [rank, c, s])
		var so := _first(func(h: float) -> bool: return WindowLights.shutters_shut(key, h, rank) < 0.5, 5.0, 9.0)
		var co := _first(func(h: float) -> bool: return WindowLights.curtains_shut(key, h, rank) < 0.5, 5.0, 9.0)
		check(co > so, "in the morning the shutters of window %d open before its curtains (%.2f, %.2f)" % [rank, so, co])
	if failed == 0:
		print("PASS: window lights")
	quit(1 if failed > 0 else 0)


## The first hour from `from` to `to` (in steps of 0.002) at which `test` holds, or -1.
func _first(test: Callable, from: float, to: float) -> float:
	var h := from
	while h < to:
		if test.call(h):
			return h
		h += 0.002
	return -1.0
