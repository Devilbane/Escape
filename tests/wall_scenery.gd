extends SceneTree
## The surroundings of a climbing wall (see WallScenery) and its rain (see WallRain): every weather has a sky, three
## rings of mountains, a ground and rock piles at the wall's sides; a raindrop is a thin soft streak, never a fat bar.
## Run with: godot --headless -s tests/wall_scenery.gd

func _initialize() -> void:
	var fails := 0
	var wall := WallMap.load_file("res://walls/sample_three_paths.txt")
	for weather in WallWeather.ORDER:
		var node := WallScenery.build(wall, weather)
		for part in ["Ridge_far", "Ridge_mid", "Ridge_near", "Ground", "Flanks"]:
			if node.get_node_or_null(part) == null:
				fails += 1
				print("FAIL no ", part, " in the scenery of ", weather)
		if WallScenery.sky(weather) == null:
			fails += 1
			print("FAIL no sky for ", weather)
		node.free()
	var drop := WallRain.drop_mesh()
	var box := drop.get_aabb()
	if box.size.x > 0.2 or box.size.y < 0.3:
		fails += 1
		print("FAIL a raindrop is not a thin streak: ", box.size)
	if not drop.surface_get_material(0) is ShaderMaterial:
		fails += 1
		print("FAIL a raindrop has no soft-edged shader")
	print("PASS" if fails == 0 else "FAILED %d" % fails)
	quit(1 if fails > 0 else 0)
