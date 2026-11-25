extends SceneTree
## Headless test for townsfolk resting on the benches by the fountain (see BenchRest):
## - every bench on the square is a resting place, reached from open ground,
## - a bench is handed out to one villager only, never the one the hero is at,
##   and only to those with no stall or post to keep,
## - the villager sits on the bench facing the fountain, keeps the clear gap to
##   everyone else, and gets up again after a while; the bench is free again,
## - a bench with a villager on it does not seat the hero,
## - left to themselves, the townsfolk rest there now and then, not all the time.
## Run with: godot --headless -s tests/bench_rest.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Testheld Bankrast"
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
		print("PASS: bench rest")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## Runs the village for `seconds`, the benches and the villagers in step.
func _run(village: Outdoor, seconds: float, each := Callable()) -> void:
	for i in int(seconds / STEP):
		village.bench_rest.tick(village, STEP)
		for v: Villager in village.villagers:
			v._physics_process(STEP)
		if each.is_valid():
			each.call()


func _test() -> void:
	check(Lang.EN.has("Auf dieser Bank sitzt schon jemand."), "the taken bench's message has an English text")
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.village_talk.clear()
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	check(village is Outdoor, "the village is loaded")
	if not village is Outdoor:
		return
	game.state = game.State.PLAYING
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	village.set_weather(Weather.CLEAR)
	# A quiet morning: no meal near (see TownMeals), everyone out and about.
	village.set_hour(9.0)
	for e in village.enemies:
		e.set_physics_process(false)
	var rest: BenchRest = village.bench_rest
	var hero: Player = game.player
	hero.global_position = village.cell_to_world(village.world_to_cell(hero.global_position))
	rest.tick(village, STEP)

	var benches: Array = village.stations.filter(func(s): return s.kind == Seats.KIND and BenchRest._by_fountain(village, s.cell))
	check(benches.size() >= 2, "the fountain has its benches: %d" % benches.size())
	check(rest.seats.size() == benches.size(), "every bench by the fountain is a place to rest: %d of %d" % [rest.seats.size(), benches.size()])
	for s: Dictionary in rest.seats:
		check(village.is_open(village.world_to_cell(s.walk_to)), "a bench is reached from open ground: %s" % [s.walk_to])
		check(s.walk_to.distance_to(s.stand) < Level.TILE * 1.2, "the last paces to a bench are few: %.1f m" % s.walk_to.distance_to(s.stand))
		check(s.front.dot(Seats.front(s.station)) > 0.99, "a rester faces the way the bench faces")

	var resters := village.villagers.filter(func(v: Villager): return BenchRest.rests_here(v))
	check(resters.size() > rest.seats.size(), "more townsfolk may rest than there are benches: %d" % resters.size())
	for v: Villager in village.villagers:
		if v.keeps_spot() or v.role in BenchRest.STAY_AWAY:
			check(not BenchRest.rests_here(v), "%s keeps to their post and never rests on a bench" % v.role)

	# The hero stands right at one bench: nobody is sent to that one.
	var hero_bench: Dictionary = rest.seats[0]
	hero.global_position = hero_bench.stand
	for v: Villager in resters:
		v._start("idle", 1.0)
		v.hush()
	village.barber_chair.seat = {} # Only the benches are counted here, not the barber's chair.
	var sent := 0
	for v: Villager in resters:
		for i in 60:
			if v.rests():
				break
			if v._rest_on_bench():
				sent += 1
				break
	check(sent == rest.seats.size() - 1, "every free bench is taken, one villager each: %d of %d" % [sent, rest.seats.size() - 1])
	check(hero_bench.taker == null, "nobody takes the bench the hero stands at")
	var takers := {}
	for s: Dictionary in rest.seats:
		if s.taker != null:
			check(not takers.has(s.taker), "a villager has one bench only")
			takers[s.taker] = true
	var left_over := resters.filter(func(v: Villager): return not v.rests())
	if not left_over.is_empty():
		var again := 0
		for i in 60:
			if left_over[0]._rest_on_bench():
				again += 1
		check(again == 0, "with every bench taken, nobody else is sent to one")

	# They walk over and sit down on their bench, facing the fountain.
	hero.global_position = village.cell_to_world(village.world_to_cell(hero_bench.stand)) + Vector3(0, 0, -Level.TILE * 2.0)
	var all_sat := {}
	# Flags in a Dictionary: a lambda gets its own copy of a plain bool.
	var f := {"crowded": "", "shared": false, "jumped": false}
	var last := {}
	_run(village, 40.0, func():
		var on := {}
		for v: Villager in village.villagers:
			if v.rests() and last.has(v) and last[v].distance_to(v.global_position) > 0.5:
				f.jumped = true
			last[v] = v.global_position
			if v.seated_on_bench():
				all_sat[v] = true
				if on.has(v.meal_seat.sit):
					f.shared = true
				on[v.meal_seat.sit] = true
				for o: Villager in village.villagers:
					if o != v and o.visible and not o.at_home and o._task != "walk" \
							and o.global_position.distance_to(v.global_position) < v.radius + o.radius + Villager.BODY_GAP - 0.05:
						f.crowded = "%s and %s %.2f m" % [v.role, o.role, o.global_position.distance_to(v.global_position)]
	)
	check(all_sat.size() >= sent - 1 and all_sat.size() >= 1, "the townsfolk sent to the benches sit down: %d of %d" % [all_sat.size(), sent])
	check(not f.shared, "nobody shares a bench")
	check(not f.jumped, "the resters walk up to their bench and never jump onto it")
	check(f.crowded == "", "a rester keeps the clear gap to everyone standing about: %s" % f.crowded)

	# One sits there now: in the middle of their bench, facing the fountain; the hero cannot sit there too.
	var seated: Array = rest.seated()
	if seated.is_empty():
		# Everyone may have got up already; send one again and let them sit down.
		for v: Villager in resters:
			v._start("idle", 1.0)
			for i in 60:
				if v._rest_on_bench():
					break
			if v.rests():
				break
		_run(village, 15.0)
		seated = rest.seated()
	check(not seated.is_empty(), "someone sits on a bench")
	if not seated.is_empty():
		var v: Villager = seated[0]
		var at: Vector3 = v.meal_seat.sit
		check(Vector2(at.x - v.global_position.x, at.z - v.global_position.z).length() < 0.05, "the rester sits in the middle of the bench")
		check(v.facing().dot(v.meal_seat.front) > 0.95 if v.has_method("facing") else true, "the rester faces the fountain")
		check(not v.dines() and not v.seated_at_meal(), "a rest on a bench is not a meal")
		var station: Dictionary = v.meal_seat.station
		check(rest.taken(station), "the bench is taken while someone rests on it")
		hero.global_position = Seats.stand_spot(station, village, hero.radius)
		game._use_station(station)
		check(not hero.is_seated(), "the hero does not sit on a bench someone rests on")
		hero.global_position = village.cell_to_world(village.world_to_cell(hero_bench.stand)) + Vector3(0, 0, -Level.TILE * 2.0)

	# After a while every one of them gets up and the benches are free again.
	_run(village, BenchRest.STAY.y + 10.0)
	for s: Dictionary in rest.seats:
		check(s.taker == null or not s.taker.seated_on_bench() or s.until > 0.0, "a rester gets up after a while")
	var got_up := 0
	for v in all_sat:
		if not v.seated_on_bench():
			got_up += 1
	check(got_up >= all_sat.size() - 1, "the resters get up again: %d of %d" % [got_up, all_sat.size()])

	# Left alone for a long morning, some come to rest on their own, but not everyone, and not all the time.
	for v: Villager in village.villagers:
		v._start("idle", randf_range(0.5, 3.0))
	var came := {}
	var n := {"samples": 0, "resting": 0, "visits": 0}
	var was := {}
	_run(village, 600.0, func():
		n.samples += 1
		for v: Villager in village.villagers:
			if v.rests():
				came[v] = true
				n.resting += 1
				if not was.get(v, false):
					n.visits += 1
			was[v] = v.rests()
	)
	check(came.size() >= 2, "the townsfolk rest on the benches on their own now and then: %d" % came.size())
	var share := float(n.resting) / float(maxi(1, n.samples * resters.size()))
	check(share > 0.01, "a rest on a bench happens, now and then: %.3f" % share)
	check(share < 0.35, "resting is one idle choice among others, not all they do: %.3f" % share)
	print("bench rest: %d of %d came on their own, %d visits, %.1f%% of their time on a bench" % [came.size(), resters.size(), n.visits, share * 100.0])
