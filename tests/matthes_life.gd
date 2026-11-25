extends SceneTree
## Headless test: Matthes' farm work and courtship (MatthesLife):
## - in spring and summer working hours he joins a farmer on a field, with a hoe, a weeding stoop or a sack in his hands;
## - sweeping comes first: when there are leaves or snow to sweep, he is not sent to the fields;
## - he courts a woman of the village: a shy hello at first (fond 0 -> 1), then flowers; a yes raises the fondness and shows
##   hearts, a no costs him the day with her; at sweethearts he stays with her and looks at no one else;
## - the courting is saved with the game.
## Run with: godot --headless -s tests/matthes_life.gd

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


func _ticks(n: int) -> void:
	for i in n:
		game.weather = Weather.CLEAR
		await physics_frame


func _run() -> void:
	game.hero_name = "Besom"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	MatthesLife.clear()
	# Mid-spring, a clear morning.
	game.season_shift = (Weather.YEAR_DAYS - posmod(Seasons.today(), Weather.YEAR_DAYS)) + Weather.SPRING_DAYS / 2
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.snow_cover = 0.0
	lvl.set_hour(9.5)
	game.day_hour = 9.5
	await _ticks(30)
	check(Weather.is_spring(lvl.season_day), "it is spring")
	var sweeper: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == MatthesLife.ROLE:
			sweeper = v
	check(sweeper != null, "Matthes is in the village")
	if sweeper == null:
		quit(1)
		return

	# --- Field work ---
	check(MatthesLife.field_time(lvl), "spring morning: the fields want him")
	lvl.weather = Weather.RAIN
	check(not MatthesLife.field_time(lvl), "no field work in the rain")
	lvl.weather = Weather.CLEAR
	lvl.set_hour(12.5)
	check(not MatthesLife.field_time(lvl), "noon is his break")
	lvl.set_hour(9.5)
	# A farmer is at work on a field.
	var farmers: Array = lvl.villagers.filter(func(v: Villager) -> bool: return ValleyFolk.FARMERS.contains(v.role))
	check(not farmers.is_empty(), "the valley has farmers")
	for f: Villager in farmers:
		var job := ValleyFolk.pick(f, "")
		if not job.is_empty():
			f._job = job
			f.global_position = job.spot
			f._start("work", 60.0)
	sweeper.at_home = false
	sweeper.visible = true
	sweeper.night = false
	sweeper._start("idle", 1.0)
	var went := false
	for attempt in 6:
		went = MatthesLife.next(sweeper)
		if went:
			break
		sweeper._start("idle", 1.0)
	check(went, "he sets out for a field")
	var plan: Dictionary = sweeper.get_meta("tend", {})
	check(not plan.is_empty() and plan.kind in ["hoe", "sack"], "a spring job was chosen (%s)" % str(plan.get("kind")))
	check(sweeper._task == "walk", "he walks to it")
	# Beam him there and let him work.
	sweeper.global_position = plan.door if plan.has("door") else plan.spot
	sweeper._path.clear()
	await _ticks(5)
	check(sweeper._task == MatthesLife.TASK, "arrived: he is at his field work")
	await _ticks(60)
	if plan.kind == "sack":
		check(sweeper._model.find_child(MatthesLife.SACK, true, false) != null, "he shouldered a sack")
	sweeper.global_position = plan.spot
	sweeper._path.clear()
	await _ticks(60)
	var hoe := sweeper._model.find_child(MatthesLife.HOE, true, false)
	if plan.kind == "hoe":
		check(hoe != null and hoe.visible, "the hoe is in his hand")
	# Anything else puts the tools down.
	sweeper._start("idle", 1.0)
	check(not sweeper.has_meta("tend"), "the job is dropped when something else comes first")
	for n: String in [MatthesLife.HOE, MatthesLife.SACK, MatthesLife.FLOWER]:
		var p := sweeper._model.find_child(n, true, false)
		check(p == null or not p.visible, "%s is put away" % n)

	# --- Sweeping comes first ---
	game.season_shift = (Weather.AUTUMN_FROM + 2) - posmod(Seasons.today(), Weather.YEAR_DAYS)
	await _ticks(5)
	lvl.set_hour(9.5)
	if not Weather.is_autumn(lvl.season_day):
		print("note: not autumn (%s), skipping the sweeping-first check" % Weather.season(lvl.season_day))
	else:
		check(not MatthesLife.field_time(lvl), "autumn: no field work")
		check(LeafSweep.wants(lvl), "autumn morning: leaves want sweeping, and sweeping is asked before anything else")
	# Back to spring for the courtship.
	game.season_shift = (Weather.YEAR_DAYS - posmod(Seasons.today(), Weather.YEAR_DAYS)) + Weather.SPRING_DAYS / 2
	await _ticks(5)
	lvl.set_hour(18.0)
	game.day_hour = 18.0

	# --- Courtship ---
	check(MatthesLife.fond("9") == 0 and MatthesLife.sweetheart() == "", "he starts out with no sweetheart")
	var hanna: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "9":
			hanna = v
	check(hanna != null, "Hanna is in the village")
	if hanna == null:
		quit(1)
		return
	# He courts someone: the first visit is a shy hello without a flower.
	sweeper.global_position = lvl.cell_to_world(sweeper.home)
	hanna.at_home = false
	hanna.visible = true
	hanna.night = false
	hanna._start("idle", 30.0)
	sweeper._start("idle", 1.0)
	MatthesLife._visits = {"day": -1, "n": 0, "next": 0.0}
	check(MatthesLife.next(sweeper), "in the evening he goes courting")
	var visit: Dictionary = sweeper.get_meta("tend", {})
	check(visit.get("kind", "") == "visit", "it is a visit")
	var her: Villager = visit.get("her")
	check(her != null and MatthesLife.WOMEN.has(her.role), "he goes to a woman of the village (%s)" % (her.role if her != null else "-"))
	var role := her.role
	# Walk up (beamed to her side), stand shy, say hello.
	sweeper.global_position = her.global_position + Vector3(2.4, 0, 0)
	sweeper._path.clear()
	var guard := 0
	sweeper._start(MatthesLife.TASK, 600.0)
	while sweeper.has_meta("tend") and guard < 400:
		MatthesLife.step(sweeper, 0.25)
		guard += 1
		her._task_time = maxf(her._task_time, 1.0)
	check(not sweeper.has_meta("tend"), "the visit is over (%d steps)" % guard)
	check(MatthesLife.fond(role) == 1, "a shy hello makes the first point (%d)" % MatthesLife.fond(role))

	her = hanna
	role = "9"
	# Later visits bring flowers: a yes raises the fondness, a no costs only the day.
	var yes := 0
	var no := 0
	for k in 8:
		# The others turned him down today: only she is left to visit.
		MatthesLife._snubbed = {}
		for r: String in MatthesLife.WOMEN:
			if r != role:
				MatthesLife._snubbed[r] = lvl.season_day
		MatthesLife._visits = {"day": -1, "n": 0, "next": 0.0}
		MatthesLife.love[role] = 1
		her.at_home = false
		her._bubble_time = 0.0
		her.chat_partner = null
		her._start("idle", 60.0)
		sweeper._start("idle", 1.0)
		if not MatthesLife.next(sweeper):
			print("no visit: hour %.1f her free %s" % [lvl.hour, str(MatthesLife._free(her))])
			continue
		var p: Dictionary = sweeper.get_meta("tend")
		if p.get("her") != her:
			sweeper._start("idle", 1.0)
			continue
		sweeper.global_position = her.global_position + Vector3(2.0, 0, 0)
		sweeper._path.clear()
		sweeper._start(MatthesLife.TASK, 600.0)
		var saw_flower := false
		var saw_hearts := false
		guard = 0
		while sweeper.has_meta("tend") and guard < 400:
			MatthesLife.step(sweeper, 0.25)
			guard += 1
			her._task_time = maxf(her._task_time, 1.0)
			var fl := sweeper._model.find_child(MatthesLife.FLOWER, true, false)
			saw_flower = saw_flower or (fl != null and fl.visible)
		saw_hearts = lvl.find_child("Hearts", false, false) != null
		check(saw_flower, "he held a flower out")
		if MatthesLife.fond(role) > 1:
			yes += 1
			check(saw_hearts, "hearts rose at a yes")
		else:
			no += 1
			check(MatthesLife._snubbed.get(role, -1) == lvl.season_day, "a no is remembered for the day")
	check(yes > 0 and no > 0, "both answers happen (yes %d, no %d)" % [yes, no])

	# A "no" today: he does not come back to her today, and tries another woman.
	MatthesLife._snubbed[role] = lvl.season_day
	MatthesLife._visits = {"day": -1, "n": 0, "next": 0.0}
	var other := MatthesLife._suitor(sweeper, lvl)
	check(other == null or other.role != role, "after a no he turns to someone else")

	# Sweethearts: he looks at nobody else, and the lines change.
	MatthesLife.love.clear()
	MatthesLife.love[role] = MatthesLife.SWEETHEARTS
	check(MatthesLife.sweetheart() == role, "sweethearts")
	MatthesLife._snubbed = {}
	var sweet := MatthesLife._suitor(sweeper, lvl)
	check(sweet == null or sweet.role == role, "he courts only his sweetheart")
	var base: Array = sweeper._info.lines
	check(MatthesLife.talk_lines(base).size() > base.size() and MatthesLife.talk_lines(base)[base.size()] in MatthesLife.TALK_SWEET, "he tells the hero about her")

	# Saved with the game.
	var saved := MatthesLife.for_save()
	MatthesLife.clear()
	check(MatthesLife.sweetheart() == "", "a new game starts fresh")
	MatthesLife.load_from(saved)
	check(MatthesLife.fond(role) == MatthesLife.SWEETHEARTS, "the courtship comes back from the saved game")
	MatthesLife.load_from({"x": 4, "9": "oops"})
	check(MatthesLife.fond("x") == 0, "unknown keys are left out")

	# Props are built.
	check(MatthesLife.hoe(Node3D.new()).mesh.get_surface_count() > 0, "the hoe has a mesh")
	check(MatthesLife.sack(Node3D.new()).mesh.get_surface_count() > 0, "the sack has a mesh")
	for season in ["spring", "summer", "autumn", "winter"]:
		check(MatthesLife.flower_mesh(season).get_surface_count() > 0, "the flower of %s has a mesh" % season)

	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
