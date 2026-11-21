extends SceneTree
## Headless test for the frame round the dining tables (see MealGarland): poles
## taller than 3.5 m stand round the eating area with ropes from their tops,
## many lamps hang from the ropes, the ivy on them joins the village's (so it
## follows the seasons), the lamps light up at night and go out by day, their
## lights never take a shadow-casting slot, and no pole stands on a villager's
## path: every seat can still be reached from outside the frame.
## Run with: godot --headless -s tests/meal_garland.gd

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
		print("PASS: meal garland")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	check(MealGarland.POLE_HEIGHT > 3.5, "the poles are more than 3.5 m tall")
	check(MealGarland.POLE_HEIGHT - MealGarland.TIE > TownMeals.RIDGE + 0.5, "the ropes run well above the canopies")
	game.hero_name = "Testheld Girlande"
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	check(village is Outdoor, "the village is loaded")
	if not village is Outdoor:
		return
	var meals: TownMeals = village.meals
	var g: MealGarland = meals.garland
	check(g.poles.size() >= 8, "poles all round the eating area (%d)" % g.poles.size())
	check(g.lamps.size() >= 40, "many lamps hang from the ropes (%d)" % g.lamps.size())
	check(g.lights.size() == MealGarland.LIGHTS, "a few soft lights along the ropes")
	# The frame goes round every table and its canopy.
	for t: Vector3 in meals.tables:
		var inside := true
		for foot in g.poles:
			if absf(foot.x - t.x) < TownMeals.POST_X + TownMeals.OVERHANG + 0.5 and absf(foot.z - t.z) < TownMeals.POST_Z + TownMeals.OVERHANG + 0.5:
				inside = false
		check(inside, "no pole stands under a canopy")
	# The lowest point of every rope is still well overhead.
	for i in g.poles.size():
		var a := g.poles[i] + Vector3(0, MealGarland.POLE_HEIGHT - MealGarland.TIE, 0)
		var b := g.poles[(i + 1) % g.poles.size()] + Vector3(0, MealGarland.POLE_HEIGHT - MealGarland.TIE, 0)
		check(MealGarland.rope_at(a, b, 0.5).y > 3.2, "rope %d sags no lower than 3.2 m" % i)
	for p in g.lamps:
		check(p.y > 2.7, "a lamp hangs above head height (%.2f)" % p.y)
	# The ivy joined the village's (one MultiMesh per map tile, dressed by IvySeasons).
	check(g.leaf_count > g.poles.size() * 250, "the poles and ropes are thick with ivy (%d leaves)" % g.leaf_count)
	var tile := Vector2i(floori(g.poles[0].x / AgedStone.LEAF_TILE), floori(g.poles[0].z / AgedStone.LEAF_TILE))
	check(village.ivy.has_node("Leaves_%d_%d" % [tile.x, tile.y]), "the frame's leaves are part of the village's ivy")
	# Lit at night, dark by day; never in the shadow budget.
	meals.set_glow(1.0)
	for light in g.lights:
		check(light.visible and light.light_energy > 0.5, "a garland light burns at night")
		check(light.has_meta(LightShadows.NO_SHADOW), "a garland light never casts shadows")
		check(light.omni_range >= LightShadows.MIN_RANGE, "a garland light reaches the ground")
	check(float(g.halo_mat.get_shader_parameter("glow")) > 0.9 and float(g.pool_mat.get_shader_parameter("glow")) > 0.9, "every globe throws its own soft light at night")
	var halos: MeshInstance3D = village.find_child("Halos", true, false)
	check(halos != null and halos.mesh.get_faces().size() == g.lamps.size() * 6, "one halo round every globe")
	check(g.lights.size() <= MealGarland.LIGHTS, "the globes' own light costs no real lights")
	check(meals.lights_up(g.lights[0].global_position, 3.0), "the garland counts as light at night")
	meals.set_glow(0.0)
	for light in g.lights:
		check(not light.visible, "a garland light is out by day")
	check(float(g.halo_mat.get_shader_parameter("glow")) == 0.0 and float(g.pool_mat.get_shader_parameter("glow")) == 0.0, "the globes throw no light by day")
	_paths(village, meals, g)


## No pole stands on a step anyone takes: villagers walk from tile centre to tile centre
## (WalkRules.JITTER off the line at most), so every step between two open tiles keeps clear
## of every pole. And every seat can be reached from outside the frame.
func _paths(village: Outdoor, meals: TownMeals, g: MealGarland) -> void:
	var astar: AStarGrid2D = village.astar
	var room := WalkRules.JITTER + 0.45 + MealGarland.POLE_RADIUS
	var lo := village.world_to_cell(g.poles[0]) - Vector2i(3, 3)
	var hi := village.world_to_cell(g.poles[g.poles.size() / 2]) + Vector2i(3, 3)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
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
				for foot in g.poles:
					var p := Geometry3D.get_closest_point_to_segment(foot, a, b)
					check(Vector2(p.x - foot.x, p.z - foot.z).length() >= room,
							"the step %s -> %s keeps clear of the pole at %s" % [c, n, foot])
	var outside := village.world_to_cell(g.poles[0]) + Vector2i(-2, -2)
	while astar.is_point_solid(outside):
		outside += Vector2i(-1, 0)
	for s: Dictionary in meals.seats:
		var cell := village.world_to_cell(s.stand)
		check(not astar.is_point_solid(cell), "a seat's standing spot stays open")
		check(not astar.get_id_path(outside, cell).is_empty(), "a seat can be reached from outside the frame")
	for p: Vector3 in village.spots.square:
		check(not village.world_to_cell(p) in g.blocked, "nobody is sent to a pole's tile")
