extends SceneTree
## Weavers' Lane's lit windows show a curtain and now and then a figure behind
## the glass, and light up one by one in the evening.

var failed := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	var life := WindowLife.material(Color(1.0, 0.7, 0.36))
	check(life.shader.code.contains("window_lit"), "life only shows in lit windows")
	check(life.shader.code.contains("curtain_chance"), "curtains are in the shader")
	check(life.shader.code.contains("figure_chance"), "figures are in the shader")
	check(WindowLife.FIGURE_CHANCE < WindowLife.CURTAIN_CHANCE, "figures are rarer than curtains")
	check(WindowLife.CURTAIN_CHANCE + WindowLife.FIGURE_CHANCE < 0.5, "most cycles hold no event")
	check(WindowLights.ON_FROM < WindowLights.ON_TO, "windows light up over a stretch of time")
	check(WindowLights.ON_TO < WindowLights.OFF_TO, "the last window lights before the last one goes out")
	var glass := WindowLights.glass_material(Color(1.0, 0.7, 0.36))
	var house := VillageHouse.build_narrow(Vector2(4, 8), 1, RandomNumberGenerator.new(), glass)
	WindowLife.attach(house, life)
	var quad: MeshInstance3D = house.get_node_or_null("WindowLife")
	check(quad != null, "a town house gets its window life")
	if quad != null:
		var panes: Array = house.get_meta("windows")
		check(quad.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == panes.size() * 6, "one quad per window")
	if failed == 0:
		print("PASS: window life")
	quit(1 if failed > 0 else 0)
