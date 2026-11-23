extends SceneTree
## Headless test for the tavern's brewer (see TavernBrewer, VillageHalls._tavern):
## - Eberhard lives in the village, keeps the tavern and works behind its bar by day;
## - the tavern has a hearth, kegs and taps, and a chair for Fritz;
## - Fritz walks in and sits down; the brewer brings him a beer (a mug in his hand, then on the
##   table) and the two chat in speech bubbles;
## - at nightfall both leave and the tavern is locked.
## Run with: godot --headless --fixed-fps 60 -s tests/tavern_brewer.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WalkIn.lock_halls = false
	Storage.use(Storage.Memory.new())
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


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Brewer test"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var brewer := _villager(TavernBrewer.BREWER)
	var fritz := _villager(TavernBrewer.GUEST)
	check(brewer != null and fritz != null, "the village has Eberhard the brewer and Fritz")
	check(VillageHalls.kept_by(TavernBrewer.BREWER) == "tavern", "the brewer keeps the tavern")
	check(Lang.EN.has(Villager.ROLES[TavernBrewer.BREWER].name), "the brewer's name has an English entry")
	check(VillageTalk.GOALS.has(TavernBrewer.BREWER), "the brewer has a wish")
	for talk: Array in TavernBrewer.TALKS:
		for line: String in talk:
			check(Lang.EN.has(line), "English for: " + line)
	var found := TavernBrewer.seat_of(lvl)
	check(not found.is_empty(), "the tavern has a seat for Fritz")
	if brewer == null or fritz == null or found.is_empty():
		_end()
		return
	var hall: Node3D = found.rec.node
	check(hall.find_child("Hearth", true, false) != null, "the tavern has a hearth")
	check(hall.find_child("Keg", true, false) != null and hall.find_child("BeerTap", true, false) != null, "and kegs and taps on the bar")
	check(hall.find_child("Chair", true, false) != null, "and a chair for Fritz")

	# The brewer works behind the bar by day.
	for i in 60 * 60:
		await physics_frame
		if VillagePosts.at_post(brewer):
			break
	check(VillagePosts.at_post(brewer), "by day the brewer is at his place behind the bar (%s, %s)" % [brewer._task, brewer.post_trip.get("step", "-")])
	check(not brewer._model.find_child("Mug", true, false).visible, "his mug is put away while he waits")

	# Fritz comes in and sits down.
	game.player.global_position = hall.global_position
	fritz.global_position = lvl.walk_in.door_points(found.rec)[0]
	check(TavernBrewer.arrive(fritz), "Fritz walks in through the door")
	var served := false
	var carried := false
	var spoke := false
	for i in 60 * 90:
		await physics_frame
		if brewer.post_trip.get("serve", "") == "to" and brewer._model.find_child("Mug", true, false).visible:
			carried = true
		if fritz.post_trip.get("beer", false):
			served = true
		if brewer.is_talking() or fritz.is_talking():
			spoke = true
		if served and spoke:
			break
	check(fritz.post_trip.get("seated", false) or served, "Fritz sits down at his chair")
	check(carried, "the brewer carries the mug over in his hand")
	check(served and (found.seat.mug as Node3D).visible, "the beer stands on Fritz's table")
	check(spoke, "the two talk in speech bubbles")

	# Nightfall: both go, and the tavern is locked.
	game.day_hour = 22.0
	lvl.set_hour(22.0)
	for i in 60 * 40:
		await physics_frame
		if fritz.post_trip.is_empty() and brewer.post_trip.is_empty():
			break
	check(fritz.post_trip.is_empty(), "Fritz leaves the tavern at night")
	check(brewer.post_trip.is_empty(), "the brewer closes up and goes home at night")
	check(not (found.seat.mug as Node3D).visible, "the mug is cleared away")
	check(VillagePosts.locked(lvl, found.rec), "the tavern is locked without its keeper")
	_end()


func _end() -> void:
	if failures == 0:
		print("PASS: tavern_brewer")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
