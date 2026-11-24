extends SceneTree
## Headless test for Spooknortz's nights in the village (see SpookRaid): at night he climbs out of the street
## drain, walks to two houses, lingers and steals, and goes home again; none of it by day or once he is
## slain; the hero can catch him in the act and gets the stolen goods; in the morning the village finds
## things missing.
## Run with: godot --headless --fixed-fps 60 -s tests/spook_raid.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
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


func _hour(h: float) -> void:
	game.day_hour = h
	game.level.set_hour(h)


## Puts every villager who sleeps at night into bed (or out of it) by flag.
func _bed(level: Outdoor, on: bool) -> void:
	for v: Variant in level.villagers:
		if is_instance_valid(v) and v.goes_to_bed():
			v.at_home = on


## Runs his night by hand until he is home (or the steps run out).
func _round(raid: SpookRaid, seconds: float) -> void:
	var t := 0.0
	while raid.state != SpookRaid.IDLE and t < seconds:
		raid.step(0.1)
		t += 0.1


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Raid test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var raid: SpookRaid = level.spook_raid
	check(raid != null and level.cell_char(SpookRaid.START) == "Ξ", "the village has its night thief and the drain he climbs out of")
	for text in [SpookRaid.SPOTTED, SpookRaid.MORNING, SpookRaid.CAUGHT, SpookRaid.EMPTY, SpookRaid.NOT_NOW, SpookRaid.FULL, Spooknortz.THIEF_PROMPT]:
		check(Lang.EN.has(text), "English for: " + text)
	check(level.stations.filter(func(s): return s.kind == Spooknortz.THIEF).size() == 1, "one station for catching him")
	# The hero stays far away (the north-west corner), so he comes out.
	game.player.global_position = level.cell_to_world(Vector2i(40, 24))
	game._snap_camera()
	# By day nothing happens.
	_hour(12.0)
	await _wait(5)
	raid.step(0.1)
	check(raid.state == SpookRaid.IDLE and raid.figure == null, "by day he stays home")
	# At night he waits until most of the village is in bed.
	_hour(23.5)
	await _wait(5)
	_bed(level, false)
	raid.step(0.1)
	check(raid.state == SpookRaid.IDLE and not raid.village_asleep(), "with the village still up he stays in the sewers")
	var bedders: Array = level.villagers.filter(func(v): return is_instance_valid(v) and v.goes_to_bed())
	check(bedders.size() > 4, "the village has sleepers (%d)" % bedders.size())
	for i in bedders.size() / 2:
		bedders[i].at_home = true
	raid.step(0.1)
	check(raid.state == SpookRaid.IDLE, "with only half in bed he still waits")
	_bed(level, true)
	raid.step(0.1)
	check(raid.state != SpookRaid.IDLE and raid.figure != null and is_instance_valid(raid.figure), "at night he climbs out of the drain")
	check(raid.figure.global_position.distance_to(level.cell_to_world(SpookRaid.START)) < 1.0, "right at the drain")
	check(raid.figure.get_node_or_null("Fog") is CPUParticles3D and raid.figure.get_node("Fog").emitting, "a wisp of mist trails him")
	check(raid.figure.get_node("Fog").mesh.size.x <= 1.5 and raid.figure.get_node("Fog").amount <= 20 and not raid.figure.get_node("Fog").local_coords, "a small, thin one that stays behind where he walked")
	var seen_through := 0
	var meshes := 0
	for mi: MeshInstance3D in raid.figure._model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count() if mi.mesh != null else 0:
			meshes += 1
			var m := mi.get_surface_override_material(i)
			if m != null and m.has_meta(SpookRaid.SEE_THROUGH_META):
				seen_through += 1
	check(meshes > 0 and seen_through == meshes, "he is half see-through (%d of %d parts)" % [seen_through, meshes])
	check(raid.figure._model.rotation.x > 0.3 and raid.figure._model.position.y < -0.1, "he is stooped in a sneaking pose")
	check(not level.enemies.has(raid.figure), "he is no foe on the list: nobody strikes at him")
	var farthest := 0.0
	var stopped := 0
	var t := 0.0
	var was_lingering := false
	while raid.state != SpookRaid.IDLE and t < 900.0:
		raid.step(0.1)
		t += 0.1
		if raid.figure != null and is_instance_valid(raid.figure):
			farthest = maxf(farthest, raid.figure.global_position.distance_to(level.cell_to_world(SpookRaid.START)))
		if raid.state == SpookRaid.LINGER_AT and not was_lingering:
			stopped += 1
		was_lingering = raid.state == SpookRaid.LINGER_AT
	check(raid.state == SpookRaid.IDLE and raid.figure == null, "he is home again (%d s)" % t)
	check(stopped == 2 and raid.total == 2, "he lingered at two houses and stole twice (%d, %d)" % [stopped, raid.total])
	check(farthest > 20.0, "his round took him through the village (%d m from the drain)" % farthest)
	check(t < 400.0, "his round fits well into a night (%d s)" % t)
	# No second round the same night.
	raid.step(0.1)
	check(raid.state == SpookRaid.IDLE, "one round a night")
	# Morning: the village finds things missing, once.
	var told: Array = []
	Events.bus().news_told.connect(func(text, _c, _d): told.append(text))
	_hour(12.0)
	raid.step(0.1)
	raid.step(0.1)
	check(told.filter(func(x): return x == Lang.t(SpookRaid.MORNING)).size() == 1, "in the morning the village finds things missing, once")
	# Caught in the act: a second night, forced.
	_hour(23.5)
	await _wait(3)
	raid.begin(game, true)
	check(raid.state == SpookRaid.WALK, "a new round starts")
	var spot: Dictionary = level.stations.filter(func(s): return s.kind == Spooknortz.THIEF)[0]
	# Not yet carrying anything: he only shushes the hero.
	game._use_station(spot)
	check(raid.state == SpookRaid.WALK and raid.carried == 0 and not game.quests.is_active(Spooknortz.QUEST), "empty-handed he is only a shadow")
	# Let him steal once, then run into him.
	var guard := 0
	while raid.carried == 0 and raid.state != SpookRaid.IDLE and guard < 20000:
		raid.step(0.1)
		guard += 1
	check(raid.carried == 1 and raid._sack != null, "after the first theft a sack hangs on his back")
	if shots != "":
		game.player.global_position = raid.figure.global_position + Vector3(0, 0.1, 6.0)
		game._snap_camera()
		await _wait(40)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("thief_night.png"))
		# The same by day, close up, to see how see-through he is and the wisp that trails him.
		var cam := Camera3D.new()
		cam.fov = 50.0
		root.add_child(cam)
		var fig: Vector3 = raid.figure.global_position
		_hour(12.0)
		var n := 0
		for off: Vector3 in [Vector3(0, 4.2, 2.4), Vector3(0, 1.4, 3.0)]:
			cam.global_position = fig + off
			cam.look_at(fig + Vector3(0, 0.7, 0))
			cam.make_current()
			await _wait(25)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shots.path_join("thief_day%d.png" % n))
			n += 1
		cam.queue_free()
		_hour(23.5)
		await _wait(3)
	raid._catch_until = 0.0
	game._use_station(spot)
	check(game.quests.is_active(Spooknortz.QUEST) and game.player.bag.has(Spooknortz.BUNDLE), "caught in the act he drops the stolen goods: the task starts")
	check(raid.state == SpookRaid.FLEE and raid.carried == 0, "and runs for the drain")
	_round(raid, 600.0)
	check(raid.state == SpookRaid.IDLE and raid.figure == null, "he gets away down the drain")
	# The guard (Ulrich) comes along: he slips away out of his sight and lies low until he has passed.
	var ulrich: Villager = null
	for v: Variant in level.villagers:
		if is_instance_valid(v) and v.role == SpookRaid.GUARD_ROLE:
			ulrich = v
	check(ulrich != null, "the village has its guard")
	if ulrich != null:
		ulrich.at_home = false
		ulrich.visible = true
		ulrich.global_position = Vector3(0.0, 0.0, 4000.0)
		_hour(23.5)
		raid._done_tonight = false
		raid.begin(game, true)
		for i in 80:
			raid.step(0.1)
		check(raid.state == SpookRaid.WALK, "on his round again")
		var here: Vector3 = raid.figure.global_position
		var placed := false
		for a in range(0, 360, 30):
			var spot_pos := here + Vector3(cos(deg_to_rad(a)), 0.0, sin(deg_to_rad(a))) * 9.0
			var cell := level.world_to_cell(spot_pos)
			if level.astar.is_in_boundsv(cell) and not level.astar.is_point_solid(cell) and level.has_line_of_sight(spot_pos, here):
				ulrich.global_position = Vector3(spot_pos.x, 0.0, spot_pos.z)
				placed = true
				break
		check(placed, "a spot to put the guard where he sees the thief")
		var hid_before := raid.hid
		for i in 8:
			raid.step(0.1)
		check(raid.hid == hid_before + 1 and raid.state in [SpookRaid.HIDE, SpookRaid.COVER], "he slips off to cover when the guard comes (state %d)" % raid.state)
		var t_hide := 0.0
		while raid.state == SpookRaid.HIDE and t_hide < 30.0:
			raid.step(0.1)
			t_hide += 0.1
		check(raid.state == SpookRaid.COVER, "he reaches cover (%d s)" % t_hide)
		check(not level.has_line_of_sight(ulrich.global_position, raid.figure.global_position), "and the guard cannot see him there")
		for i in 150:
			raid.step(0.1)
		check(raid.state == SpookRaid.COVER, "he stays down while the guard is about")
		ulrich.global_position = Vector3(0.0, 0.0, 4000.0)
		for i in 60:
			raid.step(0.1)
		check(raid.state == SpookRaid.WALK, "he goes on once the guard has gone")
		_round(raid, 900.0)
		check(raid.state == SpookRaid.IDLE and raid.figure == null, "and still gets home")
	# Others in his way (Zarek, a villager): he leaves them room, bumps into nobody and gets home.
	var other: Villager = null
	for v: Variant in level.villagers:
		if is_instance_valid(v) and v != ulrich and v.role != SpookRaid.GUARD_ROLE:
			other = v
			break
	check(other != null, "someone to walk into")
	if other != null:
		other.at_home = false
		other.visible = true
		_hour(23.5)
		raid._done_tonight = false
		raid.begin(game, true)
		check(raid.figure.collision_layer == 0 and raid.figure.collision_mask == 0, "nobody bumps into his body")
		for i in 60:
			raid.step(0.1)
		var ahead: Vector3 = raid.figure.global_position
		if raid._at < raid._path.size():
			var way: Vector3 = (raid._path[raid._at] - ahead)
			way.y = 0.0
			ahead += way.normalized() * 1.2
		other.global_position = Vector3(ahead.x, 0.0, ahead.z)
		var closest := INF
		for i in 80:
			raid.step(0.1)
			var d: Vector3 = raid.figure.global_position - other.global_position
			d.y = 0.0
			closest = minf(closest, d.length())
		check(closest >= SpookRaid.ROOM * 0.5, "he keeps clear of the one in his way (%.2f m)" % closest)
		other.visible = false
		_round(raid, 900.0)
		check(raid.state == SpookRaid.IDLE and raid.figure == null, "and still gets home past people")
	# Slain: no more nights.
	_hour(12.0)
	raid.step(0.1)
	game.lore.append(Spooknortz.SLAIN)
	_hour(23.5)
	raid._done_tonight = false
	raid.step(0.1)
	check(raid.state == SpookRaid.IDLE, "he does not come out once he is slain")
	print("PASS: spook raid" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
