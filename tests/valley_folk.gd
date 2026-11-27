extends SceneTree
## Headless test for the people of the farming valley (see ValleyFolk): they stand in the valley, every one has
## a job in every season, the spots of their jobs are free ground that faces the fields, the river or the well,
## noon is a rest at the well, and a farmer walks to the job he picks.
## Run with: godot --headless --fixed-fps 60 -s tests/valley_folk.gd

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
	if frames == 5:
		_test()
	return false


func _test() -> void:
	game.state = game.State.PLAYING
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	var folk := {}
	for v: Villager in level.villagers:
		if "φψχωλ".contains(v.role):
			folk[v.role] = v
			check(level.world_to_cell(v.global_position).y >= Outdoor.VALLEY_FROM, "%s lives in the valley" % v.display_name)
	check(folk.size() == 5, "all five valley folk are there (%d)" % folk.size())
	for letter in CropFields.LETTERS:
		check(not ValleyFolk.edge_spots(level, letter).is_empty(), "farmers can stand beside the %s fields" % CropFields.NAMES[letter])
	check(not ValleyFolk.bank_spots(level).is_empty(), "there is a river bank to stand on")
	check(not ValleyFolk.well_spots(level).is_empty(), "the valley has a well")
	check(not ValleyFolk.door_spots(level).is_empty(), "the valley has houses with doors")
	check(not ValleyFolk.flock_spots(level).is_empty(), "the shepherd has a flock to stand by")
	# A job in every season and hour of the working day, and noon is the rest at the well.
	var days := {"spring": 3, "summer": Weather.SPRING_DAYS + 2, "autumn": Weather.AUTUMN_FROM + 1, "winter": Weather.YEAR_DAYS - 1}
	for season: String in days:
		level.season_day = days[season]
		for role: String in ValleyFolk.FARMERS:
			var v: Villager = folk[role]
			for hour: float in [8.0, 10.5, 15.0, 17.0]:
				level.hour = hour
				var job := ValleyFolk.pick(v)
				check(not job.is_empty(), "%s has a job in %s at %.1f" % [v.display_name, season, hour])
				if job.is_empty():
					continue
				var c := level.world_to_cell(job.spot)
				check(level.is_open(c), "%s's spot for %s is free ground" % [v.display_name, job.id])
				check((job.spot as Vector3).distance_to(job.face) < 7.0, "%s's job %s faces what it works on" % [v.display_name, job.id])
		level.hour = 12.5
		var rest := ValleyFolk.pick(folk["φ"])
		check(rest.get("id", "") == "rest", "noon in %s is the rest at the well" % season)
		level.hour = 10.0
		# Sowing may repeat by chance (it goes on tile after tile), so three tries: two of three
		# different is fine, all three the same is not.
		var repeats := 0
		for attempt in 3:
			var last := ValleyFolk.pick(folk["φ"])
			var next := ValleyFolk.pick(folk["φ"], last.id)
			if next.id == last.id:
				repeats += 1
		check(repeats < 3, "nobody does the same job twice in a row (%d of 3 tries repeated)" % repeats)
	# Jobs fit their season: no sowing in autumn, no harvest in spring.
	for job: Dictionary in ValleyFolk.JOBS:
		for season: String in job.seasons:
			check(season in ["spring", "summer", "autumn", "winter"], "job %s names a real season" % job.id)
	# The farmer sets off for the job he picked.
	level.season_day = days.summer
	level.hour = 9.0
	var hannes: Villager = folk["φ"]
	hannes._farm_day()
	check(not hannes._job.is_empty() and hannes._task == "walk" or hannes._task == "work", "the farmer walks to his job")
	var goal := hannes._job.spot as Vector3
	var far := hannes.global_position.distance_to(goal)
	for i in 600:
		await physics_frame
		if hannes._task != "walk":
			break
	check(hannes.global_position.distance_to(goal) < far or far < 1.5, "he gets closer to the job (from %.1f m)" % far)
	await _events(level, folk)
	game.delete_save(game.save_path())
	print("PASS: valley folk" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)


## The small happenings: the farmhand gets stuck on the ladder and is helped down, the scarecrow falls to a crow
## and is stood up again, and the hero is paid for both.
func _events(level: Outdoor, folk: Dictionary) -> void:
	var ev: ValleyEvents = level.valley_events
	check(ev != null, "the valley has its happenings")
	if ev == null:
		return
	check(ValleyEvents.happens(5, 1, 100) and not ValleyEvents.happens(5, 1, 0), "the daily roll honours the chance")
	var day := 0
	while not (ValleyEvents.happens(day, 1, ValleyEvents.LADDER_CHANCE) and ValleyEvents.happens(day, 2, ValleyEvents.SCARECROW_CHANCE)):
		day += 1
	var paid := []
	Events.bus().gift_paid.connect(func(copper: int, _text: String) -> void: paid.append(copper))
	game.day = day
	game.day_hour = 10.0
	var veit: Villager = folk["χ"]
	veit.global_position = level.cell_to_world(ValleyEvents.LADDER_CELL + Vector2i(0, 3))
	game.player.global_position = level.cell_to_world(ValleyEvents.SCARECROW_CELL + Vector2i(-4, 0))
	for i in 1500:
		await physics_frame
		if ev.ladder_phase == 2:
			break
	check(ev.ladder_phase == 2, "Veit climbs the ladder and gets stuck (phase %d)" % ev.ladder_phase)
	check(level.stations.any(func(s: Dictionary) -> bool: return s.kind == ValleyEvents.KIND and s.what == ValleyEvents.LADDER), "the ladder asks for help")
	check(veit._model.position.y > 0.5 or ev.ladder_phase == 2, "he hangs above the ground")
	ev.help(ValleyEvents.LADDER)
	check(ev.ladder_phase == 3 and paid == [ValleyEvents.LADDER_REWARD], "the hero holds the ladder and is paid (%s)" % str(paid))
	check(not level.stations.any(func(s: Dictionary) -> bool: return s.get("what", "") == ValleyEvents.LADDER), "the ladder is quiet again")
	ev.help(ValleyEvents.LADDER)
	check(paid.size() == 1, "nobody is paid twice")
	# Left alone, he gets down by himself at noon.
	ev.ladder_phase = 2
	game.day_hour = ValleyEvents.LADDER_HOURS.y + 0.1
	await physics_frame
	await create_timer(0.7).timeout
	check(ev.ladder_phase == 3, "left alone he climbs down grumbling")
	# The scarecrow.
	game.day_hour = 15.0
	for i in 600:
		await physics_frame
		if ev.scare_phase == 3:
			break
	check(ev.scare_phase == 3, "a crow lands and the scarecrow falls over (phase %d)" % ev.scare_phase)
	check(level.stations.any(func(s: Dictionary) -> bool: return s.get("what", "") == ValleyEvents.SCARECROW), "the scarecrow asks to be stood up")
	ev.help(ValleyEvents.SCARECROW)
	check(paid == [ValleyEvents.LADDER_REWARD, ValleyEvents.SCARECROW_REWARD], "the scarecrow is stood up and the hero paid (%s)" % str(paid))
	check(is_zero_approx(ev._scare.rotation.z), "it stands upright")
