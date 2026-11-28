extends SceneTree
## Herald Konrad as the town crier (see TownCrier, CrierNews, CrierPodium, CrierHat, Loudhailer): the news of the
## hero's deeds and its daily calls, the hat, the podium and sign, the climb with the loudhailer, and stepping aside
## for Matthes with a word of thanks. Run with: godot --headless --fixed-fps 60 -s tests/town_crier.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	Lang._apply()
	_news_logic()
	_parts()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(count: int) -> void:
	for i in count:
		await process_frame


## Deeds are told once, in order, with their own sentences, and kept in the save.
func _news_logic() -> void:
	var news := CrierNews.new()
	var quest: String = Quests.ALL.keys()[0]
	news.add(CrierNews.QUEST, quest, "Anna", 3)
	news.add(CrierNews.QUEST, quest, "Anna", 3)
	news.add(CrierNews.RIDDLE, RiddleCount.OWL_CLOCK, "Anna", 4)
	news.add(CrierNews.RIDDLE, "no-such-riddle", "Anna", 4)
	news.add(CrierNews.QUEST, "no-such-task", "Anna", 4)
	check(news.items.size() == 2, "each deed counts once, unknown ones not at all")
	check(news.take_fresh() == "", "a deed is not called out the very moment it is done")
	news._fresh_at = 0
	var line := news.take_fresh()
	check(line.contains("owl clock") and line.contains("Anna"), "the newest deed is announced first: " + line)
	check(news.take_fresh() == "", "the announced deeds are not announced twice")
	check(news.due_slot(5, 9.0) == -1, "no news before ten")
	check(news.due_slot(5, 10.2) == 0, "the news at ten")
	check(news.due_slot(5, 12.0) == -1, "ten is over by noon")
	check(news.due_slot(5, 16.1) == 1, "the news at four")
	var first := news.take_daily(5, 0)
	check(first.contains("owl clock"), "the daily news starts with the newest deed")
	check(news.due_slot(5, 10.4) == -1, "the news is called once a slot")
	var second := news.take_daily(5, 1)
	check(second != first and second.contains("Anna"), "the next call reads the older deed")
	var again := CrierNews.new()
	again.load_from(news.for_save())
	check(again.items.size() == 2 and again.due_slot(5, 16.1) == -1, "the news and its calls are kept in the save")
	check(news.take_daily(9, 0) == "", "deeds older than %d days are no news" % CrierNews.KEEP_DAYS)
	check(CrierNews.SIGN_TIP in Lang.EN and Lang.t(CrierNews.SIGN_TIP) == "Apple Valley News every day at 10 am and 4 pm", "the sign's tip reads in English")


## The hat, the horn, the podium and the sign as meshes.
func _parts() -> void:
	check(CrierHat.mesh().get_surface_count() == 1 and CrierHat.plume().get_surface_count() == 1, "the hat and its plume have a surface")
	check(CrierHat.brim_edge(0.0).x > CrierHat.brim_edge(PI / 3.0).x + 0.2, "the brim has a point at the front and is pulled in between the points")
	check(absf(CrierHat.brim_edge(TAU / 3.0).x - CrierHat.brim_edge(0.0).x) < 0.01, "the three points are alike")
	check(CrierHat.brim_edge(PI / 3.0).y > CrierHat.brim_edge(0.0).y + 0.1, "the sides are turned up, the points are not")
	check(Loudhailer.mesh().get_surface_count() == 1 and Loudhailer.grip_mesh().get_surface_count() == 1, "the loudhailer has a horn and a grip")
	check(Loudhailer.radius(1.0) > Loudhailer.radius(0.0) * 4.0, "the horn flares to a wide bell")
	check(CrownInsignia.cloth().get_width() > 0 and CrownInsignia.badge().get_width() > 0, "the insignia is painted")
	var holder := Node3D.new()
	root.add_child(holder)
	var podium := CrierPodium.build(holder, Vector3.ZERO)
	check(podium.get_node_or_null("Banner") != null, "the podium has its banner")
	var sign_node := podium.get_node_or_null("NewsSign")
	check(sign_node != null and (sign_node.find_child("Letters", true, false) as Label3D).text == "NEWS!", "the sign says NEWS!")
	check(podium.get_child_count() >= 6, "the podium has timber, a banner, a scroll and a sign")
	holder.queue_free()
	# The hat sits on a knight's head and goes in winter.
	var knight: Node3D = load("res://assets/characters/Knight.glb").instantiate()
	root.add_child(knight)
	CrierHat.put_on(knight)
	check(knight.find_child(CrierHat.TAG, true, false) != null, "the hat is put on")
	CrierHat.show_hat(knight, false)
	check(not (knight.find_child(CrierHat.TAG, true, false) as Node3D).visible, "the hat is taken off in winter")
	knight.queue_free()


func _run() -> void:
	game.hero_name = "Anna"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level
	game.season_shift = 20 - posmod(Seasons.today(), Weather.YEAR_DAYS)
	# Noon: outside the hours of the daily news.
	lvl.set_hour(12.0)
	game.day_hour = 12.0
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	await _wait(30)
	var konrad: Villager = lvl.herald()
	check(konrad != null and not lvl.crier_stage.is_empty(), "the village has its herald and his stage")
	if konrad == null or lvl.crier_stage.is_empty():
		return _done()
	check(konrad.find_child(CrierHat.TAG, true, false) != null, "Konrad wears the hat of the crown")
	check(lvl.astar.is_point_solid(lvl.world_to_cell(lvl.crier_stage.pos)), "villagers keep off the podium's tile")
	# The sign's tip: a ray through the board hits it, one far off does not.
	var board: Vector3 = lvl.crier_stage.sign
	check(TownCrier.sign_under_ray(lvl, board + Vector3(0, 6, 6), Vector3(0, -1, -1).normalized()), "the mouse on the sign shows its tip")
	check(not TownCrier.sign_under_ray(lvl, board + Vector3(9, 6, 6), Vector3(0, -1, -1).normalized()), "the mouse beside the sign shows nothing")
	# Stepping aside for Matthes.
	var matthes: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == StreetSweeper.ROLE:
			matthes = v
	check(matthes != null, "Matthes is there")
	konrad._start("work", 30.0)
	var home := konrad.global_position
	matthes.global_position = home + Vector3(-1.5, 0, 0)
	TownCrier.give_way(matthes, Vector3.RIGHT)
	check(konrad._task == "walk", "Konrad steps out of the way of the broom")
	await _wait(90)
	check(konrad.global_position.distance_to(home) > 1.5, "Konrad stands aside, not in the way")
	check(konrad._task == TownCrier.WAIT_TASK, "Konrad waits aside")
	check(konrad.is_talking(), "Konrad says a word about Matthes's work")
	matthes.global_position = home + Vector3(30, 0, 0)
	await _wait(600)
	check(lvl.world_to_cell(konrad.global_position) == konrad.home, "Konrad is back at his place")
	# A deed of the hero is announced from the podium.
	CrierNews.current.add(CrierNews.QUEST, Quests.ALL.keys()[0], "Anna", game.day)
	CrierNews.current._fresh_at = 0
	await _wait(240)
	check(konrad.is_announcing(), "Konrad climbs his podium for the news of a deed")
	var peak := 0.0
	var spoke := false
	var horn_up := false
	for i in 1500:
		await _wait(1)
		peak = maxf(peak, konrad.global_position.y)
		if konrad._crier != null and konrad._crier.phase == "speak":
			spoke = spoke or konrad.is_talking()
			horn_up = horn_up or (konrad._crier.hailer != null and konrad._crier.hailer.visible)
		if not konrad.is_announcing() and peak > 0.0:
			break
	check(peak > CrierPodium.DECK_H - 0.05, "he stands on the deck (%.2f m)" % peak)
	check(spoke and horn_up, "he speaks with the loudhailer raised")
	check(is_zero_approx(konrad.global_position.y) and not konrad.is_announcing(), "he is down on the ground after the speech")
	check(konrad._crier.hailer == null or not konrad._crier.hailer.visible, "the loudhailer is put away")
	# The daily news at ten.
	konrad._start("work", 30.0)
	await _wait(5)
	game.day_hour = 10.1
	lvl.set_hour(10.1)
	var saw := false
	for i in 40:
		await _wait(10)
		saw = saw or konrad.is_announcing()
	check(saw, "the daily news is called at ten")
	_done()


func _done() -> void:
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
