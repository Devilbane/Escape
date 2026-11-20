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
	check(TownMeals.meal_at(9.0) == -1 and TownMeals.meal_at(12.0) == 0 and TownMeals.meal_at(20.0) == 1, "lunch at noon, dinner at eight")
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

	for meal in [12.0, 20.0]:
		_meal(village, meals, meal)


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
