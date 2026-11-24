extends SceneTree
## Headless test for the village's sewers (see Sewers and SewerSurface): the stream from the valley's
## river runs up the pass to a grating at the village gate, the drain under the village hangs together
## from the grating to the outfall, the sewers are drawn under whole ground like a cellar, the hero opens a
## manhole hatch and climbs down its ladder, the street drains and the outfall stand on the map, and no
## plot can be marked out over it.
## Run with: godot --headless --fixed-fps 60 -s tests/sewers.gd
## With SHOTS=<folder> and a display it also saves pictures.

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
	_check_layout()
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


## The layout alone: everything hangs together from the first cell of the channel, the channel
## runs unbroken from the grating to the outfall, every walkway cell touches a channel or another
## walkway cell, and the shafts reach the walkway.
func _check_layout() -> void:
	var cells := Sewers.cells()
	var plot_cells := Sewers.PLOT.size * HouseSketch.CELLS_PER_TILE
	for c: Vector2i in cells:
		check(c.x >= 0 and c.y >= 0 and c.x < plot_cells.x and c.y < plot_cells.y, "cell %s lies inside the plot" % c)
	var start: Vector2i = Sewers.ROUTE[0]
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in HouseSketch.DOWN.values():
			if cells.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				todo.append(c + d)
	check(Sewers.sketch().flush_ladders, "the shaft ladders end flush, none sticks out of a shut hatch")
	check(seen.size() == cells.size(), "every cell is reached from the grating (%d of %d)" % [seen.size(), cells.size()])
	var channel := Sewers.channel()
	var walk := cells.keys().filter(func(c): return cells[c] in ["w", "r"] and not channel.has(c))
	# The walkway is one connected strip (the shafts and their passages hang on it): no gaps at the corners.
	var strip := {}
	var first: Vector2i = Vector2i(Sewers.ROUTE[0].x - 1, Sewers.ROUTE[0].y)
	check(cells.get(first, "") == "w", "the walkway starts beside the channel's first cell")
	var queue: Array[Vector2i] = [first]
	strip[first] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in HouseSketch.DOWN.values():
			var n := c + d
			if cells.get(n, "") in ["w", "s", "r"] and not strip.has(n):
				strip[n] = true
				queue.append(n)
	check(strip.size() == walk.size() + Sewers.HATCHES.size(), "the walkway runs unbroken with its passages and shafts (%d of %d)" % [strip.size(), walk.size() + Sewers.HATCHES.size()])
	# The channel flows from the first to the last cell: each cell's neighbour ahead is a channel cell too.
	var last: Vector2i = Sewers.ROUTE[Sewers.ROUTE.size() - 1]
	for c: Vector2i in channel:
		if c != last:
			check(channel.has(c + (channel[c] as Vector2i)), "the water at %s flows on into the channel" % c)
	for hatch: Dictionary in Sewers.HATCHES:
		var shaft: Vector2i = hatch.cell
		check(cells.get(shaft, "") == "s", "a shaft is dug under the hatch at %s" % hatch.tile)
		check(Sewers.tile_of(shaft) == hatch.tile, "the shaft lies under its hatch's tile %s (is %s)" % [hatch.tile, Sewers.tile_of(shaft)])
		check(Sewers.tile_of(HouseSketch.ladder_top(shaft.x, shaft.y, HouseSketch.LADDER_ORIENTS[hatch.dir])) == hatch.tile, "the ladder comes up inside the hatch's tile")
	var house := Sewers.sketch()
	check(house.count(HouseSketch.DIG) == cells.size(), "every cell is dug")
	check(house.count(HouseSketch.LADDER) == Sewers.HATCHES.size(), "a ladder stands in each shaft")
	for text in [Sewers.LEARN, Sewers.ENTERED, Sewers.LID_OPENED, Sewers.LID_PROMPT]:
		check(Lang.EN.has(text), "English for: " + text)
	_check_labyrinth(cells)


## The labyrinth: circuits that lead back without turning round, chambers with pillars, vermin of the
## right family and a respawn that fits the lap.
func _check_labyrinth(cells: Dictionary) -> void:
	for room: Rect2i in Sewers.ROOMS:
		check(room.size.x >= 5 and room.size.y >= 5 and room.size.x <= 9 and room.size.y <= 9, "a chamber is big but not huge (%s)" % room.size)
	for c: Vector2i in Sewers.PILLARS:
		check(not cells.has(c), "the pillar at %s is solid" % c)
		var round := 0
		for d: Vector2i in HouseSketch.DOWN.values():
			if cells.get(c + d, "") == "r":
				round += 1
		check(round == 4, "there is room to run round the pillar at %s" % c)
	# Each circuit: from the walkway out through its passages and chambers and back to the walkway,
	# without setting foot on the walkway's own column in between.
	var circuits := [[Vector2i(13, 52), Vector2i(13, 34)], [Vector2i(13, 20), Vector2i(13, 12)]]
	var lap := 0.0
	for circuit: Array in circuits:
		var dist := {circuit[0]: 0}
		var todo: Array[Vector2i] = [circuit[0]]
		while not todo.is_empty():
			var c: Vector2i = todo.pop_front()
			for d: Vector2i in HouseSketch.DOWN.values():
				var n := c + d
				if n.x < 14 and "wr".contains(cells.get(n, "-")) and not dist.has(n):
					dist[n] = dist[c] + 1
					todo.append(n)
		check(dist.has(circuit[1]), "a circuit runs from %s round to %s and not along the walkway" % [circuit[0], circuit[1]])
		var back: int = absi(circuit[0].y - circuit[1].y)
		lap = maxf(lap, (float(dist.get(circuit[1], 0)) + back) * HouseSketch.CELL)
	check(lap > 80.0, "the bigger circuit is a real lap (%d m)" % lap)
	var seconds := lap / Player.SPEED
	check(Sewers.RESPAWN_AFTER >= seconds and Sewers.RESPAWN_AFTER <= seconds * 4.0, "the vermin come back about a lap later (%d s lap, %d s respawn)" % [seconds, Sewers.RESPAWN_AFTER])
	check(Sewers.MOBS.size() >= 8, "the chambers and passages are inhabited")
	for m: Array in Sewers.MOBS:
		check(cells.get(m[1], "") in ["r", "w"], "%s at %s stands in a dug cell" % [m[0], m[1]])
		check(Enemy.KINDS.has(m[0]) and MonsterFamilies.family_of(m[0]) == "wildlife", "%s is wildlife" % m[0])
	var header := LevelMap.load_file("res://levels/11_die_freiheit.txt").get_header(MonsterFamilies.HEADER)
	check(MonsterFamilies.parse(header).has("wildlife"), "the village map's families include wildlife")


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Sewer test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var sketcher: HouseSketcher = game.house_sketcher
	var view: CellarView = sketcher.cellar_view
	# On the map: the stream, its grating, the outfall and the river below it.
	var water := 0
	for y in range(SewerSurface.STREAM_TO_ROW, SewerSurface.STREAM_FROM_ROW + 1):
		for x in [44, 45]:
			if level.cell_char(Vector2i(x, y)) == "≈":
				water += 1
	check(water == 2 * (SewerSurface.STREAM_FROM_ROW - SewerSurface.STREAM_TO_ROW + 1), "the stream is water all the way from the valley to the grating (%d tiles)" % water)
	check(level.cell_char(Vector2i(44, 68)) == "≈" and level.cell_char(Vector2i(45, 68)) == "≈", "the stream leaves the valley's river")
	check(level.cell_char(Vector2i(44, 45)) == "Ω" and level.cell_char(Vector2i(45, 45)) == "Ω", "the grating closes the stream at the village gate")
	check(level.cell_char(Vector2i(37, 19)) == "Ψ" and level.cell_char(Vector2i(38, 19)) == "Ψ", "the outfall stands in the north-west corner")
	check(level.find_child("StreamFlow", true, false) != null and level.find_child("OutfallFlow", true, false) != null, "the stream and the river below the outfall carry leaves and rubbish")
	for hatch: Dictionary in Sewers.HATCHES:
		check(level.cell_char(hatch.tile) == "Θ", "a hatch lies in the street at %s" % hatch.tile)
	for tile: Vector2i in Sewers.GRILLES:
		check(level.cell_char(tile) == "Ξ" and Outdoor.WALK.contains("Ξ"), "a street drain at %s, walkable" % tile)
	# No snow over the drains' flat iron and stone (it would flicker), nor on the street round them, nor
	# on the heap at the stream's grating (it draws its own snow).
	var warm_drains := 0
	for tile: Vector2i in Sewers.GRILLES:
		var at := level.cell_to_world(tile)
		for w: Vector4 in level.warm_spots:
			if Vector2(w.x - at.x, w.z - at.z).length() < 0.5 and is_equal_approx(w.w, SewerSurface.GRILLE_WARM):
				warm_drains += 1
				break
	check(warm_drains == Sewers.GRILLES.size(), "no snow settles on the street round every drain (%d)" % warm_drains)
	var bare_drains := 0
	for m: Node in level.find_children("*", "MeshInstance3D", false, false):
		for tile: Vector2i in Sewers.GRILLES:
			if m.has_meta("no_snow") and Vector2(m.position.x - level.cell_to_world(tile).x, m.position.z - level.cell_to_world(tile).z).length() < 0.5:
				bare_drains += 1
	check(bare_drains >= Sewers.GRILLES.size(), "every drain's iron and stone is marked free of snow (%d)" % bare_drains)
	for heap: Node in level.get_tree().get_nodes_in_group(SewerSurface.HEAP_GROUP):
		check(heap.has_meta("no_snow"), "the heap at the grating takes no second coat of snow")
	# Drawn: ground cut open over the shafts only, whole ground over the tunnels.
	check(view.holes.size() >= Sewers.cells().size(), "the sewers' cells are holes in the ground (%d)" % view.holes.size())
	var space := level.get_world_3d().direct_space_state
	var tunnel := Sewers.floor_at(Vector2i(14, 30))
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(tunnel.x, 5, tunnel.z), Vector3(tunnel.x, -10, tunnel.z)))
	check(not down.is_empty() and absf(down.position.y) < 0.2, "the ground over the walkway is solid to walk on (%s)" % str(down.get("position", "nothing")))
	var into := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(tunnel.x, -0.5, tunnel.z), Vector3(tunnel.x, -10, tunnel.z)))
	check(not into.is_empty() and absf(into.position.y + HouseSketch.DEPTH) < 0.1, "under it the floor lies DEPTH down (%s)" % str(into.get("position", "nothing")))
	check(not sketcher.deep.visible, "on the ground the sewers are not drawn")
	check(get_nodes_in_group(Player.LADDER_GROUP).size() >= Sewers.HATCHES.size(), "the ladders are there to climb")
	# Nobody wades the channel: a solid block fills it.
	var wade := Sewers.floor_at(Sewers.ROUTE[0] + Vector2i(0, -10)) + Vector3(0, 0.5, 0)
	var side := Sewers.floor_at(Sewers.ROUTE[0] + Vector2i(-1, -10)) + Vector3(0, 0.5, 0)
	var block := space.intersect_ray(PhysicsRayQueryParameters3D.create(side, wade))
	check(not block.is_empty(), "the kerb and the water's block stop the hero between walkway and channel")
	# No plot over the drain (the village's streets are no plot ground anyway, see Plots.problem).
	check(Sewers.covers_tile(Vector2i(44, 40)) and not Sewers.covers_tile(Vector2i(60, 20)), "the tiles over the sewers are told apart from the rest")
	# The hatches: shut, solid and a station; running into one opens it.
	var lids := level.stations.filter(func(s): return s.kind == Sewers.KIND_LID)
	check(lids.size() == Sewers.HATCHES.size(), "every hatch has its lid to run into (%d)" % lids.size())
	var a: Dictionary = Sewers.HATCHES[0]
	var lid: Dictionary = lids.filter(func(l): return l.key == a.tile)[0]
	var top := HouseSketch.ladder_top(a.cell.x, a.cell.y, HouseSketch.LADDER_ORIENTS[a.dir])
	var street := Sewers.sketch().cell_world(top.x, top.y)
	var shaft := Sewers.sketch().cell_world(a.cell.x, a.cell.y)
	var lid_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(shaft.x, 3, shaft.z), Vector3(shaft.x, -0.1, shaft.z)))
	check(not lid_hit.is_empty() and lid_hit.position.y > 0.5, "a shut lid is solid (stops the hero at %s)" % str(lid_hit.get("position", "nothing")))
	if shots != "":
		game.player.global_position = street + Vector3(0, 0.1, 0.0)
		game._snap_camera()
		await _shot("hatch_shut")
	Sewers.open_for = 3.0
	game._use_station(lid)
	await _wait(80)
	check(Sewers.opened.has(a.tile), "running into the lid opens it")
	check(not lid.used and lid.has("stand"), "the hatch stays clickable for good, with a spot to stand at the ladder's head")
	var open_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(shaft.x, 3, shaft.z), Vector3(shaft.x, -10, shaft.z)))
	check(open_hit.is_empty() or open_hit.position.y < -HouseSketch.DEPTH + 0.1, "an open hatch lets the hero through to the floor")
	if shots != "":
		await _shot("hatch_open")
	# Clicking the open hatch: the hero at the head of the ladder climbs down it.
	game.player.global_position = lid.stand + Vector3(0.0, 0.05, 0.0)
	await _wait(5)
	game._use_station(lid)
	await _wait(3)
	check(game.player.on_ladder(), "clicking the open hatch climbs down the ladder")
	var climbed := 0
	while game.player.on_ladder() and climbed < 600:
		await _wait(1)
		climbed += 1
	check(not game.player.on_ladder() and game.player.global_position.y < -HouseSketch.DEPTH + 0.6, "and the climb ends on the floor (%s)" % str(game.player.global_position))
	check(Sewers.prompt(Sewers.KIND_LID, lid) == Lang.t(Sewers.LID_DOWN_PROMPT), "an open hatch asks to be climbed down")
	# The shaft's floor takes no snow.
	var bare := 0
	for m: Node in sketcher.find_children("*", "MeshInstance3D", true, false):
		if m.has_meta("no_snow"):
			bare += 1
	check(bare >= Sewers.cells().size(), "the pit floors are marked free of snow (%d)" % bare)
	# Down: the cellar view is on, the whole drain is one pit, the surface hides.
	game.player.global_position = Sewers.floor_at(Vector2i(14, 46)) + Vector3(0, 0.1, 0)
	game._snap_camera()
	await _wait(20)
	check(view.active, "down in the walkway the cellar view is on")
	check(sketcher.deep.visible, "down there the sewers are drawn")
	check(game.lore.has(Sewers.LEARN), "the compendium learns of the sewers")
	check(game._under_roof(), "no weather falls into the sewers")
	check(game._in_lost_mine(), "no daylight reaches down there")
	check(view.pit.size() == Sewers.cells().size(), "the whole drain is one cellar (%d of %d)" % [view.pit.size(), Sewers.cells().size()])
	# The map: the sewers get a floor of their own that fills in as the hero explores, the den stays
	# blank until it is found, and the hatches, grating and outfall are landmarks on the surface.
	var journal: Journal = game.journal
	journal.reveal_sewer(game.player.global_position)
	check(journal.has_sewer() and journal.is_sewer_seen(Vector2i(14, 46)), "the map records the sewers the hero sees")
	check(not journal.is_sewer_seen(Vector2i(14, 5)), "far-off tunnels stay unseen")
	journal.reveal_sewer(Sewers.floor_at(Vector2i(14, 56)))
	check(not journal.is_sewer_seen(Spooknortz.PASSAGE[0]) and not journal.is_sewer_seen(Spooknortz.SPOT), "the hidden den stays blank on the map")
	var file: String = journal.current_file()
	check(MapView.storeys(journal, file).has(MapView.SEWER), "the sewers are a floor of the map")
	check(MapView.hero_storey(game.player.global_position) == MapView.SEWER, "the hero is on the sewers' floor")
	var kinds := journal.places_on(file).filter(func(p): return p.kind == "sewer").map(func(p): return p.name)
	check(kinds.has("Kanalluke") and kinds.has("Gitter des Baches") and kinds.has("Auslauf der Kanalisation"), "hatches, grating and outfall are landmarks on the surface map (%s)" % str(kinds))
	var packed := journal.for_save()
	var reloaded := Journal.new(game)
	reloaded.load_from(packed)
	check(reloaded.is_sewer_seen(Vector2i(14, 46)), "the explored sewers are saved with the journal")
	# The look: grimy brick in several variants, soft light shafts (no beam mesh), a murky water shader.
	check(Sewers.brick_material(0) != Sewers.brick_material(1) and Sewers.floor_material(0) != Sewers.floor_material(2), "the brick comes in grime variants")
	var variants := {}
	for piece: Dictionary in Sewers.sketch().pieces.values():
		if piece.kind == HouseSketch.DIG:
			variants[piece.wall] = true
	check(variants.size() == Sewers.VARIANTS, "the walls use every grime variant (%d)" % variants.size())
	var soft := 0
	var spots: Array = game.level.find_children("*", "SpotLight3D", true, false)
	for l: Node in spots:
		if l.spot_angle >= 45.0 and not l.shadow_enabled:
			soft += 1
	check(soft >= Sewers.GRILLES.size(), "every street drain lets in a broad, soft spot of daylight (%d)" % soft)
	var beams := 0
	for m: Node in sketcher.deep.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		if mesh is CylinderMesh and is_equal_approx((mesh as CylinderMesh).top_radius, 0.45) and (mesh as CylinderMesh).height > 2.0:
			beams += 1
	check(beams == 0, "no hard-edged beam of light is drawn (%d)" % beams)
	await _check_vermin()
	await _check_den()
	if shots != "":
		for spot: Array in [["room1", Vector2i(3, 51)], ["room2", Vector2i(5, 35)], ["room3", Vector2i(6, 22)], ["walkway", Vector2i(14, 40)]]:
			game.player.global_position = Sewers.floor_at(spot[1]) + Vector3(0, 0.1, 0)
			game._snap_camera()
			await _wait(10)
			await _shot("sewer_" + spot[0])
	# Surface views.
	if shots != "":
		for spot: Array in [["culvert", Vector3(46.5 * 4.0, 0.1, 48.0 * 4.0)], ["outfall", Vector3(39.0 * 4.0, 0.1, 15.0 * 4.0)], ["street", Vector3(43.0 * 4.0, 0.1, 40.0 * 4.0)]]:
			game.player.global_position = spot[1]
			game._snap_camera()
			await _wait(20)
			await _shot("surface_" + spot[0])
	# Up again: the sewers hide; drawing the houses again is quick and adds no lid twice.
	game.player.global_position = street + Vector3(0, 0.1, 0)
	game._snap_camera()
	await _wait(20)
	check(not view.active and not sketcher.deep.visible, "back up the sewers hide again")
	# After a minute with nobody near, the lid falls shut, and is solid again.
	game.player.global_position = street + Vector3(30.0, 0.1, 0.0)
	game._snap_camera()
	await _wait(60 * 7)
	check(not Sewers.opened.has(a.tile), "the lid falls shut after a minute")
	var shut_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(shaft.x, 3, shaft.z), Vector3(shaft.x, -0.1, shaft.z)))
	check(not shut_hit.is_empty() and shut_hit.position.y > 0.5, "a lid shut again is solid")
	Sewers.open_for = 60.0
	game._use_station(lid)
	await _wait(100)
	check(Sewers.opened.has(a.tile), "it can be opened again")
	var t := Time.get_ticks_msec()
	sketcher.refresh()
	check(Time.get_ticks_msec() - t < 400, "the houses are drawn again quickly (%d ms)" % (Time.get_ticks_msec() - t))
	check(level.stations.filter(func(s): return s.kind == Sewers.KIND_LID).size() == Sewers.HATCHES.size(), "drawing again adds no lid twice")
	print("PASS: sewers" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The vermin rise when the hero is down there; a fallen one is back after RESPAWN_AFTER seconds, out of
## sight, and not while the hero is near its post.
func _check_vermin() -> void:
	Sewers.clock_stopped = 1000.0
	var standing := Sewers.standing()
	for g: Dictionary in Sewers.vermin():
		if g.enemy == null or not is_instance_valid(g.enemy) or g.enemy.dead:
			print("missing: ", g.kind, " ", g.cell, " fell ", g.fell, " enemy ", g.enemy, " hero dead ", game.player.dead)
	check(standing.size() == Sewers.MOBS.size(), "the vermin stand at their posts (%d of %d)" % [standing.size(), Sewers.MOBS.size()])
	var g: Dictionary = Sewers.vermin()[0]
	var e: Enemy = g.enemy
	e.take_hit(999, e.global_position + Vector3(1, 0, 0))
	await _wait(10)
	check(e.dead and float(g.fell) >= 0.0, "a slain one is noted")
	await _wait(10)
	check(not _stands(g), "it does not come back at once")
	Sewers.clock_stopped += Sewers.RESPAWN_AFTER * 0.5
	await _wait(10)
	check(not _stands(g), "nor half a lap later")
	Sewers.clock_stopped += Sewers.RESPAWN_AFTER
	var hero_at: Vector3 = game.player.global_position
	game.player.global_position = Sewers.floor_at(g.cell) + Vector3(3, 0.1, 0)
	await _wait(10)
	check(not _stands(g), "not while the hero stands beside its post")
	game.player.global_position = hero_at
	await _wait(10)
	check(_stands(g), "after a lap, out of sight, it is back")
	Sewers.clock_stopped = -1.0


func _stands(g: Dictionary) -> bool:
	return g.enemy != null and is_instance_valid(g.enemy) and not g.enemy.dead


## Spooknortz's den: a false wall the hero breaks open, the secret behind it, the revenant by day and not
## at night, his window and what it does, the stolen goods and the walled-up coins.
func _hour(h: float) -> void:
	game.day_hour = h
	game.level.set_hour(h)


func _check_den() -> void:
	for text in [Spooknortz.DEN_FOUND, Spooknortz.MET, Spooknortz.FRIEND, Spooknortz.SLAIN, Spooknortz.NICHE_FOUND, Spooknortz.WALL_PROMPT, Spooknortz.TALK_PROMPT,
			Spooknortz.NICHE_PROMPT, Spooknortz.WALL_OPENED, Spooknortz.NICHE_OPENED, Spooknortz.AWAY, Spooknortz.GONE] + Spooknortz.TALES:
		check(Lang.EN.has(text), "English for: " + text)
	for key in ["title", "goal", "offer", "remind", "done"]:
		check(Lang.EN.has(Quests.ALL[Spooknortz.QUEST][key]), "English for the quest's %s" % key)
	check(Items.ALL.has(Spooknortz.BUNDLE) and Lang.EN.has(Items.ALL[Spooknortz.BUNDLE].name), "the bundle of stolen goods is an item")
	for id: String in Spooknortz.WARES:
		check(Items.ALL.has(id), "his ware %s exists" % id)
	var cells := Sewers.cells()
	for c: Vector2i in Spooknortz.PASSAGE:
		check(cells.has(c), "the passage cell %s is dug" % c)
	check(cells.has(Spooknortz.SPOT), "he has his place in the den")
	check(not cells.has(Spooknortz.WALL_CELL + Vector2i(1, 0)) and not cells.has(Spooknortz.WALL_CELL + Vector2i(-1, 0)), "the passage is one cell wide")
	var view: CellarView = game.house_sketcher.cellar_view
	_hour(12.0)
	game.player.global_position = Sewers.floor_at(Vector2i(4, 54)) + Vector3(0, 0.1, 0)
	game._snap_camera()
	await _wait(10)
	var wall: Array = game.level.stations.filter(func(s): return s.kind == Spooknortz.WALL)
	var talk: Array = game.level.stations.filter(func(s): return s.kind == Spooknortz.KIND)
	var niche: Array = game.level.stations.filter(func(s): return s.kind == Spooknortz.NICHE)
	check(wall.size() == 1 and talk.size() == 1 and niche.size() == 1, "the wall, the revenant and the niche each have a station (%d, %d, %d)" % [wall.size(), talk.size(), niche.size()])
	check(not Spooknortz.opened and Spooknortz._veil.visible and not Spooknortz._wall_shape.disabled, "the wall is shut and the den hidden at first")
	check(Spooknortz._figure == null, "he is not about while the wall is shut")
	if shots != "":
		await _shot("den_wall")
	# Running into the wall breaks it open.
	game._use_station(wall[0])
	await _wait(60)
	check(Spooknortz.opened and game.lore.has(Spooknortz.DEN_FOUND), "the wall gives way and the compendium learns of the den")
	check(Spooknortz._wall_shape.disabled and not Spooknortz._veil.visible, "the way is open and the den shows")
	# By day he rests in his den.
	game.player.global_position = Sewers.floor_at(Vector2i(4, 58)) + Vector3(0, 0.1, 0)
	game._snap_camera()
	await _wait(10)
	check(Spooknortz._figure != null and is_instance_valid(Spooknortz._figure), "by day Spooknortz rests in his den")
	if shots != "":
		await _shot("den_open")
	check(not game.level.enemies.has(Spooknortz._figure), "at rest he cannot be struck")
	# At night he is out.
	_hour(23.5)
	await _wait(10)
	check(Spooknortz._figure == null, "at night the den is empty")
	game._use_station(talk[0])
	check(game.menus.current == "", "the window stays shut while he is out")
	_hour(12.0)
	await _wait(10)
	check(Spooknortz._figure != null, "by day he is back")
	# His window.
	game.coins = 300
	game._use_station(talk[0])
	check(game.menus.current == Spooknortz.KIND, "running into him opens his window")
	await _wait(5)
	if shots != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("den_window.png"))
	var frame: Rect2 = game.menus._panel.get_global_rect()
	var before: int = int(Items.ALL["amulett_tempo"].price * Spooknortz.MARKUP)
	Spooknortz._buy(game.menus, "amulett_tempo")
	check(game.player.bag.has("amulett_tempo") and game.coins == 300 - before, "buying a ware takes its price (%d copper left)" % game.coins)
	Spooknortz._listen(game.menus)
	check(game.lore.has(Spooknortz.TALES[0]) and game.lore.has(Spooknortz.MET), "listening teaches a rumour and the compendium learns of him")
	Spooknortz._listen(game.menus)
	check(game.lore.has(Spooknortz.TALES[1]), "the next rumour comes next")
	Spooknortz._fetch_goods(game.menus)
	check(game.quests.is_active(Spooknortz.QUEST) and game.player.bag.has(Spooknortz.BUNDLE), "he hands over the stolen goods and the task starts")
	var had: int = game.coins
	Spooknortz._befriend(game.menus)
	check(game.lore.has(Spooknortz.FRIEND) and game.coins == had - Spooknortz.GIFT, "a gift makes him a friend")
	check(Spooknortz._price(game, "amulett_tempo") < before, "a friend pays less")
	await _wait(5)
	check(game.menus._panel.get_global_rect() == frame, "nothing in his window moved while the hero chose (%s, was %s)" % [game.menus._panel.get_global_rect(), frame])
	# The walled-up coins.
	var paid := [0]
	game.level.coins_collected.connect(func(n, _m, _x): paid[0] += n)
	game.menus.close()
	game._use_station(niche[0])
	check(Spooknortz.plundered and paid[0] >= Spooknortz.NICHE_COINS[0] and game.lore.has(Spooknortz.NICHE_FOUND), "the loose bricks hide coins (%d)" % paid[0])
	var once: int = paid[0]
	game._use_station(niche[0])
	check(paid[0] == once, "they give coins only once")
	# Fighting him: he turns on the hero and falls like any monster.
	game._use_station(talk[0])
	Spooknortz._fight(game.menus)
	var e := Spooknortz._figure
	check(game.menus.current == "" and game.level.enemies.has(e) and Spooknortz._hostile, "choosing to fight sets him on the hero")
	e.take_hit(9999, e.global_position + Vector3(1, 0, 0))
	await _wait(20)
	check(game.lore.has(Spooknortz.SLAIN) and Spooknortz._figure == null, "he falls to dust")
	game._use_station(talk[0])
	check(game.menus.current == "", "no window opens over his dust")
	check(view.active, "all the while the sewers stay drawn")


func _shot(name: String) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.level.set_hour(12.0)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
