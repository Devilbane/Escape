extends SceneTree
## Headless test for the braziers at the dining tables (see MealBraziers): four
## of them, only in winter (gone in summer, burning day and night in winter,
## brighter at night), their lights never take a shadow-casting slot, and none
## stands on a villager's path or on a seat: every step between two open tiles
## keeps clear of them, and every seat keeps room to sit down and get up.
## Run with: godot --headless -s tests/meal_braziers.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: meal braziers")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	game.hero_name = "Testheld Kohlenbecken"
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	check(village is Outdoor, "the village is loaded")
	if not village is Outdoor:
		return
	var meals: TownMeals = village.meals
	var br: MealBraziers = meals.braziers
	check(br.spots.size() == 4, "four braziers round the dining tables (%d)" % br.spots.size())
	village.set_winter_wear(false, true)
	check(not br.burning, "no braziers outside winter")
	for node in village.find_children("Brazier", "Node3D", true, false):
		check(not node.visible, "a brazier is put away outside winter")
	village.set_winter_wear(true, true)
	check(br.burning, "the braziers burn in winter")
	for node in village.find_children("Brazier", "Node3D", true, false):
		check(node.visible, "a brazier stands there in winter")
	meals.set_glow(0.0)
	var day_energy := br.lights[0].light_energy
	meals.set_glow(1.0)
	check(br.lights[0].light_energy > day_energy, "the braziers glow brighter at night")
	for light in br.lights:
		check(light.visible, "a brazier's light burns in winter")
		check(light.has_meta(LightShadows.NO_SHADOW), "a brazier's light never casts shadows")
	check(meals.lights_up(br.spots[0], 2.0), "a burning brazier counts as light")
	# Near the guests: each stands by a table's end.
	for at in br.spots:
		var near := INF
		for t: Vector3 in meals.tables:
			near = minf(near, Vector2(at.x - t.x, at.z - t.z).length())
		check(near < 3.0, "a brazier stands by a table (%.1f m)" % near)
		for s: Dictionary in meals.seats:
			for key in ["sit", "stand"]:
				var p: Vector3 = s[key]
				check(Vector2(p.x - at.x, p.z - at.z).length() > MealBraziers.BOWL.x + 0.5, "a brazier leaves room at a seat's %s spot" % key)
	# Clear of every step anyone takes between open tiles.
	var astar: AStarGrid2D = village.astar
	var room := WalkRules.JITTER + 0.45 + MealBraziers.BOWL.x
	var c0 := village.world_to_cell(br.spots[0]) - Vector2i(3, 3)
	var c1 := village.world_to_cell(br.spots[-1]) + Vector2i(3, 3)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var c := Vector2i(x, y)
			if not astar.is_in_boundsv(c) or astar.is_point_solid(c):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var n: Vector2i = c + d
				if not astar.is_in_boundsv(n) or astar.is_point_solid(n):
					continue
				if d.x != 0 and d.y != 0 and (astar.is_point_solid(Vector2i(n.x, c.y)) or astar.is_point_solid(Vector2i(c.x, n.y))):
					continue
				var a := village.cell_to_world(c)
				var b := village.cell_to_world(n)
				for at in br.spots:
					var p := Geometry3D.get_closest_point_to_segment(at, a, b)
					check(Vector2(p.x - at.x, p.z - at.z).length() >= room, "the step %s -> %s keeps clear of the brazier at %s" % [c, n, at])
	village.set_winter_wear(false, true)
	check(not br.burning and not br.lights[0].visible, "the braziers go when winter ends")
