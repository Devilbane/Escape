extends SceneTree
## Headless test for the glow mushrooms (see GlowMushrooms): every day at most three patches of one to
## seven mushrooms in the open map, new places on a new day, picked ones gone for the day, one ingredient
## per mushroom, the glow following the clock, the kinds in their own colours, the lanterns' mushrooms.
## Run with: godot --headless -s tests/glow_mushrooms.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await process_frame
	var lvl: Outdoor = game.level
	check(not (lvl.get_meta("glow_cells", []) as Array).is_empty(), "the open map has places for glow mushrooms")

	# The rules: at most three patches, one to seven mushrooms, always on open ground, away from the village.
	var seen_sizes := {}
	var seen_kinds := {}
	var places := {}
	var most := 0
	var fewest := 99
	for day in range(1, 61):
		var patches := GlowMushrooms.patches_for(lvl, day)
		most = maxi(most, patches.size())
		fewest = mini(fewest, patches.size())
		for p: Dictionary in patches:
			seen_sizes[p.count] = int(seen_sizes.get(p.count, 0)) + 1
			seen_kinds[p.kind] = int(seen_kinds.get(p.kind, 0)) + 1
			places[p.cell] = true
			check(p.count >= 1 and p.count <= 7, "a patch has 1 to 7 mushrooms (%d)" % p.count)
			check(lvl.is_open(p.cell), "a patch grows on open ground")
		check(patches == GlowMushrooms.patches_for(lvl, day), "a day's patches are the same every time")
	check(most == 3 and fewest >= 1, "one to three patches a day (%d to %d)" % [fewest, most])
	check(places.size() > 20, "the places change from day to day (%d)" % places.size())
	var small := 0
	var big := 0
	for n in seen_sizes:
		if n <= 3:
			small += seen_sizes[n]
		elif n >= 6:
			big += seen_sizes[n]
	check(small > big * 3, "mostly one to three mushrooms (%d small, %d of six or seven)" % [small, big])
	check(seen_kinds.has(0), "the garland kind is the common one")
	var colours := {}
	for k in GlowMushrooms.KINDS.size():
		colours[GlowMushrooms.colour(k)] = true
	check(colours.size() == 4, "every kind glows in its own colour")
	check(GlowMushrooms.colour(0) == MealGarland.GLOW_COLOUR, "the common kind has the garland's colour")

	# Growing, picking, a new morning.
	GlowMushrooms.refresh(lvl, 3)
	var n := GlowMushrooms.grown(lvl)
	check(n >= 1 and n <= 3, "patches stand in the map (%d)" % n)
	var pick: Dictionary = lvl._pickups.filter(func(p: Dictionary) -> bool: return str(p.get("id", "")).begins_with("gp:"))[0]
	check(GlowMushrooms.is_glow(pick.ingredient) and pick.count >= 1, "a patch gives its mushrooms as an ingredient")
	check(Rarity.tier(pick.ingredient) == Crafting.INGREDIENTS[pick.ingredient].tier, "it has its rarity tier")
	lvl.taken[pick.id] = true
	lvl._pickups.erase(pick)
	pick.node.queue_free()
	GlowMushrooms.refresh(lvl, 3)
	check(GlowMushrooms.grown(lvl) == n - 1, "a picked patch stays gone for the day")
	GlowMushrooms.refresh(lvl, 4)
	check(not lvl.taken.has(pick.id), "yesterday's pick is forgotten")
	check(GlowMushrooms.grown(lvl) == GlowMushrooms.patches_for(lvl, 4).size(), "a new morning, new patches")

	# The glow follows the clock.
	GlowMushrooms.set_glow(0.0)
	var cap := GlowMushrooms.cap_material(0)
	check(float(cap.get_shader_parameter("glow")) == 0.0, "pale and dull by day")
	GlowMushrooms.set_glow(0.5)
	check(is_equal_approx(float(GlowMushrooms.cap_material(1).get_shader_parameter("glow")), 0.5), "halfway at dusk")
	GlowMushrooms.set_glow(1.0)
	check(is_equal_approx(float(GlowMushrooms.pool_material(3).get_shader_parameter("glow")), 1.0), "full at night")
	lvl.set_hour(2.0)
	check(is_equal_approx(float(cap.get_shader_parameter("glow")), 1.0), "the outdoor night lights them")
	lvl.set_hour(12.0)
	check(float(cap.get_shader_parameter("glow")) == 0.0, "the outdoor noon puts them out")

	# The recipes and the compendium.
	for id in ["pilztrank", "sternentrank"]:
		check(Crafting.RECIPES.has(id), "recipe " + id)
		for ing in Crafting.RECIPES[id].ingredients:
			check(Crafting.INGREDIENTS.has(ing), "its ingredient %s exists" % ing)
	check(lvl._lamps.size() > 0 and lvl._candles.size() > 0 and lvl._candles[0].mesh == GlowMushrooms.lamp_mesh(), "the lanterns hold glow mushrooms")
	print("PASS: glow mushrooms" if failures == 0 else "FAILED: glow mushrooms (%d)" % failures)
	quit(1 if failures > 0 else 0)
