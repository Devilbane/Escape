extends SceneTree
## Headless test for the halls one can walk into (see VillageHalls, VillagePosts):
## - the tavern, the shop and the post office are timber houses now, each with a sign and a door in
##   the middle of its front, opened like the villagers' houses (walls, floor, door);
## - the hero walks in through the door; inside, the floor above and whichever walls face the camera
##   are hidden (the shop's door faces away, so its back wall hides and its front stays);
## - each hall has its counter and furniture, the shop and the tavern a place behind the counter;
## - by day the shopkeeper walks in through the door to her place behind the counter, the hero
##   reaches her from in front of it, and at nightfall she walks out again;
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
	check(halls.size() == VillageHalls.KINDS.size(), "the tavern, the shop and the post office can be walked into (%d)" % halls.size())
	var houses_on := _house_boxes(lvl)
	for rec in halls:
		var hall: Node3D = rec.node
		var kind: String = rec.kind
		check(rec.get("opened", false) and hall.has_meta("village_house"), "the %s is a timber house one walks into" % kind)
		check(hall.get_node_or_null("HallSign") != null, "the %s has its sign by the door" % kind)
		check(is_zero_approx(float((hall.get_meta("shape") as Dictionary).door_x)), "the %s's door is in the middle of its front" % kind)
		var inside_node := hall.get_node_or_null("HallInside")
		check(inside_node != null and inside_node.get_node_or_null("Counter") != null, "the %s has its counter" % kind)
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
		check(rec.up.all(func(p): return not is_instance_valid(p) or not (p as Node3D).visible), "inside the %s its floor above and roof are hidden" % kind)
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
		await _walk(-in_dir, 4.0)
		check(walk_in.hero_in.is_empty(), "and out of the %s again (%s)" % [kind, hero.global_position])
		check(rec.up.all(func(p): return not is_instance_valid(p) or (p as Node3D).visible), "outside again the %s's roof is back" % kind)

	# --- The shopkeeper behind her counter --------------------------------------------------
	var mira: Villager = null
	for v in lvl.villagers:
		if v.role == "6":
			mira = v
	check(mira != null, "the shopkeeper is in the village")
	if mira != null:
		var shop: Dictionary = halls.filter(func(r): return r.kind == "shop")[0]
		check(VillagePosts.post_of(mira).get("rec", {}).get("node") == shop.node, "the shop is the shopkeeper's hall")
		_place(walk_in.door_points(shop)[0] + Vector3(6, 0.2, 0))
		var at_post := false
		for i in 60 * 40:
			await physics_frame
			if mira.post_trip.get("step", "") == "at":
				at_post = true
				break
		check(at_post, "by day the shopkeeper walks in to her place behind the counter (%s, %s)" % [mira._task, mira.global_position])
		check(walk_in.building_at(mira.global_position).get("node") == shop.node, "she is inside the shop")
		await _wait(30)
		check(mira.global_position.distance_to(shop.posts[0].pos) < 0.4, "behind the counter")
		check(mira.station.get("touch", 0.0) > 1.0, "the hero reaches her from in front of the counter")
		var front: Vector3 = shop.posts[0].front
		check(lvl.station_at(front) == mira.station, "standing before the counter the hero touches her station")
		# Nightfall: out of the door and home.
		game.day_hour = 22.0
		lvl.set_hour(22.0)
		var out := false
		for i in 60 * 20:
			await physics_frame
			if mira.post_trip.is_empty():
				out = true
				break
		check(out, "at nightfall she walks out of the shop again (%s, %s)" % [mira._task, mira.post_trip])
		check(walk_in.building_at(mira.global_position).is_empty(), "and is out on the street (%s)" % mira.global_position)
		game.day_hour = 12.0
		lvl.set_hour(12.0)

	# --- The switches -----------------------------------------------------------------------
	for ch: String in VillageHalls.KINDS:
		WalkIn.halls[ch] = false
	lvl = await _load_village()
	check(lvl.walk_in.buildings.all(func(r): return not VillageHalls.KINDS.values().has(r.kind)), "switched off, no hall can be walked into")
	for ch: String in VillageHalls.KINDS:
		var kit := lvl.get_children().filter(func(n): return n is Node3D and n.has_meta("block") and lvl.cell_char((n.get_meta("block") as Rect2i).position) == ch)
		check(kit.size() == 1 and not kit[0].has_meta("hall"), "switched off, the %s is the old kit model" % VillageHalls.KINDS[ch])
	var houses_off := _house_boxes(lvl)
	var same := houses_off.size() == houses_on.size()
	for i in mini(houses_off.size(), houses_on.size()):
		if not (houses_off[i] as AABB).is_equal_approx(houses_on[i]):
			same = false
	check(same, "switching the halls leaves every house as it was")
	if mira != null:
		for v in lvl.villagers:
			if v.role == "6":
				check(VillagePosts.post_of(v).is_empty(), "switched off, the shopkeeper has no counter to go to")
	for ch: String in VillageHalls.KINDS:
		WalkIn.halls[ch] = true

	game.delete_save(game.save_path())
	print("PASS: village halls" if failures == 0 else "FAILED: village halls (%d)" % failures)
	quit(1 if failures > 0 else 0)
