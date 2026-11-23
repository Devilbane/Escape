extends SceneTree
## Headless test: stepping out of a building the hero walked into is quick, because the open air
## is set aside while the hero is indoors and put back on the way out (see Game._park_outdoor).
## - Walking into a house of Weavers' Lane (the hero's home, claimed on the first visit) keeps the village out of the scene tree, not freed.
## - Stepping out puts the same village back, in a fraction of the time a fresh build takes,
##   with the hero in front of the door and every link of the map made once, not twice.
## - The farm animals are known again once the village is back (see FarmAnimal._all).
## - When something the village is built from changed indoors, it is built anew on the way out.
## Run with: godot --headless --fixed-fps 60 -s tests/house_exit_quick.gd

## The most a step out may take (a fresh build of the village takes many seconds).
const QUICK_MS := 1500

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
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: house exit quick")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## Walks in at the door of `station` and waits until the hero is indoors.
func _walk_in(station: Dictionary) -> void:
	game.state = game.State.PLAYING
	game.go_inside(station.building, station.house)
	for i in 240:
		await physics_frame
		if game.state == game.State.PLAYING and not game.level.outdoor:
			break


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(3)
	var station := {}
	for s in game.level.stations:
		if s.kind == "eingang" and s.building == "^":
			station = s
			break
	check(not station.is_empty(), "Weavers' Lane has a house door")
	if station.is_empty():
		_finish()
		return
	# The deeds live on disk: this hero gets the house to themself, and the deeds are put back after.
	var house: int = station.house
	var former := Homes.owner_of(house)
	game.hero_name = "Exittester"
	Homes.release(house)
	Homes.release(Homes.house_of(game.hero_name))
	# The first step into the house makes it the hero's home, and the village shows that: it is
	# built anew once. From then on it is set aside.
	await _walk_in(station)
	check(game.home_claimed, "the first step in makes the house home")
	game._leave_building()
	var village: Outdoor = game.level
	await _wait(3)
	var links: int = village.key_collected.get_connections().size()
	var killed: int = village.enemy_killed.get_connections().size()
	var animals := FarmAnimal._all.size()

	await _walk_in(station)
	check(not game.level.outdoor and game.level.is_home, "the door led into the house")
	check(is_instance_valid(village) and not village.is_inside_tree(), "the village waits out of the tree")
	check(game._parked == village, "the village is set aside, not freed")

	var t := Time.get_ticks_msec()
	game._leave_building()
	var took := Time.get_ticks_msec() - t
	print("step out with the village set aside: %d ms" % took)
	check(game.level == village and village.is_inside_tree(), "the same village is back")
	check(took < QUICK_MS, "stepping out is quick (%d ms)" % took)
	check(game._parked == null, "nothing is set aside any more")
	var door: Vector3 = village.doors["^" + str(house)]
	check(game.player.global_position.distance_to(door) < 0.5, "the hero stands in front of the door")
	check(village.key_collected.get_connections().size() == links, "the map's links are made once")
	check(village.enemy_killed.get_connections().size() == killed, "the horrors watch the map once")
	check(FarmAnimal._all.size() == animals, "the farm animals are known again (%d of %d)" % [FarmAnimal._all.size(), animals])
	check(is_instance_valid(game.plot_marker) and game.plot_marker.get_parent() == village, "the builder's tools are there again")
	await _wait(10)
	check(game.level == village and game.state == game.State.PLAYING, "the village plays on")

	# Something the village is built from changes indoors: it is built anew.
	await _walk_in(station)
	game.secrets_found += 1
	game._leave_building()
	game.secrets_found -= 1
	check(game.level is Outdoor and game.level != village, "a changed village is built anew")
	check(not is_instance_valid(game._parked), "the stale village is let go")
	await _wait(3)

	Homes.release(house)
	if former != "" and Homes.house_of(former) == 0:
		Homes.claim(former, house)
	_finish()
