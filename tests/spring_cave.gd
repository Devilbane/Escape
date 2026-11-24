extends SceneTree
## The cave behind the river's spring waterfall (see SpringCave): in summer there is no way to the porch;
## in winter the frozen fall is a wall of ice that only a climbing hammer in the hand breaks; the open
## doorway lasts until the thaw; the cave's map is built with its monsters and its way out.
## Run with: godot --headless -s tests/spring_cave.gd

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


func _stations(lvl: Outdoor, kind: String) -> Array:
	return lvl.stations.filter(func(s: Dictionary) -> bool: return s.kind == kind)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Cave test"
	await _wait(10)
	game.treasure_maps.state.erase(SpringCave.ID)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	var fall: Waterfall = lvl.waterfall
	check(fall != null, "the waterfall is built")
	if fall == null:
		quit(1)
		return
	var hero: Player = game.player
	hero.bag.clear()
	hero.equipped.erase("waffe")

	# Shut: a wall of ice and its station, no way in.
	check(is_instance_valid(fall.wall), "the fall stands over the porch as a wall")
	check(_stations(lvl, SpringCave.KIND).size() == 1 and _stations(lvl, SpringCave.PLUG).is_empty(), "the ice has its station, the rock none")
	check(not SpringCave.is_open(lvl), "the doorway is shut")
	check(lvl.doors.has(SpringCave.ID), "the cave has its door on the map")
	check(game.interiors.has(SpringCave.ID), "the cave's map is known (building: %s)" % SpringCave.ID)

	# Summer: nothing to break.
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	game._use_station(_stations(lvl, SpringCave.KIND)[0])
	check(not SpringCave.is_open(lvl), "in summer the water cannot be broken")

	# Winter, bare hands, then a hammer in the bag, then in the hand.
	game.ice_cover = 1.0
	lvl.set_ice(1.0)
	await _wait(5)
	game._use_station(_stations(lvl, SpringCave.KIND)[0])
	check(not SpringCave.is_open(lvl), "bare hands do not break the ice")
	hero.bag.append("kletterhammer")
	game._use_station(_stations(lvl, SpringCave.KIND)[0])
	check(not SpringCave.is_open(lvl), "a hammer in the bag does not break the ice")
	hero.equipped["waffe"] = "kletterhammer"
	game._use_station(_stations(lvl, SpringCave.KIND)[0])
	await create_timer(SpringCave.BREAK_TIME + 0.4).timeout
	check(SpringCave.is_open(lvl), "the hammer breaks a doorway in the ice")
	check(not is_instance_valid(fall.wall) or fall.wall.is_queued_for_deletion(), "the wall of ice is gone")
	check(_stations(lvl, SpringCave.KIND).is_empty() and _stations(lvl, SpringCave.PLUG).size() == 1, "the boulder with the wave has the station now")
	for mat in fall._curtains:
		check(float(mat.get_shader_parameter("hole")) > 0.5, "the curtain has a doorway")

	# The state is saved with the treasure maps.
	var saved: Dictionary = game.treasure_maps.for_save()
	game.treasure_maps.load_from(saved)
	check(SpringCave.is_open(lvl), "the open doorway is kept in the save")

	# The way out: on the porch in winter, on the shore in a thaw.
	var porch := SpringCave.exit_point(lvl, 1.0)
	var shore := SpringCave.exit_point(lvl, 0.0)
	check(porch.distance_to(fall.position) < 1.0, "in winter the hero comes out on the porch")
	check(shore.z > fall.position.z + Level.TILE * 3.0 and lvl.is_open(lvl.world_to_cell(shore)), "in a thaw the hero comes out on open ground in front of the pool")

	# The thaw shuts the doorway again.
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	check(not SpringCave.is_open(lvl), "the thaw takes the open doorway")
	check(is_instance_valid(fall.wall) and _stations(lvl, SpringCave.KIND).size() == 1, "the next frost finds a wall again")

	# The cave itself.
	game.go_inside(SpringCave.ID)
	await _wait(60)
	var cave: Level = game.level
	check(cave.building == SpringCave.ID and not cave is Outdoor, "the way leads into the spring cave")
	check(cave.enemies.size() >= 6, "monsters live in the cave (%d)" % cave.enemies.size())
	check(cave.respawn, "the monsters come back")
	check(HeroLevel.BUILDING_AREAS.get(SpringCave.ID, "") == "quelle", "the cave has its area")
	check(cave._has_cell("F") and cave._has_cell("K") and cave._has_cell("D"), "the cave has its fountain, its key and its locked door")

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: spring_cave")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
