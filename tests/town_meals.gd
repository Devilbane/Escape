extends SceneTree
## Headless test for the shared meals on the square (see TownMeals): the village
## has its dining tables with six seats each, every table line has an English
## text, and over a lunch and a dinner the townsfolk come one by one (not all at
## once, most of them round the meal's hour), each takes a seat of their own,
## sits at it facing the table, talks at the table, and gets up again; the
## shopkeepers and the children stay away; dinner is over before nightfall.
## Run with: godot --headless -s tests/town_meals.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Testheld Mahlzeit"
const STEP := 1.0 / 30.0


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
		print("PASS: town meals")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	check(Tiles.OUTDOOR.has(TownMeals.LETTER), "the dining table's letter is claimed")
	for entry in TownMeals.TABLE_TALK:
		var lines: Array = entry.lines if entry is Dictionary else entry
		check(lines.size() >= 2, "a table talk has two lines at least: %s" % [lines])
		for line in lines:
			check(Lang.EN.has(line), "\"%s\" has an English text" % line)
	check(TownMeals.meal_at(9.0) == -1 and TownMeals.meal_at(12.0) == 0 and TownMeals.meal_at(19.0) == 1, "lunch at noon, dinner at seven")
	check(TownMeals.MEALS[1] - TownMeals.WALK_AHEAD + TownMeals.ARRIVE_LATE + 0.2 + TownMeals.SEATED.y <= TownMeals.LAST_CALL - 0.1, "even a late diner gets the full hour before bedtime")
	check(TownMeals.meal_at(DayNight.NIGHT_FROM) == -1, "no dinner after nightfall")

	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.village_talk.clear()
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	check(village is Outdoor, "the village is loaded")
	if not village is Outdoor:
		return
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	village.set_weather(Weather.CLEAR)
	var meals: TownMeals = village.meals
	check(meals.tables.size() >= 2, "the square has its dining tables: %d" % meals.tables.size())
	check(meals.seats.size() == meals.tables.size() * 6, "six seats at every table")
	for t: Vector3 in meals.tables:
		check(not village.is_open(village.world_to_cell(t)), "nobody walks through a table")
	for s: Dictionary in meals.seats:
		check(village.is_open(village.world_to_cell(s.stand)), "a seat is reached from open ground: %s" % [s.stand])
	var goers := []
	for v: Villager in village.villagers:
		if TownMeals.goes(v):
			goers.append(v)
	check(goers.size() >= 5, "most of the village comes to eat: %d" % goers.size())
	check(goers.size() <= meals.seats.size(), "there is a seat for everyone who comes")

	for meal in TownMeals.MEALS:
		_meal(village, meals, meal)
	_canopies(village, meals)


## Every table has its canopy, lantern and candles: dark by day, lit at dusk and
## at night; the ground under it stays free of snow.
func _canopies(village: Outdoor, meals: TownMeals) -> void:
	check(meals.lights.size() == meals.tables.size(), "a lantern hangs over every table")
	check(meals.roofed.size() == meals.tables.size(), "the ground under every canopy is roofed")
	for t: Vector3 in meals.tables:
		var c := village.world_to_cell(t)
		check(meals.roofed.has(c), "the canopy covers its table's tile")
	# The snow keeps off the whole of every bench (the sky mask's tiles blur at their corners).
	check(meals.awnings.size() == meals.tables.size(), "every canopy keeps the snow off what stands under it")
	var reach := Vector2(Seats.BENCH_SIZE.x * TownMeals.BENCH_STRETCH, Seats.BENCH_SIZE.z) * 0.5
	for i in meals.tables.size():
		var t: Vector3 = meals.tables[i]
		var a: Array = meals.awnings[i] if i < meals.awnings.size() else [0, 0, 0, 0, 0]
		for side in [-1.0, 1.0]:
			var b := Vector2(t.x, t.z + side * TownMeals.BENCH_OFF)
			check(a[0] < b.x - reach.x and a[2] > b.x + reach.x and a[1] < b.y - reach.y and a[3] > b.y + reach.y,
					"a table's bench lies wholly under its canopy's snow shelter")
		check(a[4] > TownMeals.EAVE, "the snow shelter reaches up to the cloth")
	var node: Node3D = null
	for child in village.get_children():
		if child.name.begins_with("MealTable"):
			node = child
			break
	check(node != null and node.get_node_or_null("Cloth") != null and node.get_node_or_null("Canopy") != null, "a table has its canopy cloth and frame")
	if node != null and node.get_node_or_null("Cloth") != null:
		var box: AABB = (node.get_node("Cloth") as MeshInstance3D).get_aabb()
		check(box.position.y > 2.0, "the cloth hangs above a standing villager's head: %.2f" % box.position.y)
	village.set_hour(12.0)
	for light in meals.lights:
		check(not light.visible, "the table lanterns are dark at noon")
	village.set_hour(19.5)
	for light in meals.lights:
		check(light.visible and light.light_energy > 1.0, "the table lanterns burn at dusk: %.2f" % light.light_energy)
	village.set_hour(23.0)
	for light in meals.lights:
		check(light.visible and is_equal_approx(light.light_energy, TownMeals.LAMP_ENERGY), "the table lanterns burn at night")
	check(meals.lights_up(meals.tables[0] + Vector3(0, 0, 2.5), Outdoor.LAMP_REACH), "a lit table shows the hero to enemies at night")


## Runs the village from well before the meal at `centre` until it is over.
func _meal(village: Outdoor, meals: TownMeals, centre: float) -> void:
	var name := "lunch" if centre < 18.0 else "dinner"
	for v: Villager in village.villagers:
		v._start("idle", 1.0)
		v.hush()
	village.hour = centre - 1.6
	meals.tick(village, STEP)
	var came := {}
	var max_seated := 0
	var talked := false
	var shared := false
	var misplaced := false
	var bad_comer := false
	var end := minf(centre + TownMeals.MEAL_END + 0.1, DayNight.NIGHT_FROM - 0.01)
	var steps := int((end - village.hour) * DayNight.DAY_LENGTH / 24.0 / STEP)
	var sat_from := {}
	var sat_for := {}
	var talk_texts := {}
	for entry in TownMeals.TABLE_TALK:
		for line in (entry.lines if entry is Dictionary else entry):
			talk_texts[Lang.t(line)] = true
	for i in steps:
		village.hour += STEP * 24.0 / DayNight.DAY_LENGTH
		meals.tick(village, STEP)
		for v: Villager in village.villagers:
			v._physics_process(STEP)
		var taken := {}
		var seated := 0
		for v: Villager in village.villagers:
			if v.dines() and not came.has(v):
				came[v] = village.hour
				if not TownMeals.goes(v):
					bad_comer = true
			if v.seated_at_meal():
				seated += 1
				var at: Vector3 = v.meal_seat.sit
				if Vector2(at.x - v.global_position.x, at.z - v.global_position.z).length() > 0.05:
					misplaced = true
				if taken.has(v.meal_seat.sit):
					shared = true
				taken[v.meal_seat.sit] = true
				if v._bubble_time > 0.0 and talk_texts.has(v._bubble.text.get_slice("\n", 1)):
					talked = true
		max_seated = maxi(max_seated, seated)
		for v: Villager in village.villagers:
			if v.seated_at_meal() and not sat_from.has(v):
				sat_from[v] = village.hour
			elif not v.seated_at_meal() and sat_from.has(v):
				sat_for[v] = village.hour - sat_from[v]
				sat_from.erase(v)
	check(not bad_comer, "%s: only those who come to meals sit down" % name)
	check(came.size() >= 5, "%s: the townsfolk come to eat: %d" % [name, came.size()])
	var hours: Array = came.values()
	hours.sort()
	if hours.size() >= 2:
		check(hours[-1] - hours[0] >= 0.4, "%s: they come one after another, not all at once: %s" % [name, hours])
		var mean := 0.0
		for h: float in hours:
			mean += h
		mean /= hours.size()
		check(absf(mean + TownMeals.WALK_AHEAD * 0.5 - centre) < 0.6, "%s: they come round the meal's hour: %.2f" % [name, mean])
		var together := 0
		for j in range(1, hours.size()):
			if hours[j] - hours[j - 1] < 0.01:
				together += 1
		check(together < hours.size() / 2, "%s: no crowd setting off in the same moment" % name)
	check(sat_for.size() >= 4, "%s: the diners get up again: %d" % [name, sat_for.size()])
	for v in sat_for:
		var h: float = sat_for[v]
		check(h >= TownMeals.SEATED.x - 0.02 and h <= TownMeals.SEATED.y + 0.02, "%s: %s sits about an hour: %.2f h" % [name, v.role, h])
	check(max_seated >= 4, "%s: the tables fill up: %d at once" % [name, max_seated])
	check(not shared, "%s: nobody shares a seat" % name)
	check(not misplaced, "%s: everyone sits on their seat" % name)
	check(talked, "%s: they talk at the table" % name)
	var still := 0
	for v: Villager in village.villagers:
		if v.dines():
			still += 1
	check(still == 0, "%s: everyone has left the table at the end: %d still there" % [name, still])
	for s: Dictionary in meals.seats:
		check(s.taker == null, "%s: every seat is free again" % name)
