extends SceneTree
## Headless test for the halls one can walk into (see VillageHalls, VillagePosts):
## - the tavern, the shop, the post office, the Crown office and the guildhall are timber houses now, each with a sign and a door in
##   the middle of its front, opened like the villagers' houses (walls, floor, door);
## - the hero walks in through the door; inside, the floor above and whichever walls face the camera
##   are hidden (the shop's door faces away, so its back wall hides and its front stays);
## - each hall has its counter and furniture, the shop and the tavern a place behind the counter;
## - by day each keeper (the shopkeeper, the clerk, the guild master) walks in through the door to
##   the place behind the counter or desk, the hero reaches them from in front of it, and at
##   nightfall they walk out again;
## - with a hall's switch off (WalkIn.halls) it is the old solid kit model again, and nothing else
##   in the village changes.
## Run with: godot --headless --fixed-fps 60 -s tests/village_halls.gd

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
	WalkIn.lock_halls = false # these tests walk into halls at any hour (see tests/village_halls.gd for the locks)
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


func _load_village() -> Outdoor:
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(5)
	return game.level


func _place(at: Vector3) -> void:
	var hero: Player = game.player
	hero.global_position = at
	hero.velocity = Vector3.ZERO
	hero.path.clear()
	hero.reset_physics_interpolation()


func _walk(dir: Vector3, seconds: float) -> void:
	var hero: Player = game.player
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	for k in int(seconds * 60.0):
		hero.path.clear()
		hero.path.append(hero.global_position + flat * 2.0)
		await physics_frame
	hero.path.clear()
	await _wait(2)


func _house_boxes(lvl: Outdoor) -> Array:
	var out := []
	for c in lvl.get_children():
		if c is Node3D and c.has_meta("village_house") and not c.has_meta("hall"):
			var box := AABB()
			var first := true
			for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", false, false):
				if mi.name == "WindowSpill" or mi.name == "WalkInside":
					continue
				var b: AABB = mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			out.append(box)
	return out


func _run() -> void:
	game.hero_name = "Hall test"
	game.escaped = true
	var hero: Player = game.player

	# --- The halls ----------------------------------------------------------------------
	var lvl := await _load_village()
	var walk_in: WalkIn = lvl.walk_in
	var halls := walk_in.buildings.filter(func(r): return VillageHalls.KINDS.values().has(r.kind))
	check(halls.size() == VillageHalls.KINDS.size(), "every hall can be walked into (%d)" % halls.size())
	var houses_on := _house_boxes(lvl)
	for rec in halls:
		var hall: Node3D = rec.node
		var kind: String = rec.kind
		if kind == MageTower.KIND:
			continue # The mages' tower has no counter and no keeper: tests/mage_tower.gd walks through it.
		check(rec.get("opened", false) and hall.has_meta("village_house"), "the %s is a timber house one walks into" % kind)
		check(hall.get_node_or_null("HallSign") != null, "the %s has its sign by the door" % kind)
		check(is_zero_approx(float((hall.get_meta("shape") as Dictionary).door_x)), "the %s's door is in the middle of its front" % kind)
		var inside_node := hall.get_node_or_null("HallInside")
		check(inside_node != null and (inside_node.get_node_or_null("Counter") != null or inside_node.get_node_or_null("Desk") != null), "the %s has its counter or desk" % kind)
		check(not (rec.get("posts", []) as Array).is_empty(), "the %s has a place behind its counter" % kind)
		for ch: String in VillageHalls.KINDS:
			if VillageHalls.KINDS[ch] == kind:
				check(not lvl.find_children("*", "Node3D", false, false).any(func(n): return n.has_meta("block") and n.get_meta("block") == rec.block and n != hall),
						"no kit model stands in the %s's block" % kind)

		# In through the door.
		var way := walk_in.door_points(rec)
		var in_dir := way[1] - way[0]
		in_dir.y = 0.0
		_place(way[0] - in_dir.normalized() * 1.5 + Vector3(0, 0.2, 0))
		await _wait(3)
		await _walk(in_dir, 2.5)
		check(walk_in.hero_in.get("node") == hall, "the hero walks into the %s (%s)" % [kind, hero.global_position])
		check(absf(hero.global_position.y - walk_in.floor_at(hero.global_position)) < 0.2, "onto the %s's floor" % kind)
		check(rec.up.all(func(p): return not is_instance_valid(p) or not WalkIn.drawn(p as Node3D)), "inside the %s its floor above and roof are hidden" % kind)
		var facing_cam := walk_in._faces_camera(rec, "front")
		for side: String in WalkIn.SIDES:
			var parts: Array = rec[side]
			var hidden := parts.all(func(p): return not is_instance_valid(p) or not (p as Node3D).visible)
			if walk_in._faces_camera(rec, side):
				check(hidden, "inside the %s, its %s wall (facing the camera) is hidden" % [kind, side])
			elif side == "front" or side == "back":
				check(not hidden, "inside the %s, its %s wall (facing away) stays" % [kind, side])
		if kind == "shop":
			check(not facing_cam, "the shop's door faces away from the camera, onto the square")
		check(lvl.is_sheltered(hero.global_position), "inside the %s the hero is out of the weather" % kind)
		# The counter stops the hero: walking on towards the back wall, they stay in front of it.
		var post: Dictionary = rec.posts[0]
		await _walk(in_dir, 3.0)
		var behind := Vector2(post.pos.x - hero.global_position.x, post.pos.z - hero.global_position.z).length()
		check(behind > 0.8, "the counter keeps the hero from its back (%.2f m from the keeper's place)" % behind)
		# Running into the counter may have spoken to its keeper behind it: close that window.
		game.menus.close()
		game.state = game.State.PLAYING
		await _walk(-in_dir, 4.0)
		check(walk_in.hero_in.is_empty(), "and out of the %s again (%s)" % [kind, hero.global_position])
		# (Unless the hero stands behind it, where it is lifted off so they show, see WalkIn._mind_cover.)
		var roof := (rec.node as Node3D).get_node_or_null("WalkRoof") as Node3D # (the first of its parts is a lid that stays hidden)
		check(bool(rec.get("roof_off", false)) or roof == null or WalkIn.drawn(roof), "outside again the %s's roof is back" % kind)

	# --- The keepers behind their counters and desks -------------------------------------
	var keepers := {}
	for kind: String in VillageHalls.KEEPERS:
		for v in lvl.villagers:
			if v.role == VillageHalls.KEEPERS[kind]:
				keepers[kind] = v
		check(keepers.has(kind), "the %s's keeper is in the village" % kind)
	var shop_rec: Dictionary = halls.filter(func(r): return r.kind == "shop")[0]
	_place(walk_in.door_points(shop_rec)[0] + Vector3(6, 0.2, 0))
	for i in 60 * 50:
		await physics_frame
		if keepers.values().all(func(v): return v.post_trip.get("step", "") == "at"):
			break
	await _wait(30)
	for kind: String in keepers:
		var keeper: Villager = keepers[kind]
		var rec: Dictionary = halls.filter(func(r): return r.kind == kind)[0]
		check(VillagePosts.post_of(keeper).get("rec", {}).get("node") == rec.node, "the %s is its keeper's hall" % kind)
		check(keeper.post_trip.get("step", "") == "at", "by day the %s's keeper walks in to the place behind the counter (%s, %s)" % [kind, keeper._task, keeper.global_position])
		check(walk_in.building_at(keeper.global_position).get("node") == rec.node, "the keeper is inside the %s" % kind)
		check(keeper.global_position.distance_to(rec.posts[0].pos) < 0.4, "behind the %s's counter" % kind)
		check(keeper.station.get("touch", 0.0) > 1.0, "the hero reaches the %s's keeper from in front of the counter" % kind)
		check(lvl.station_at(rec.posts[0].front) == keeper.station, "standing before the %s's counter the hero touches the keeper's station" % kind)
		check(VillagerPost.for_station(lvl, keeper.station) == "", "at their place in the %s its keeper deals" % kind)
		# Calm behind the counter: mostly standing idle, the hands busy only now and then.
		var busy := 0
		for i in 60 * 6:
			await physics_frame
			if keeper.work_anim() != "Idle" and keeper._anim.current_animation == keeper.work_anim():
				busy += 1
		check(busy < 60 * 4, "the %s's keeper stands calmly, busy only now and then (%d of 360 ticks)" % [kind, busy])
	# Nightfall: out of the door and home.
	game.day_hour = 22.0
	lvl.set_hour(22.0)
	for i in 60 * 20:
		await physics_frame
		if keepers.values().all(func(v): return v.post_trip.is_empty()):
			break
	for kind: String in keepers:
		var keeper: Villager = keepers[kind]
		check(keeper.post_trip.is_empty(), "at nightfall the %s's keeper walks out again (%s, %s)" % [kind, keeper._task, keeper.post_trip])
		check(walk_in.building_at(keeper.global_position).get("node") == null, "and is out of the %s (%s)" % [kind, keeper.global_position])
		# Outside it they send the hero there, closed for the night now (see VillagerPost.HALL_LINES).
		check(VillagerPost.for_station(lvl, keeper.station) == VillagerPost.hall_line(kind, true), "outside the %s at night its keeper says it is closed" % kind)
		var rec: Dictionary = halls.filter(func(r): return r.kind == kind)[0]
		var door_at := walk_in.door_points(rec)[0]
		var home_at := lvl.cell_to_world(keeper.home)
		check(not (rec.block as Rect2i).has_point(keeper.home) and Vector2(home_at.x - door_at.x, home_at.z - door_at.z).length() < Level.TILE * 2.5,
				"the %s's keeper has their place before its door (%s)" % [kind, keeper.home])
		check(Lang.EN.has(VillagerPost.hall_line(kind, false)) and Lang.EN.has(VillagerPost.hall_line(kind, true)), "English for the %s keeper's lines" % kind)
	# Locked doors: a hall whose keeper is not inside is locked, open while she is in it.
	WalkIn.lock_halls = true
	for kind: String in keepers:
		var rec: Dictionary = halls.filter(func(r): return r.kind == kind)[0]
		check(VillagePosts.locked(lvl, rec), "the %s is locked at night, its keeper out" % kind)
		keepers[kind].post_trip = {"rec": rec, "step": "at"}
		check(not VillagePosts.locked(lvl, rec), "the %s is open while its keeper is inside" % kind)
		keepers[kind].post_trip = {}
	WalkIn.lock_halls = false
	game.day_hour = 12.0
	lvl.set_hour(12.0)

	# --- The switches -----------------------------------------------------------------------
	for ch: String in VillageHalls.KINDS:
		WalkIn.halls[ch] = false
	lvl = await _load_village()
	check(lvl.walk_in.buildings.all(func(r): return not VillageHalls.KINDS.values().has(r.kind)), "switched off, no hall can be walked into")
	for ch: String in VillageHalls.KINDS:
		if VillageHalls.KINDS[ch] == MageTower.KIND:
			continue # The tower has no kit model to fall back to.
		var kit := lvl.get_children().filter(func(n): return n is Node3D and n.has_meta("block") and lvl.cell_char((n.get_meta("block") as Rect2i).position) == ch)
		check(kit.size() == 1 and not kit[0].has_meta("hall"), "switched off, the %s is the old kit model" % VillageHalls.KINDS[ch])
	var houses_off := _house_boxes(lvl)
	var same := houses_off.size() == houses_on.size()
	for i in mini(houses_off.size(), houses_on.size()):
		if not (houses_off[i] as AABB).is_equal_approx(houses_on[i]):
			same = false
	check(same, "switching the halls leaves every house as it was")
	for v in lvl.villagers:
		if VillageHalls.kept_by(v.role) != "":
			check(VillagePosts.post_of(v).is_empty(), "switched off, %s has no counter to go to" % v.role)
	for ch: String in VillageHalls.KINDS:
		WalkIn.halls[ch] = true

	game.delete_save(game.save_path())
	print("PASS: village halls" if failures == 0 else "FAILED: village halls (%d)" % failures)
	quit(1 if failures > 0 else 0)
