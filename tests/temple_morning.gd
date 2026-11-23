extends SceneTree
## Headless test for the morning gathering in the temple (see TempleMorning):
## - the temple has seats for the village and a place before the altar facing them,
## - at the morning's call the villagers walk to the temple's door, in through it, and sit on the
##   pews (never two on one seat, never a step outside the street, the porch and the nave),
## - Elsbeth stands before the altar facing the pews and speaks her lines, two answer,
## - then everyone gets up, walks out and goes on with the day: the shopkeeper behind her counter
##   again (the shop is locked while she is away, and open once she is back),
## - the next day it happens again, and it does not happen for a game loaded after the service.
## Run with: godot --headless -s tests/temple_morning.gd --fixed-fps 60

var failures := 0
var game: Node
var frames := 0
const HERO := "Testheld Bankrast"
const STEP := 1.0 / 60.0


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
		print("PASS: temple morning")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _run(village: Outdoor, seconds: float, each := Callable()) -> void:
	for i in int(seconds / STEP):
		village.temple_morning.tick(village, STEP)
		village.bench_rest.tick(village, STEP)
		for v: Villager in village.villagers:
			v._physics_process(STEP)
		if each.is_valid():
			each.call()


## Whether a point is somewhere a villager on the way to the temple may stand: not inside any
## building's block but the temple's own nave (the walls of the houses are no way).
func _on_the_way(village: Outdoor, at: Vector3) -> bool:
	var rec := TempleMorning.temple_of(village)
	var nave := village.temple_room(rec.node)
	if nave.grow(0.3).has_point(Vector2(at.x, at.z)):
		return true
	for b: Dictionary in village.walk_in.buildings:
		if b == rec:
			continue
		if village.walk_in_room(b.node).has_point(Vector2(at.x, at.z)):
			return false
	return true


func _test() -> void:
	for lines: Array in TempleMorning.SPEECHES:
		for line: String in lines:
			check(Lang.EN.has(line), "the speech line has an English text: " + line)
	for line: String in TempleMorning.ANSWERS:
		check(Lang.EN.has(line), "the answer has an English text: " + line)
	check(Lang.EN.has(TempleMorning.NEWS), "the news has an English text")
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
	for e in village.enemies:
		e.set_physics_process(false)
	village.set_hour(5.5)
	village.day = 3
	var rec := TempleMorning.temple_of(village)
	check(not rec.is_empty(), "the temple can be walked into")
	var found: Dictionary = village.walk_in.temple_seats(rec)
	var places: Array = found.seats
	check(places.size() >= 16, "the pews seat the village: %d" % places.size())
	var goers := village.villagers.filter(func(v: Villager) -> bool: return TempleMorning.goes(v))
	check(places.size() >= goers.size(), "a seat for each: %d seats for %d" % [places.size(), goers.size()])
	var speaker: Villager
	for v: Villager in village.villagers:
		if v.role == TempleMorning.SPEAKER:
			speaker = v
	check(speaker != null, "Elsbeth is in the village")
	var hero: Player = game.player
	hero.global_position = village.cell_to_world(village.world_to_cell(hero.global_position))

	# The morning: everyone is up and about before the call.
	var said := []
	var hear := func(who: String, text: String, _pos: Vector3) -> void: said.append([who, text])
	Events.bus().speech_said.connect(hear)
	var lost := []
	var seated_most := 0
	var shop_keeper: Villager
	for v: Villager in village.villagers:
		if v.role == "6":
			shop_keeper = v
		if v.at_home:
			v.set_night(false, true)
	village.set_hour(5.85)
	_run(village, 3.0)
	check(village.temple_morning.phase == "idle", "before the call nothing gathers")
	# The call: the hour runs on slowly (an hour is 50 seconds) while they walk.
	var hour := 5.9
	for t in int(150.0 / STEP):
		if t % 30 == 0:
			hour += 30.0 * STEP * 24.0 / DayNight.DAY_LENGTH
			village.hour = hour
		village.temple_morning.tick(village, STEP)
		village.bench_rest.tick(village, STEP)
		for v: Villager in village.villagers:
			v._physics_process(STEP)
			if v.service_step() in ["in", "sitting", "seated", "rising", "at", "out"] and not _on_the_way(village, v.global_position):
				lost.append(v.display_name)
		var seated := 0
		for v: Villager in village.villagers:
			if v.service_step() == "seated":
				seated += 1
		seated_most = maxi(seated_most, seated)
		if village.temple_morning.phase == "speech" and speaker.service_step() == "at":
			break
	check(lost.is_empty(), "nobody walked through a wall: %s" % [lost])
	check(village.temple_morning.phase in ["speech", "leave"], "the speech begins: phase %s at hour %.2f" % [village.temple_morning.phase, hour])
	var taken := {}
	for s: Dictionary in village.temple_morning.seats:
		if s.taker != null:
			check(not taken.has(s.taker), "nobody holds two seats")
			taken[s.taker] = true
			check(is_same(s.taker.service_spot(), s) or not s.taker.serves(), "each taker walks to their own seat")
	var at: Vector3 = speaker.global_position
	var altar_front: Vector3 = village.temple_morning.pulpit.stand
	check(Vector2(at.x - altar_front.x, at.z - altar_front.z).length() < 0.5, "Elsbeth stands before the altar")
	var facing := speaker.global_transform.basis.z
	var to_pews: Vector3 = village.temple_morning.pulpit.front
	check(facing.dot(to_pews) > 0.7, "she faces the pews: %.2f" % facing.dot(to_pews))
	# The shop is shut while the shopkeeper is away from her counter.
	var shop: Dictionary = {}
	for b: Dictionary in village.walk_in.buildings:
		if b.kind == "shop":
			shop = b
	if shop_keeper != null and not shop.is_empty():
		check(VillagePosts.locked(village, shop), "the shop is locked while the shopkeeper is in the temple")

	# The speech; the last ones still come in and sit down.
	_run(village, 25.0, func():
		village.hour = minf(village.hour, 7.5)
		seated_most = maxi(seated_most, village.villagers.filter(func(v: Villager) -> bool: return v.service_step() == "seated").size()))
	check(seated_most >= goers.size() - 3, "most of the village sits down: %d of %d" % [seated_most, goers.size()])
	var lines_said := said.filter(func(s: Array) -> bool: return s[0] == speaker.display_name)
	check(lines_said.size() >= 3, "Elsbeth speaks her three lines: %d" % lines_said.size())
	var whole := false
	for lines: Array in TempleMorning.SPEECHES:
		if lines_said.size() >= 3 and lines_said[0][1] == Lang.t(lines[0]):
			whole = true
	check(whole, "her speech is one of the speeches")
	check(said.size() > lines_said.size(), "someone on the pews answers")

	# Everyone leaves and goes on with the day.
	_run(village, 45.0, func(): village.hour = minf(village.hour, 7.7))
	var still := village.villagers.filter(func(v: Villager) -> bool: return v.serves())
	check(still.is_empty(), "everyone has left the temple: %d still there" % still.size())
	check(village.temple_morning.phase == "idle", "the service is over: %s" % village.temple_morning.phase)
	for v: Villager in village.villagers:
		# (Walking in through a hall's door a keeper has no body for a moment either, see VillagePosts.)
		if not v.at_home and (v.post_trip.is_empty() or VillagePosts.at_post(v)):
			check(v.collision_layer != 0, "%s is a body again" % v.display_name)
	_run(village, 40.0, func(): village.hour = minf(village.hour, 7.84))
	if shop_keeper != null and not shop.is_empty():
		check(not VillagePosts.locked(village, shop), "the shop is open again once the shopkeeper is back at her counter")
	Events.bus().speech_said.disconnect(hear)

	# Not twice a day.
	village.hour = 6.0
	_run(village, 1.0)
	check(village.temple_morning.phase == "idle", "no second service on the same day")
	# Another day: again, with another speech.
	village.day = 4
	village.hour = 6.0
	_run(village, 1.0)
	check(village.temple_morning.phase == "gather", "the next morning it begins again")
	_run(village, 40.0)
	# An alarm ends it at once: everyone out on the porch, nobody stays inside.
	village.village_alarm.raised = true
	_run(village, 40.0)
	village.village_alarm.raised = false
	var inside := village.villagers.filter(func(v: Villager) -> bool: return v.serves())
	check(village.temple_morning.phase == "idle" and inside.is_empty(), "the alarm sends everyone out: %s, %d inside" % [village.temple_morning.phase, inside.size()])
