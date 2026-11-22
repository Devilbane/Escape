extends SceneTree
## Headless test for the guildhall one walks through on all its storeys (see GuildHall):
## - it is two storeys of the village's style under a flat roof, with a cellar dug under it;
## - its floors, flights of stairs and railings are solid where they should be: one stands on the
##   ground floor, the steps, the upper floor, the deck of the roof and the cellar's floor;
## - the hero walks from the door up both flights onto the roof, down again and into the cellar,
##   and the camera sees the storey they stand on (what is above it hides);
## - the roof has its training ground (mat, dummies, rack, two ballistas), the cellar Ragna's bed;
## - up on the roof the weather falls on the hero, in the cellar it does not;
## - at night Ragna walks down to her bed in the cellar, and in the morning back out of the door.
## Run with: godot --headless --fixed-fps 60 -s tests/guild_hall.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


## The height of the floor one would stand on at `local` (the hall's frame), looking down from a
## little over `local.y`.
func _ground(hall: Node3D, local: Vector3) -> float:
	var from := hall.global_transform * (local + Vector3(0, 0.9, 0))
	var to := hall.global_transform * (local - Vector3(0, 1.2, 0))
	var space := (game.level as Node3D).get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -INF
	return (hall.global_transform.affine_inverse() * (hit.position as Vector3)).y


## Walks the hero to `target` (world) along WalkIn's way, for at most `seconds`; true once there.
func _walk(target: Vector3, seconds: float) -> bool:
	game.player.walk_to(target)
	for i in int(seconds * 60.0):
		await physics_frame
		var at: Vector3 = game.player.global_position
		if Vector2(at.x - target.x, at.z - target.z).length() < 0.5 and absf(at.y - target.y) < 0.4:
			return true
	return false


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Guild test"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var halls: Array = lvl.walk_in.buildings.filter(func(r): return r.kind == "guild")
	check(halls.size() == 1, "the guildhall is a hall one walks into")
	if halls.is_empty():
		_end()
		return
	var rec: Dictionary = halls[0]
	var hall: Node3D = rec.node
	var lay: Dictionary = rec.get("layout", {})
	check(not lay.is_empty() and bool((hall.get_meta("shape") as Dictionary).get("flat", false)), "it has two storeys under a flat roof")
	if lay.is_empty():
		_end()
		return

	# --- The cellar's hole in the ground --------------------------------------------------------
	check(lvl.hall_holes.size() == 16, "the cellar is dug out of the ground under the hall (%d cells)" % lvl.hall_holes.size())
	var view: CellarView = game.house_sketcher.cellar_view if game.house_sketcher != null else null
	if view != null:
		check(lvl.hall_holes.all(func(r): return view.holes.has(r)), "the cellar is one of the cellars the hero can go down into")

	# --- What one stands on ---------------------------------------------------------------------
	var a: Dictionary = lay.a
	var b: Dictionary = lay.b
	var c: Dictionary = lay.c
	var spots := {
		"the ground floor": [Vector3(0, lay.floor, 1.0), lay.floor],
		"halfway up the stairs to the upper floor": [Vector3((a.x0 + a.x1) * 0.5, GuildHall.ramp(a, (a.foot + a.top) * 0.5), (a.foot + a.top) * 0.5), GuildHall.ramp(a, (a.foot + a.top) * 0.5)],
		"the upper floor": [Vector3(0, lay.up_floor, -2.0), lay.up_floor],
		"halfway up the stairs to the roof": [Vector3((b.x0 + b.x1) * 0.5, GuildHall.ramp(b, (b.foot + b.top) * 0.5), (b.foot + b.top) * 0.5), GuildHall.ramp(b, (b.foot + b.top) * 0.5)],
		"the deck of the roof": [Vector3(-1.5, lay.deck, 2.5), lay.deck],
		"halfway down to the cellar": [Vector3((c.x0 + c.x1) * 0.5, GuildHall.ramp(c, (c.foot + c.top) * 0.5), (c.foot + c.top) * 0.5), GuildHall.ramp(c, (c.foot + c.top) * 0.5)],
		"the cellar's floor": [Vector3(1.0, GuildHall.CELLAR, 2.0), GuildHall.CELLAR],
	}
	for what: String in spots:
		var spot: Array = spots[what]
		var y := _ground(hall, spot[0])
		check(absf(y - float(spot[1])) < 0.2, "one stands on %s (at %.2f, wanted %.2f)" % [what, y, spot[1]])
		var floor_y: float = lvl.walk_in.floor_at(hall.global_transform * (spot[0] as Vector3)) - hall.global_position.y
		check(absf(floor_y - float(spot[1])) < 0.05, "the villagers' floor_at knows %s too (%.2f)" % [what, floor_y])
	# The openings are open: nothing to stand on over the flights' upper ends but their steps.
	var over_well := _ground(hall, Vector3((c.x0 + c.x1) * 0.5, lay.floor, c.top + 1.5))
	check(over_well < float(lay.floor) - 0.5, "the stairs down open through the ground floor (%.2f)" % over_well)

	# --- What stands where ----------------------------------------------------------------------
	var roof: Node3D = rec.get("roof_node")
	check(roof != null and roof.find_children("TrainingMat", "", true, false).size() == 1, "a large training mat lies on the roof")
	check(roof != null and roof.find_children("*Dummy*", "", true, false).size() >= 2, "straw dummies stand on the roof")
	check(roof != null and roof.find_children("WeaponRack", "", true, false).size() == 1, "a rack of weapons stands on the roof")
	check(roof != null and roof.find_children("*GuildBallista*", "", true, false).size() == 2, "two ballistas look out over the parapet")
	var cellar: Node3D = rec.get("cellar_node")
	check(cellar != null and cellar.find_children("GuildMasterBed", "", true, false).size() == 1, "Ragna's bed stands in the cellar")
	check(cellar != null and cellar.find_children("Bookcase", "", true, false).size() == 1 and cellar.find_children("*Rack*", "", true, false).size() == 1, "and her furniture (a wardrobe, a rack of her blades)")
	check(hall.get_node_or_null("GuildUpper") != null and hall.get_node("GuildUpper").find_children("MapTable", "", true, false).size() == 1, "the map room upstairs has its table")

	# --- Up to the roof and down to the cellar ------------------------------------------------
	var way := lvl.walk_in.door_points(rec)
	game.player.global_position = way[0]
	game.player.reset_physics_interpolation()
	await _physics(5)
	var on_deck := hall.global_transform * Vector3(-2.5, lay.deck, -2.5)
	var seen := {}
	game.player.walk_to(on_deck)
	var reached := false
	for i in 60 * 40:
		await physics_frame
		if rec.inside:
			seen[int(rec.storey)] = _what_shows(rec)
		var at: Vector3 = game.player.global_position
		if Vector2(at.x - on_deck.x, at.z - on_deck.z).length() < 0.6 and absf(at.y - on_deck.y) < 0.4:
			reached = true
			break
	check(reached, "the hero walks in and up both flights onto the roof (at %s, storey %d)" % [hall.global_transform.affine_inverse() * game.player.global_position, int(rec.storey)])
	check(seen.has(GuildHall.GROUND_STOREY) and not seen[GuildHall.GROUND_STOREY].up_room and not seen[GuildHall.GROUND_STOREY].roof,
			"on the ground floor the storey above and the roof are lifted off (%s)" % seen.get(GuildHall.GROUND_STOREY))
	check(seen.has(GuildHall.UPPER_STOREY) and seen[GuildHall.UPPER_STOREY].up_room and not seen[GuildHall.UPPER_STOREY].roof and not seen[GuildHall.UPPER_STOREY].all_walls,
			"on the upper floor it shows without its walls facing the camera, the roof lifted off (%s)" % seen.get(GuildHall.UPPER_STOREY))
	check(seen.has(GuildHall.ROOF_STOREY) and seen[GuildHall.ROOF_STOREY].roof and seen[GuildHall.ROOF_STOREY].up_room,
			"on the roof everything shows (%s)" % seen.get(GuildHall.ROOF_STOREY))
	check(not lvl.walk_in.covers(game.player.global_position), "up on the roof the weather falls on the hero")
	var in_cellar := hall.global_transform * Vector3(-0.8, GuildHall.CELLAR, 0.6)
	reached = await _walk(in_cellar, 45.0)
	check(reached, "and down all the way into the cellar (at %s)" % [hall.global_transform.affine_inverse() * game.player.global_position])
	await _wait(3)
	check(int(rec.storey) == GuildHall.CELLAR_STOREY and not hall.visible and cellar.visible, "down in the cellar the hall above is out of the camera's way")
	check(lvl.walk_in.covers(game.player.global_position), "the cellar is out of the weather")
	if view != null:
		check(view.active, "and the cellar shows as one under the ground (see CellarView)")
	reached = await _walk(way[0], 40.0)
	check(reached, "and back out of the door (at %s)" % [game.player.global_position])
	await _wait(3)
	check(hall.visible and not rec.inside, "outside the hall stands whole again")

	# --- Ragna sleeps in the cellar -------------------------------------------------------------
	var ragna: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == VillageHalls.KEEPERS.guild:
			ragna = v
	check(ragna != null, "Guild Master Ragna lives in the village")
	if ragna != null:
		VillagePosts.leave_at_once(ragna)
		ragna.global_position = way[0]
		ragna.reset_physics_interpolation()
		check(VillageBeds.enter(ragna, false), "at night she goes into the guildhall")
		for i in 60 * 40:
			await physics_frame
			VillageBeds.step(ragna, 1.0 / 60.0)
			if ragna.bed_trip.get("step", "") == "asleep":
				break
		var local := hall.global_transform.affine_inverse() * ragna.global_position
		check(ragna.bed_trip.get("step", "") == "asleep" and local.y < -1.5, "she walks down to her bed in the cellar and sleeps (%s, %s)" % [ragna.bed_trip.get("step", "-"), local])
		check(VillageBeds.rise(ragna), "in the morning she gets up")
		for i in 60 * 40:
			await physics_frame
			if ragna.bed_trip.is_empty():
				break
			VillageBeds.step(ragna, 1.0 / 60.0)
		check(ragna.bed_trip.is_empty() and ragna.global_position.distance_to(way[0]) < 1.5, "and walks back up and out of the door (%s)" % ragna.global_position)
	_end()


## What of the hall shows now: the upper storey's room, all its walls, the roof.
func _what_shows(rec: Dictionary) -> Dictionary:
	var all_walls := true
	for side: String in WalkIn.UP_SIDES:
		for part in rec[side]:
			if is_instance_valid(part) and not (part as Node3D).visible:
				all_walls = false
	var room := true
	for part in rec.up_room:
		if is_instance_valid(part) and not (part as Node3D).visible:
			room = false
	var roof: Node3D = rec.roof_node
	return {"up_room": room, "all_walls": all_walls, "roof": roof.visible}


func _end() -> void:
	if failures == 0:
		print("PASS: guild hall")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
