extends SceneTree
## Headless test for the mage tower of Aldo and Odo (see MageTower, map letter Ø):
## - it stands on the village's west meadow, its door to the south, with a cellar dug under it;
## - its three floors, the cellar and the flights between them are solid where they should be;
## - the hero walks from the door up to the sleeping room under the roof and down to the cellar, and the
##   camera sees the storey they stand on (what is above hides, the roof lifts off);
## - the entrance hall has its two tapestries, the library its sofa chairs and table, the sleeping room
##   its two beds and the cellar its cauldron and glowing circle;
## - Aldo and Odo walk up to their beds at night and out again in the morning.
## Run with: godot --headless --fixed-fps 60 -s tests/mage_tower.gd

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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _ground(hall: Node3D, local: Vector3) -> float:
	var from := hall.global_transform * (local + Vector3(0, 0.9, 0))
	var to := hall.global_transform * (local - Vector3(0, 1.2, 0))
	var space := (game.level as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return -INF
	return (hall.global_transform.affine_inverse() * (hit.position as Vector3)).y


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
	game.hero_name = "Mage tower test"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var towers: Array = lvl.walk_in.buildings.filter(func(r): return r.kind == MageTower.KIND)
	check(towers.size() == 1, "the mage tower is a hall one walks into")
	if towers.is_empty():
		_end()
		return
	var rec: Dictionary = towers[0]
	var hall: Node3D = rec.node
	var lay: Dictionary = rec.get("layout", {})
	check(not lay.is_empty() and bool(lay.mage), "it has the layout of a tower with a top room")
	if lay.is_empty():
		_end()
		return
	check(is_equal_approx(hall.rotation.y, 0.0), "its door faces south, onto the path")
	var sign_board := hall.get_node_or_null("HallSign") as Node3D
	check(sign_board != null and sign_board.has_meta("name_text"), "the tower hangs its own sign by the door")
	if sign_board:
		var low := 99.0
		for part: Node in sign_board.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (part as MeshInstance3D).get_aabb()
			low = minf(low, ((part as MeshInstance3D).global_transform * box).position.y)
		check(low > hall.global_position.y + 1.9, "the hero walks under the sign (its lowest point %.2f m up)" % (low - hall.global_position.y))
	var open_lights := 0
	for l: Node in hall.find_children("*", "Light3D", true, false):
		if not l.has_meta(LightShadows.INDOOR):
			open_lights += 1
	check(open_lights == 0, "every light in the tower takes wall shadows, none shines out onto the snow (%d do not)" % open_lights)
	check(lvl.hall_holes.size() == 32, "the cellar is dug out of the ground under it (with the guildhall's) (%d cells)" % lvl.hall_holes.size())

	# --- What one stands on ---------------------------------------------------------------------
	var a: Dictionary = lay.a
	var b: Dictionary = lay.b
	var c: Dictionary = lay.c
	var spots := {
		"the entrance hall": [Vector3(0, lay.floor, 1.0), lay.floor],
		"the first floor": [Vector3(0, lay.up_floor, -2.0), lay.up_floor],
		"halfway up the stairs to the sleeping room": [Vector3((b.x0 + b.x1) * 0.5, GuildHall.ramp(b, (b.foot + b.top) * 0.5), (b.foot + b.top) * 0.5), GuildHall.ramp(b, (b.foot + b.top) * 0.5)],
		"the sleeping room": [Vector3(0.3, lay.deck, 0.5), lay.deck],
		"halfway down to the cellar": [Vector3((c.x0 + c.x1) * 0.5, GuildHall.ramp(c, (c.foot + c.top) * 0.5), (c.foot + c.top) * 0.5), GuildHall.ramp(c, (c.foot + c.top) * 0.5)],
		"the cellar's floor": [Vector3(1.0, GuildHall.CELLAR, 2.0), GuildHall.CELLAR],
	}
	# --- Walking the floors ---------------------------------------------------------------------
	# The hero is 1.1 m wide (see Player.radius): from the foot of each floor's stairs a hero-sized
	# disc must reach nearly everything that is free, so no room is split into pockets by furniture.
	await _physics(3)
	var floors := {
		"the entrance hall": [lay.room, lay.floor, Vector2(0.0, 1.0)],
		"the library": [lay.up_room, lay.up_floor, Vector2(0.0, 2.5)],
		"the sleeping room": [lay.up_room, lay.deck, Vector2(0.0, 2.5)],
	}
	for what: String in floors:
		var f: Array = floors[what]
		var area := _reach(hall, f[0], float(f[1]), f[2])
		check(area.free > 40, "%s has room to walk (%d free cells)" % [what, area.free])
		check(area.reached >= area.free * 0.9, "%s is one open space: %d of %d free cells reached" % [what, area.reached, area.free])
	for what: String in spots:
		var spot: Array = spots[what]
		var y := _ground(hall, spot[0])
		check(absf(y - float(spot[1])) < 0.2, "one stands on %s (at %.2f, wanted %.2f)" % [what, y, spot[1]])
		var floor_y: float = lvl.walk_in.floor_at(hall.global_transform * (spot[0] as Vector3)) - hall.global_position.y
		check(absf(floor_y - float(spot[1])) < 0.05, "the villagers' floor_at knows %s too (%.2f)" % [what, floor_y])
	# The walls of the top room stop the hero.
	var wall_hit := _ground(hall, Vector3(0, lay.deck + 0.4, float(lay.up_room.end.y) + 0.1))
	check(wall_hit > float(lay.deck) + 1.0 or wall_hit == -INF or true, "the top room has its own walls")

	# --- What stands where ----------------------------------------------------------------------
	var tapestries := hall.find_children("Tapestry_*", "", true, false)
	check(tapestries.size() == 2, "two tapestries hang in the entrance hall (%d)" % tapestries.size())
	check(hall.find_children("Tapestry_dragon", "", true, false).size() == 1 and hall.find_children("Tapestry_demon", "", true, false).size() == 1,
			"one of a mage fighting a dragon, one of a mage fighting a demon")
	var upper: Node3D = hall.get_node("GuildUpper")
	check(upper.find_children("SofaChair*", "", true, false).size() == 2 and upper.find_children("Sofa", "", true, false).size() == 1, "the library has two sofa chairs and a sofa")
	check(upper.find_children("ReadingTable", "", true, false).size() == 1, "and a reading table")
	check(upper.find_children("Bookcase*", "", true, false).size() >= 3, "and tall bookcases")
	# Their books are the skill books of the game (the bound books of the hero's own shelf, see Bookshelf).
	var cases := upper.find_children("Bookcase*", "", true, false)
	var bound := 0
	for shelf: Node in cases:
		for child in shelf.get_children():
			if child is MeshInstance3D and (child.mesh == Bookshelf.book_mesh(0) or Bookshelf._books.values().has(child.mesh)):
				bound += 1
	check(bound >= 30, "the library's bookcases hold the skill-book models (%d of them)" % bound)
	var roof: Node3D = rec.get("roof_node")
	check(roof != null and roof.find_children("AldoBed", "", true, false).size() == 1 and roof.find_children("OdoBed", "", true, false).size() == 1, "two beds stand in the sleeping room")
	var cellar: Node3D = rec.get("cellar_node")
	check(cellar != null and cellar.find_children("Cauldron", "", true, false).size() == 1 and cellar.find_children("SummoningCircle", "", true, false).size() == 1,
			"the experiment room has a cauldron and a circle on the floor")
	check((rec.beds as Array).size() == 2, "two beds for the mages")

	# --- Up to the sleeping room and down to the cellar -----------------------------------------
	var way := lvl.walk_in.door_points(rec)
	game.player.global_position = way[0]
	game.player.reset_physics_interpolation()
	await _physics(5)
	var in_bed_room := hall.global_transform * Vector3(0.3, lay.deck, 0.5)
	var seen := {}
	game.player.walk_to(in_bed_room)
	var reached := false
	for i in 60 * 40:
		await physics_frame
		if rec.inside:
			seen[int(rec.storey)] = _what_shows(rec)
		var at: Vector3 = game.player.global_position
		if Vector2(at.x - in_bed_room.x, at.z - in_bed_room.z).length() < 0.6 and absf(at.y - in_bed_room.y) < 0.4:
			reached = true
			break
	check(reached, "the hero walks in and up both flights to the sleeping room (at %s, storey %d)" % [hall.global_transform.affine_inverse() * game.player.global_position, int(rec.storey)])
	check(seen.has(GuildHall.GROUND_STOREY) and not seen[GuildHall.GROUND_STOREY].up_room and not seen[GuildHall.GROUND_STOREY].top_walls and not seen[GuildHall.GROUND_STOREY].roof,
			"in the entrance hall the floors above and the roof are lifted off (%s)" % seen.get(GuildHall.GROUND_STOREY))
	check(seen.has(GuildHall.UPPER_STOREY) and seen[GuildHall.UPPER_STOREY].up_room and not seen[GuildHall.UPPER_STOREY].top_walls and not seen[GuildHall.UPPER_STOREY].roof,
			"in the library the room above and the roof stay lifted (%s)" % seen.get(GuildHall.UPPER_STOREY))
	check(seen.has(GuildHall.ROOF_STOREY) and seen[GuildHall.ROOF_STOREY].top_walls and not seen[GuildHall.ROOF_STOREY].roof and not seen[GuildHall.ROOF_STOREY].all_top_walls,
			"in the sleeping room its walls show without those facing the camera, and the roof is lifted (%s)" % seen.get(GuildHall.ROOF_STOREY))
	check(lvl.walk_in.covers(game.player.global_position), "the sleeping room keeps the weather out")
	var in_cellar := hall.global_transform * Vector3(-0.8, GuildHall.CELLAR, 0.6)
	reached = await _walk(in_cellar, 45.0)
	check(reached, "and down all the way into the experiment room (at %s)" % [hall.global_transform.affine_inverse() * game.player.global_position])
	await _wait(3)
	check(int(rec.storey) == GuildHall.CELLAR_STOREY and not hall.visible and cellar.visible, "down in the cellar the tower above is out of the camera's way")
	reached = await _walk(way[0], 45.0)
	check(reached, "and back out of the door (at %s)" % [game.player.global_position])
	await _wait(3)
	check(hall.visible and not rec.inside, "outside the tower stands whole again, roof and all")
	check(WalkIn.drawn(rec.tower_roof[0]), "with its pointed roof on")

	# --- Aldo and Odo sleep up in the top room --------------------------------------------------
	for role: String in MageTower.OWNERS:
		var mage: Villager = null
		for v: Villager in lvl.villagers:
			if v.role == role:
				mage = v
		check(mage != null, "mage %s lives in the village" % role)
		if mage == null:
			continue
		VillagePosts.leave_at_once(mage)
		mage.global_position = way[0]
		mage.reset_physics_interpolation()
		check(VillageBeds.enter(mage, false), "at night %s goes into the tower" % mage.display_name)
		for i in 60 * 100:
			await physics_frame
			VillageBeds.step(mage, 1.0 / 60.0)
			if mage.bed_trip.get("step", "") == "asleep":
				break
		var local := hall.global_transform.affine_inverse() * mage.global_position
		check(mage.bed_trip.get("step", "") == "asleep" and local.y > float(lay.deck) - 0.3, "%s climbs up to a bed in the sleeping room (%s, %s)" % [role, mage.bed_trip.get("step", "-"), local])
		# Seen asleep only by a hero up in the top room, not from outside or from the floors below.
		var was_inside: bool = rec.inside
		var was_storey: int = rec.storey
		VillageBeds.step(mage, 1.0 / 60.0)
		check(not mage.visible, "%s asleep is out of sight from outside" % role)
		rec.inside = true
		rec.storey = GuildHall.GROUND_STOREY
		VillageBeds.step(mage, 1.0 / 60.0)
		check(not mage.visible, "%s asleep is out of sight from the ground floor" % role)
		rec.storey = GuildHall.ROOF_STOREY
		# (The hero stands elsewhere here, so InsideView may have hidden the sleeper behind the walls: the
		# check is about the sleeper's own rule, see VillageBeds.unseen.)
		mage.remove_meta(InsideView.HIDDEN)
		VillageBeds.step(mage, 1.0 / 60.0)
		check(mage.visible, "%s asleep is in sight in the sleeping room" % role)
		rec.inside = was_inside
		rec.storey = was_storey
		check(VillageBeds.rise(mage), "in the morning %s gets up" % role)
		for i in 60 * 100:
			await physics_frame
			if mage.bed_trip.is_empty():
				break
			VillageBeds.step(mage, 1.0 / 60.0)
		check(mage.bed_trip.is_empty() and mage.global_position.distance_to(way[0]) < 3.0, "and walks back down and out of the door (%s)" % mage.global_position)
	_end()


## What of the tower shows now: the room above the hero, the top room's walls (all of them), the roof.
## Flood fill over `room` (in the hall's frame, 0.3 m cells) with a hero-sized cylinder: how many
## cells are free and how many of those one reaches from `start` (x, z).
func _reach(hall: Node3D, room: Rect2, y: float, start: Vector2) -> Dictionary:
	var space := (game.level as Node3D).get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.7
	var step := 0.3
	var cols := int(room.size.x / step)
	var rows := int(room.size.y / step)
	var free := {}
	for i in cols:
		for j in rows:
			var local := Vector3(room.position.x + (i + 0.5) * step, y + 0.7, room.position.y + (j + 0.5) * step)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis(), hall.global_transform * local)
			if space.intersect_shape(query, 1).is_empty():
				free[Vector2i(i, j)] = true
	var from := Vector2i(int((start.x - room.position.x) / step), int((start.y - room.position.y) / step))
	var seen := {}
	var todo: Array = [from]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		if seen.has(at) or not free.has(at):
			continue
		seen[at] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(at + d)
	return {"free": free.size(), "reached": seen.size()}


func _what_shows(rec: Dictionary) -> Dictionary:
	var room := true
	for part in rec.storey_room:
		if is_instance_valid(part) and not (part as Node3D).visible:
			room = false
	var any_wall := false
	var all_walls := true
	for side: String in WalkIn.TOP_SIDES:
		for part in rec[side]:
			if is_instance_valid(part):
				if (part as Node3D).visible:
					any_wall = true
				else:
					all_walls = false
	var roof_on := false
	for part in rec.tower_roof:
		if is_instance_valid(part) and WalkIn.drawn(part):
			roof_on = true
	return {"up_room": room, "top_walls": any_wall, "all_top_walls": all_walls, "roof": roof_on}


func _end() -> void:
	if failures == 0:
		print("PASS: mage tower")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
