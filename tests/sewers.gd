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
	check(seen.size() == cells.size(), "every cell is reached from the grating (%d of %d)" % [seen.size(), cells.size()])
	var channel := Sewers.channel()
	var walk := cells.keys().filter(func(c): return cells[c] == "w" and not channel.has(c))
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
			if cells.get(n, "") in ["w", "s"] and not strip.has(n):
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
	game._use_station(lid)
	await _wait(80)
	check(lid.used and Sewers.opened.has(a.tile), "running into the lid opens it")
	var open_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(shaft.x, 3, shaft.z), Vector3(shaft.x, -10, shaft.z)))
	check(open_hit.is_empty() or open_hit.position.y < -HouseSketch.DEPTH + 0.1, "an open hatch lets the hero through to the floor")
	if shots != "":
		await _shot("hatch_open")
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
	if shots != "":
		for spot: Array in [["walkway", Vector2i(14, 40)], ["shaft", Vector2i(12, 46)], ["west", Vector2i(8, 7)]]:
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
	var t := Time.get_ticks_msec()
	sketcher.refresh()
	check(Time.get_ticks_msec() - t < 400, "the houses are drawn again quickly (%d ms)" % (Time.get_ticks_msec() - t))
	check(level.stations.filter(func(s): return s.kind == Sewers.KIND_LID).size() == Sewers.HATCHES.size(), "drawing again adds no lid twice")
	print("PASS: sewers" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.level.set_hour(12.0)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
