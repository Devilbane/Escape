extends SceneTree
## Headless test: villagers go in and out of their houses through the door, and only where they have a bed.
## - Every villager who sleeps has a bed of their own at night: nobody is left at a door with no bed
##   behind it, and no bed holds two.
## - Mira, Bruno, Pip and Pippi (a family) sleep upstairs above the shop, in four beds.
## - Walking in at nightfall, Bruno, Pip and Pippi cross the doorway in line with its middle, the door
##   leaf open by then, are in sight while they do (no vanishing in the street), and the door shuts
##   behind them; in the morning they walk out the same way and the door is open for them.
## Run with: godot --headless --fixed-fps 60 -s tests/villager_doors.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("ok   ", what)


func _initialize() -> void:
	WalkIn.lock_halls = false
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
		await physics_frame


func _villager(lvl: Outdoor, role: String) -> Villager:
	for v: Villager in lvl.villagers:
		if v.role == role:
			return v
	return null


## Walks `v` for up to `seconds` (until `done` says stop) and reports how it crossed its door:
## {"crossed": bool, "open": leaf openness at the crossing, "off": metres from the middle of
## the doorway, "seen": visible while it crossed}.
func _crossing(lvl: Outdoor, v: Villager, seconds: float, done: Callable) -> Dictionary:
	var rec: Dictionary = v.bed_trip.get("house", {})
	var door: Vector3 = (rec.node as Node3D).global_transform * (rec.door as Vector3)
	var way := lvl.walk_in.door_points(rec)
	var out := Vector3(way[0].x - way[1].x, 0, way[0].z - way[1].z).normalized()
	var across := Vector3(-out.z, 0, out.x)
	var leaf: HouseDoor = rec.leaf
	var result := {"crossed": false, "open": 0.0, "off": 99.0, "seen": false}
	var last := (v.global_position - door).dot(out)
	for k in int(seconds * 60.0):
		await physics_frame
		var now := (v.global_position - door).dot(out)
		if (last > 0.0) != (now > 0.0) and not result.crossed:
			result.crossed = true
			result.open = leaf.openness()
			result.off = absf((v.global_position - door).dot(across))
			result.seen = v.visible
		last = now
		if done.call():
			break
	return result


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(5)
	var lvl: Outdoor = game.level
	for c in lvl.find_children("*", "CharacterBody3D", true, false):
		c.process_mode = Node.PROCESS_MODE_INHERIT

	# Everyone who sleeps has a bed; nobody shares one.
	for v: Villager in lvl.villagers:
		v.set_night(true, true)
	await _wait(5)
	var beds := {}
	for v: Villager in lvl.villagers:
		if not v.goes_to_bed():
			continue
		var bed: Dictionary = v.bed_trip.get("bed", {})
		# Gorm's bed stands in sight on his ground floor and Ragna's down in her cellar.
		var in_sight: bool = v.role == SmithCottage.OWNER or v.role == VillageHalls.KEEPERS.guild
		check(not bed.is_empty() and v.at_home and (in_sight or not v.visible), "%s sleeps in a bed of their own (%s)" % [v._info.get("name"), v.bed_trip.get("step", "-")])
		if not bed.is_empty():
			check(not beds.has(bed.pos), "%s's bed holds nobody else" % v._info.get("name"))
			beds[bed.pos] = true
	for role in ["6", "3", "7", "pippi"]:
		var v := _villager(lvl, role)
		check(v != null and v.bed_trip.get("house", {}).get("kind", "") == "shop", "%s sleeps above the shop" % role)
	for v: Villager in lvl.villagers:
		v.set_night(false, true)
	await _wait(60 * 90)
	check(lvl.villagers.all(func(v): return v.bed_trip.is_empty()), "in the morning everyone is out of bed")

	# In through the door, one after the other.
	for role in ["3", "7", "pippi"]:
		var v := _villager(lvl, role)
		var home: Vector3 = v.house_door()
		v.global_position = home + Vector3(0, 0, 6.0)
		v.reset_physics_interpolation()
		v.set_night(true, false)
		# Wait for the walk to the door and the first step of the trip.
		for k in 60 * 40:
			await physics_frame
			if not v.bed_trip.is_empty():
				break
		check(not v.bed_trip.is_empty(), "%s walks to the door of their house" % role)
		check(v.visible and v.bed_trip.get("house", {}).get("kind", "") == "shop", "%s is still in the street when the trip begins" % role)
		var r := await _crossing(lvl, v, 30.0, func(): return String(v.bed_trip.get("step", "")) in ["climb", "upstairs"])
		check(r.crossed, "%s walks through the doorway" % role)
		check(r.open > 0.6, "%s finds the door open (%.2f)" % [role, r.open])
		check(r.off < 0.45, "%s crosses it in line with its middle (%.2f m off)" % [role, r.off])
		check(r.seen, "%s is in sight in the doorway" % role)
		for k in 60 * 30:
			await physics_frame
			if String(v.bed_trip.get("step", "")) == "upstairs":
				break
		check(String(v.bed_trip.get("step", "")) == "upstairs", "%s is in bed upstairs" % role)
		var leaf: HouseDoor = v.bed_trip.house.leaf
		await _wait(int((HouseDoor.CLOSE_TIME + 1.6) * 60))
		check(leaf.openness() == 0.0, "the door is shut behind %s" % role)
		# And out again in the morning.
		v.set_night(false, true)
		var out := await _crossing(lvl, v, 90.0, func(): return v.bed_trip.is_empty() and v.visible)
		check(out.crossed, "%s walks out through the doorway" % role)
		check(out.open > 0.6 and out.off < 0.45, "%s finds it open and crosses in line (%.2f open, %.2f off)" % [role, out.open, out.off])
		check(v.visible and not v.at_home and v.global_position.y < 0.3, "%s is out in the street" % role)

	if failures == 0:
		print("PASS: villager doors")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
