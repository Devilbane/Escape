extends SceneTree
## Headless test for the village buildings one can walk into (see WalkIn, VillageBeds):
## - every villager's house and the temple open: their door swings open before the hero, the
##   walls stop them, and inside they stand on the floor, out of the weather;
## - inside, the floor above, the roof and the front wall are hidden (the temple's front fades), and
##   come back once the hero is out again; a house lights its lamp;
## - the walls hide the hero inside from sight, the windows and the open door do not;
## - a click into a house walks the hero round through its door;
## - at night the villagers sleep in the beds (three to a house, the rest up the ladder) and in the
##   morning walk out of the door again; a villager sent home walks in and lies down;
## - from outside each house looks as it did: the same size, the same ivy;
## - with the switches off (WalkIn.houses, WalkIn.temple) the old solid buildings are back.
## Run with: godot --headless --fixed-fps 60 -s tests/walk_in.gd

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


## Walks the hero for `seconds` straight along `dir` (as the keys would: no path finding, the walls
## and the door stop them).
func _walk(dir: Vector3, seconds: float) -> void:
	var hero: Player = game.player
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	for k in int(seconds * 60.0):
		hero.path.clear()
		hero.path.append(hero.global_position + flat * 2.0)
		await physics_frame
	hero.path.clear()
	await _wait(2)


func _place(at: Vector3) -> void:
	var hero: Player = game.player
	hero.global_position = at
	hero.velocity = Vector3.ZERO
	hero.path.clear()
	hero.reset_physics_interpolation()


## The world box of the outside of a house: every mesh but the room's own.
func _outside_box(house: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", false, false):
		if mi.name == "WindowSpill" or mi.name == "WalkInside":
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _ivy_count(lvl: Outdoor) -> int:
	var n := 0
	if lvl.ivy:
		for child in lvl.ivy.get_children():
			if child is MultiMeshInstance3D and String(child.name).begins_with("Leaves"):
				n += (child as MultiMeshInstance3D).multimesh.instance_count
	return n


func _houses(lvl: Outdoor) -> Array:
	# The villagers' own four, not the smith's cottage (see SmithCottage).
	return lvl.walk_in.buildings.filter(func(r): return r.kind == "house" and not r.has("owner"))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Walk-in test"
	game.escaped = true

	# --- The old solid buildings, with the switches off -----------------------------
	WalkIn.houses = false
	WalkIn.temple = false
	var lvl := await _load_village()
	check(lvl.walk_in.buildings.all(func(r): return VillageHalls.KINDS.values().has(r.kind)), "switched off, no house or temple can be walked into")
	var solid_boxes := []
	for c in lvl.get_children():
		if c is Node3D and c.has_meta("village_house") and not c.has_meta("hall"):
			solid_boxes.append(_outside_box(c))
			check(c.get_node_or_null("WalkLow") == null, "switched off, a house stays one solid block")
	var solid_ivy := _ivy_count(lvl)
	var solid_tile := Vector2i.ZERO
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == "h":
				solid_tile = Vector2i(x, y)
	check(lvl.is_opaque(solid_tile), "switched off, a house block hides what is behind it")

	# --- Walk-in buildings ------------------------------------------------------------
	WalkIn.houses = true
	WalkIn.temple = true
	lvl = await _load_village()
	var walk_in: WalkIn = lvl.walk_in
	var houses := _houses(lvl)
	var temples := walk_in.buildings.filter(func(r): return r.kind == "temple")
	check(houses.size() == 4, "the four villagers' houses can be walked into (%d)" % houses.size())
	check(temples.size() == 1, "the temple can be walked into")
	check(not lvl.is_opaque(solid_tile), "a walk-in house's block no longer hides by itself (its walls do)")

	# Unchanged outside.
	var i := 0
	for c in lvl.get_children():
		if c is Node3D and c.has_meta("village_house") and not c.has_meta("hall"):
			if i < solid_boxes.size():
				var a: AABB = solid_boxes[i]
				var b := _outside_box(c)
				check(a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size), "house %d is just as big from outside (%s / %s)" % [i, a, b])
			i += 1
	var walk_ivy := _ivy_count(lvl)
	check(walk_ivy == solid_ivy, "the houses and the temple wear just as much ivy (%d / %d)" % [walk_ivy, solid_ivy])

	var hero: Player = game.player
	hero.godmode = true
	for c in lvl.find_children("*", "CharacterBody3D", true, false):
		if c != hero:
			c.process_mode = Node.PROCESS_MODE_DISABLED

	# Into the first house and out again.
	var rec: Dictionary = houses[0]
	var house: Node3D = rec.node
	var way := walk_in.door_points(rec)
	var leaf: HouseDoor = rec.leaf
	_place(way[0] + Vector3(0, 0.2, 1.0))
	await _wait(3)
	check(not leaf.is_open(), "the house door is shut")
	var inward := (way[1] - way[0])
	inward.y = 0.0
	await _walk(inward, 2.6)
	check(not walk_in.building_at(hero.global_position).is_empty(), "the hero walks in through the door (%s)" % hero.global_position)
	check(absf(hero.global_position.y - float(rec.floor)) < 0.2, "and stands on the floor (%.2f)" % hero.global_position.y)
	check(walk_in.hero_in.get("node") == house, "the house knows the hero is inside")
	check(not (rec.up[0] as Node3D).visible, "the floor above and the roof are hidden")
	check(not (rec.front[0] as Node3D).visible, "the front wall is hidden")
	check((rec.lamp as OmniLight3D).visible, "the lamp is lit")
	check(lvl.is_sheltered(hero.global_position) and lvl.hero_indoors, "inside, the weather stays out")
	# The back wall stops the hero.
	await _walk(-inward, 0.0)
	await _walk(inward, 3.0)
	check(not walk_in.building_at(hero.global_position, 0.05).is_empty(), "the back wall stops the hero (%s)" % hero.global_position)
	# Sight: a wall hides the hero, a window does not.
	var inside := hero.global_position
	var shape: Dictionary = house.get_meta("shape")
	var behind := house.global_transform * Vector3(0, 0, -float(shape.d) * 0.5 - 6.0)
	check(not lvl.has_line_of_sight(behind, inside), "the back wall hides the hero from behind the house")
	var by_window := house.global_transform * Vector3(float(shape.w) * 0.5 - 0.8, 0.6, 0)
	var out_window := house.global_transform * Vector3(float(shape.w) * 0.5 + 6.0, 0.1, 0)
	check(lvl.has_line_of_sight(out_window, by_window), "a side window lets the hero be seen")
	check(lvl.blow_blocked(out_window + Vector3(-5.0, 0, 0), by_window), "but no blow lands through its pane")
	await _walk(-inward, 4.0)
	check(walk_in.building_at(hero.global_position, 0.3).is_empty(), "and walks out again (%s)" % hero.global_position)
	check((rec.up[0] as Node3D).visible and (rec.front[0] as Node3D).visible, "outside, the house is whole again")
	check(not (rec.lamp as OmniLight3D).visible, "the lamp is out")

	# A click inside walks round through the door.
	_place(way[0] + Vector3(4.0, 0.2, 2.0))
	await _wait(2)
	var bed: Dictionary = rec.beds[0]
	hero.walk_to(bed.stand)
	check(hero.path.size() >= 2, "a click into the house plans a way through the door")
	await _wait(60 * 8)
	check(not walk_in.building_at(hero.global_position).is_empty(), "the hero walks there (%s)" % hero.global_position)
	check(rec.beds.size() == WalkIn.MAX_BEDS, "a house has three beds (%d)" % rec.beds.size())
	_place(way[0] + Vector3(0, 0.2, 3.0))
	await _wait(5)

	# The temple.
	var t_rec: Dictionary = temples[0]
	var t_way := walk_in.door_points(t_rec)
	_place(t_way[0] + Vector3(0, 0.2, 2.0))
	await _wait(3)
	var t_in := t_way[1] - t_way[0]
	t_in.y = 0.0
	await _walk(t_in, 3.5)
	check(walk_in.hero_in.get("node") == t_rec.node, "the hero walks into the temple (%s)" % hero.global_position)
	check(absf(hero.global_position.y - float(t_rec.floor) * (t_rec.node as Node3D).scale.y) < 0.2, "onto its floor (%.2f)" % hero.global_position.y)
	check(t_rec.up.all(func(p): return not is_instance_valid(p) or not (p as Node3D).visible), "its roof and spire are hidden")
	await _wait(30)
	check(float(t_rec.fade) > 0.5, "its front wall fades")
	var see_through: Array = t_rec.get("fade_meshes", []).filter(func(m): return m.stone or not m.plain.is_empty())
	check(see_through.size() > 0 and see_through.all(func(m): return not m.stone or float((m.mesh as GeometryInstance3D).get_instance_shader_parameter("fade")) > 0.5), "its front wall's stones are see-through (%d)" % see_through.size())
	var front_plain: Array = []
	for m in see_through:
		front_plain.append_array(m.plain)
	check(front_plain.all(func(mat): return mat.albedo_color.a < 0.5), "and its plain parts too")
	await _walk(-t_in, 5.0)
	check(walk_in.hero_in.is_empty(), "and out again (%s)" % hero.global_position)
	_place(t_way[0] + Vector3(0, 0.2, 6.0))

	# --- The villagers' night ------------------------------------------------------------
	for c in lvl.find_children("*", "CharacterBody3D", true, false):
		c.process_mode = Node.PROCESS_MODE_INHERIT
	for v: Villager in lvl.villagers:
		v.set_night(true, true)
	await _wait(5)
	var asleep := 0
	var upstairs := 0
	for v: Villager in lvl.villagers:
		if not v.goes_to_bed():
			continue
		var step := String(v.bed_trip.get("step", ""))
		if step == "asleep":
			asleep += 1
			check(v.visible and v.at_home, "%s sleeps in a bed where one can see them" % v.role)
		elif step == "upstairs":
			upstairs += 1
			check(not v.visible, "%s sleeps upstairs, out of sight" % v.role)
		else:
			check(false, "%s went to bed in a house (%s)" % [v.role, step])
	check(asleep > 0 and asleep <= houses.size() * WalkIn.MAX_BEDS, "villagers sleep in the beds (%d), the rest upstairs (%d)" % [asleep, upstairs])
	for r: Dictionary in houses:
		var taken := (r.beds as Array).filter(func(b): return b.by != null).size()
		check(taken <= WalkIn.MAX_BEDS, "no bed holds two")
	# Gorm sleeps in his own little house beside the smithy, and nobody else does.
	var cottages := walk_in.buildings.filter(func(r): return r.get("owner", "") == SmithCottage.OWNER)
	check(cottages.size() == 1 and (cottages[0].beds as Array).size() == 1, "the smith's cottage can be walked into, with one bed")
	for v: Villager in lvl.villagers:
		var home: Dictionary = v.bed_trip.get("house", {})
		if v.role == SmithCottage.OWNER:
			check(home.get("owner", "") == SmithCottage.OWNER and String(v.bed_trip.get("step", "")) == "asleep", "Gorm sleeps in his own bed in his cottage")
		else:
			check(not home.has("owner"), "%s does not sleep in the smith's cottage" % v.role)
	# Morning: everyone walks out.
	for v: Villager in lvl.villagers:
		v.set_night(false, true)
	await _wait(60 * 14)
	var still := lvl.villagers.filter(func(v): return not v.bed_trip.is_empty() or (v.at_home and v.goes_to_bed()))
	check(still.is_empty(), "in the morning everyone is out of the houses again (%s)" % [still.map(func(v): return v.role + ":" + String(v.bed_trip.get("step", "")))])
	check(lvl.villagers.all(func(v): return v.global_position.y < 0.3), "and back on the ground")
	# One walks home and to bed.
	var sleeper: Villager = null
	for v: Villager in lvl.villagers:
		if v.goes_to_bed():
			sleeper = v
			break
	sleeper.global_position = sleeper.house_door()
	sleeper.reset_physics_interpolation()
	sleeper.set_night(true, false)
	var went := false
	for k in 60 * 25:
		await physics_frame
		if String(sleeper.bed_trip.get("step", "")) in ["asleep", "upstairs"]:
			went = true
			break
	check(went, "a villager walks in through the door and goes to bed (%s)" % sleeper.bed_trip.get("step", "-"))
	if String(sleeper.bed_trip.get("step", "")) == "asleep":
		check(sleeper.global_position.y > 0.9, "and lies on the mattress (%.2f)" % sleeper.global_position.y)

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: walk-in buildings")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
