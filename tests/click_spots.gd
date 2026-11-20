extends SceneTree
## Headless test for the small click spots of beds and workbenches (see Level.station_clicked):
## a click opens a bench only on the middle of its top and a bed only on its pillows, not anywhere
## on them; running into them along a clicked path does not open them either, while running into
## them by the keys still does; and the benches and bed of a self-built house have their spots
## on their own tops. Key E beside a bench or bed uses it.
## Run with: godot --headless --fixed-fps 60 -s tests/click_spots.gd

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


## Clicks the screen where `target` shows with the game's camera looking down at it as in play,
## and returns the station the click walks to ({} for none).
func _click_at(target: Vector3) -> Dictionary:
	var cam: Camera3D = game.camera
	cam.global_position = target + Vector3(0, 14, 9)
	cam.look_at(target)
	var screen := cam.unproject_position(target)
	var point = game._mouse_to_floor(screen)
	game._pending_station = {}
	game._click(point)
	var picked: Dictionary = game._pending_station
	game._pending_station = {}
	game.player.path.clear()
	return picked


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var lvl: Level = game.level
	var benches: Array = lvl.stations.filter(func(s): return s.kind == "werkbank")
	check(benches.size() >= 3, "the crafting square has its benches")
	for b in benches:
		check(b.has("spot"), "the %s bench has a click spot" % b.craft)
		if not b.has("spot"):
			continue
		check(absf(b.spot.y - 0.98) < 0.05, "the spot is on the bench top")
		check(_click_at(b.spot) == b, "a click on the middle of the %s bench opens it" % b.craft)
		check(_click_at(b.spot + Vector3(0, 0, 1.05)) != b, "a click on an end of the %s bench does not" % b.craft)
		check(_click_at(b.pos + Vector3(0.9, 0, 0)) != b, "a click on the floor in front of the %s bench does not" % b.craft)

	# Beds: a dungeon bed, turned to its room, has its spot on the pillows at its head.
	var pos := Vector3(10, 0, 20)
	for rot in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var foot := Vector3(sin(rot), 0, cos(rot))
		var spot := Level.pillow_spot(pos, rot)
		check(foot.dot(spot - pos) < -0.9, "the pillows lie at the head of a bed turned %.1f" % rot)
		var bed := {"kind": "bett", "cell": lvl.world_to_cell(pos), "pos": pos, "rot": rot, "used": false, "spot": spot}
		lvl.stations.append(bed)
		check(_click_at(spot) == bed, "a click on the pillows opens the bed")
		check(_click_at(pos + foot * 0.6 + Vector3(0, 0.85, 0)) != bed, "a click on the blanket does not")
		check(_click_at(pos + foot * 1.4 + Vector3(0, 0.7, 0)) != bed, "a click on the foot of the bed does not")
		lvl.stations.erase(bed)

	# Running into a bench: not on the way somewhere clicked, but by the keys.
	var bench: Dictionary = benches[0]
	var p: Player = game.player
	game.menus.close()
	p.path = [bench.pos + Vector3(5, 0, 0)]
	game._on_player_bumped(bench.pos)
	check(game.menus.current == "", "running into a bench along a clicked path opens nothing")
	p.path.clear()
	p.steer = Vector3(-1, 0, 0)
	game._on_player_bumped(bench.pos)
	check(game.menus.current == "", "running into it steered by the held mouse opens nothing")
	p.steer = Vector3.ZERO
	p.global_position = bench.pos + Vector3(1.2, 0, 0)
	game._on_player_bumped(bench.pos)
	check(game.menus.current == "werkbank", "running into it by the keys opens it (opened %s)" % game.menus.current)
	game.menus.close()
	check(game._use_spot_station_by_key() and game.menus.current == "werkbank", "key E beside the bench opens it")
	game.menus.close()

	# The pieces of a self-built house: every bench's spot is on its top, the bed's on its pillows.
	var furnisher: HouseFurnisher = game.house_furnisher
	if furnisher == null:
		furnisher = HouseFurnisher.new()
		furnisher.game = game
	for kind in ["bett", "werkbank", "feinbank", "schleifrad", "alchemie"]:
		var piece := Node3D.new()
		lvl.add_child(piece)
		var station: Dictionary = furnisher.build_piece(piece, kind)
		check(station.has("spot"), "the house's %s has a click spot" % kind)
		if station.has("spot"):
			var box: Dictionary = piece.get_meta("solids")[0]
			var inside: bool = absf(station.spot.x - box.at.x) < box.size.x * 0.5 and absf(station.spot.z - box.at.z) < box.size.z * 0.5
			check(inside, "the spot of the house's %s is over it (%s)" % [kind, station.spot])
			check(station.spot.y > 0.6 and station.spot.y < 1.2, "the spot of the house's %s is at its top" % kind)
		piece.queue_free()
	check(furnisher.build_piece(Node3D.new(), "feinbank").spot.distance_to(Vector3(0, 0.98, -0.2)) < 0.01,
			"a house bench's spot is the middle of its top, turned with it")

	if failures == 0:
		print("PASS: click spots")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
