extends SceneTree
## Headless test: the doors of the village houses swing open before anyone goes in.
## - Every village house (standalone and on Weavers' Lane) has a HouseDoor, shut at first.
## - A door swings open in OPEN_TIME, stays open a while and shuts again by itself.
## - Walking into a house of Weavers' Lane opens its door; the hero is not kept waiting
##   longer than the swing (the fade starts after OPEN_TIME).
## - A villager who comes home opens the door of the house, and gets out through it.
## Run with: godot --headless --fixed-fps 60 -s tests/house_doors.gd

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


func _finish() -> void:
	if failures == 0:
		print("PASS: house doors")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(2)
	var lvl: Outdoor = game.level

	var houses := lvl.get_children().filter(func(c): return c.has_meta("door_leaf"))
	check(houses.size() > 0, "the village has houses with doors")
	check(lvl.house_doors.size() == houses.size(), "every house door is known to the village (%d of %d)" % [lvl.house_doors.size(), houses.size()])
	for d: HouseDoor in lvl.house_doors:
		check(d.openness() == 0.0, "a door is shut at first")

	# The swing: open soon, shut again alone.
	var door: HouseDoor = lvl.house_doors[0]
	door.swing(0.3)
	await _wait(int((HouseDoor.OPEN_TIME + 0.1) * 60))
	check(door.is_open(), "the door is open after the swing")
	check(door.leaf.rotation.y < -1.0, "the door leaf turns out into the street")
	await _wait(int((0.3 + HouseDoor.CLOSE_TIME + 0.2) * 60))
	check(door.openness() == 0.0, "the door shuts again by itself")

	# A villager at a door opens it.
	check(lvl.swing_door_near(door.global_position + Vector3(0, 0, 1.0)), "a door near a point swings")
	check(not lvl.swing_door_near(Vector3(9999, 0, 9999)), "no door swings far from every house")
	await _wait(int((HouseDoor.OPEN_TIME + 0.1) * 60))
	check(door.is_open(), "the door swings for a villager coming home")
	await _wait(int((HouseDoor.HOLD + HouseDoor.CLOSE_TIME + 0.3) * 60))
	check(door.openness() == 0.0, "and shuts after them")

	# The hero walks into a house of Weavers' Lane.
	var station := {}
	for s in lvl.stations:
		if s.kind == "eingang" and s.building == "^" and s.has("leaf"):
			station = s
			break
	check(not station.is_empty(), "the doors of Weavers' Lane carry their leaf")
	if not station.is_empty():
		var leaf: HouseDoor = station.leaf
		game.state = game.State.PLAYING
		game.go_inside(station.building, station.house, leaf)
		await _wait(int((HouseDoor.OPEN_TIME + 0.1) * 60))
		check(game.state == game.State.TRANSITION, "the hero goes in")
		check(leaf.is_open(), "the door opens as the hero goes in")

	# A villager going home and coming out again.
	var v: Villager = lvl.villagers[0]
	var home_door: Vector3 = lvl.spots.houses[0]
	var home_leaf: HouseDoor = lvl.house_doors[0]
	for d: HouseDoor in lvl.house_doors:
		if d.global_position.distance_to(home_door) < home_leaf.global_position.distance_to(home_door):
			home_leaf = d
	v.global_position = home_door
	v.at_home = false
	v.visible = true
	v._hide_inside(true, true)
	check(v.at_home and v.visible, "a villager is still in the street while the door opens")
	await _wait(int((HouseDoor.OPEN_TIME + 0.1) * 60))
	check(home_leaf.is_open(), "the door of the house swings open for the villager")
	check(not v.visible, "the villager is indoors once it is open")
	v._hide_inside(false, true)
	check(v.visible and not v.at_home, "the villager steps out at once")

	_finish()
