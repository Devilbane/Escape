extends SceneTree
## Headless test: the rock climber Wolfram (see ClimberNpc and ClimberRoute). He stands at the foot of the
## face east of the stream, climbs it under the rules of RockClimb (three pull-ups, a nail with the rope,
## then a nail after every two) without ever slipping, sits at the top, and climbs down taking his nails
## and rope with him. A hero who watches him for an hour of game time gets a rough idea of climbing
## (the skill is ripe, level 0 until a night's sleep). His wares cost more than Mira's and are limited.
## Run with: godot --headless --fixed-fps 60 -s tests/rock_climber.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var told: Array[String] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Climber test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	game.state = game.State.PLAYING
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	Events.bus().news_told.connect(func(text: String, _c: Color, _d: float) -> void: told.append(text))
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0

	# He is there, with his window, at the foot of the face the hero can climb too.
	var climber: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == ClimberNpc.ROLE:
			climber = v
	check(climber != null, "the climber stands on the map")
	if climber == null:
		quit(1)
		return
	check(climber.station.kind == ClimberNpc.KIND and NpcKeywords.has(ClimberNpc.KIND), "he has a window that answers to words")
	check(NpcKeywords.matches(ClimberNpc.KIND, "tell me about climbing"), "the word \"climbing\" opens his window")
	check(NpcKeywords.matches(ClimberNpc.KIND, "klettern"), "so does the German word")
	var spot := ClimbSpots.at(lvl, ClimberNpc.SPOT_CELL)
	check(not spot.is_empty() and lvl.cell_char(spot.cell) == Mountains.ROCK_LETTER, "his face is a climbing spot in the rock")
	check(lvl.cell_char(spot.cell + Vector2i(0, 1)) != Mountains.ROCK_LETTER, "with open ground in front of it")
	check(climber.global_position.distance_to(lvl.cell_to_world(spot.cell + Vector2i(0, 1))) < 6.0, "he starts at its foot")
	check(Climbing.can_climb(float(spot.height), int(spot.level)), "the skill the spot asks for can climb its height")

	# The hero looks on from a few steps away, in the open.
	hero.global_position = lvl.cell_to_world(spot.cell + Vector2i(0, 4))
	hero.reset_physics_interpolation()
	var top := 0.0
	var most_nails := 0
	var sat := false
	var sat_at := -1.0
	var sat_z := 99.0
	var rope_seen := false
	var came_down := false
	var phases := {}
	var guard := 0
	while guard < 9000 and not came_down:
		await _wait(1)
		guard += 1
		hero.hp = hero.max_hp
		if climber._climb == null:
			continue
		var r: ClimberRoute = climber._climb
		phases[r.phase] = true
		top = maxf(top, climber.global_position.y)
		most_nails = maxi(most_nails, r.nails_left.size())
		rope_seen = rope_seen or r.rope != null
		if r.phase == ClimberRoute.Phase.VIEW:
			sat = true
			sat_at = climber.global_position.y
			sat_z = climber.global_position.z - lvl.cell_to_world(spot.cell).z
		if sat and r.phase == ClimberRoute.Phase.WAIT and r.nails_left.is_empty():
			came_down = true
	check(phases.has(ClimberRoute.Phase.PULL) and phases.has(ClimberRoute.Phase.HAMMER) and phases.has(ClimberRoute.Phase.THREAD), "he pulls up, hammers and threads the rope")
	check(top > float(spot.height) - 0.3, "he gets to the top (%.2f of %.2f)" % [top, float(spot.height)])
	check(most_nails == 3, "three nails on the way (a nail after three pull-ups, the next two after two each): %d" % most_nails)
	check(rope_seen, "he climbs on a rope")
	check(sat and absf(sat_at - float(spot.height)) < 0.3, "he rests on the terrace (y %.2f)" % sat_at)
	# He sits on the flat part of the top (it ends a metre in front of the middle of the tile), well back from that edge.
	check(sat_z < -0.3, "he sits behind the middle of the top, not out at its edge (%.2f m from the middle)" % sat_z)
	check(phases.has(ClimberRoute.Phase.UNCLIP), "he takes the nails out on the way down")
	check(came_down, "he is down again after %d frames" % guard)
	check(lvl.get_node_or_null("ClimberRope") == null and climber._climb.rope == null, "no rope is left on the wall")
	check(climber.global_position.y < 0.3, "he stands on the ground (y %.2f)" % climber.global_position.y)

	# Watching: an hour of game time makes the skill ripe, but it stays level 0 until a night's sleep.
	check(game.lore.has(ClimberNpc.WATCHED), "the hero who watched him has a rough idea (%d frames)" % guard)
	check(told.has(Lang.t(ClimberNpc.WATCHED_TELL)), "and was told to sleep on it")
	check(hero.xp.get("klettern", 0.0) >= Training.skill_xp_for(1), "the skill has enough practice for level 1")
	check(hero.trained_level("klettern") == 0, "but it is still level 0 before the night")

	# His wares: dearer than Mira's, few of each, one gone when bought.
	game.day = 10
	var stock := ClimberNpc.wares(game)
	check(stock.size() == ClimberNpc.WARES.size() and int(stock.kletterhammer) == 1, "he has a small stock of the climbing gear")
	for id: String in ClimberNpc.WARES:
		check(ClimberNpc.price(id) > Items.buy_price(id), "%s costs more than at Mira's" % id)
	game.coins = 1000
	hero.bag.clear()
	game.menus.open(ClimberNpc.KIND)
	await _wait(3)
	ClimberNpc._buy(game.menus, "kletterhammer")
	check(hero.bag.has("kletterhammer") and int(game.climber_stock.kletterhammer) == 0, "buying the hammer takes it from the stock")
	check(game.coins == 1000 - ClimberNpc.price("kletterhammer"), "and costs his price")
	ClimberNpc._buy(game.menus, "kletterhammer")
	check(hero.bag.count("kletterhammer") == 1, "he has no second hammer")
	game.day = 10 + ClimberNpc.RESTOCK_DAYS
	check(int(ClimberNpc.wares(game).kletterhammer) == 1, "after a few days he has one again")
	game.menus.close()
	game.delete_save(game.save_path())
	print("PASS: rock climber" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
