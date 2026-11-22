extends SceneTree
## Headless test for the forgotten silver mine under the woods (see LostMine): its layout lies
## under the forest and hangs together from the shaft, it is drawn on the open-air map like a
## built house's cellar with whole ground over it, the hero climbs down into it and the surface
## hides, the pages of the log and the sealed gate are there to run into, and no plot can be
## marked out over it.
## Run with: godot --headless --fixed-fps 60 -s tests/lost_mine.gd
## With SHOTS=<folder> and a display it also saves pictures of the hut and the mine.

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


## The layout alone: every row as wide as the plot, every tunnel reached from the shaft,
## tunnels and rooms no wider than a normal room, the hut's floor round the shaft.
func _check_layout() -> void:
	var cells := LostMine.cells()
	var n := LostMine.PLOT.size * HouseSketch.CELLS_PER_TILE
	check(LostMine.LAYOUT.size() == n.y, "the layout has a row for every cell of the plot")
	for row: String in LostMine.LAYOUT:
		check(row.length() == n.x, "every row of the layout is as wide as the plot")
	check(cells.get(LostMine.SHAFT, "") == "L", "the shaft is dug under the hut")
	check(LostMine.HUT.has_point(LostMine.SHAFT) and LostMine.HUT.has_point(HouseSketch.ladder_top(LostMine.SHAFT.x, LostMine.SHAFT.y, HouseSketch.LADDER_ORIENTS[LostMine.LADDER_DIR])), "the ladder leads up into the hut")
	check(cells.get(LostMine.GATE_CELL, "") == "D" and not cells.has(LostMine.GATE_CELL + Vector2i(0, -1)), "the gate stands at the end of a tunnel")
	# Everything hangs together from the shaft (the caved-in drift counts: it is dug).
	var seen := {LostMine.SHAFT: true}
	var todo: Array[Vector2i] = [LostMine.SHAFT]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in HouseSketch.DOWN.values():
			if cells.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				todo.append(c + d)
	check(seen.size() == cells.size(), "every tunnel and room is reached from the shaft (%d of %d)" % [seen.size(), cells.size()])
	# No large halls: no 6 x 6 block of dug cells (12 x 12 m) anywhere.
	var hall := false
	for c: Vector2i in cells:
		var full := true
		for dy in 6:
			for dx in 6:
				if not cells.has(c + Vector2i(dx, dy)):
					full = false
		hall = hall or full
	check(not hall, "no hall bigger than a normal room")
	for page: Array in LostMine.NOTES:
		check(cells.has(page[1]) and cells[page[1]] != "x", "a page lies in a tunnel or room")
	for c: Vector2i in LostMine.LAMPS:
		check(cells.has(c), "a lamp hangs in a tunnel or room")
	var house := LostMine.sketch()
	check(house.count(HouseSketch.DOOR) == 1 and house.count(HouseSketch.WINDOW) == 2, "the hut has a door and two windows")
	check(house.count(HouseSketch.LADDER) == 1, "a ladder stands in the shaft")
	check(house.count(HouseSketch.DIG) == cells.size(), "every cell of the mine is dug")
	for key in house.pieces:
		var p := HouseSketch.parts_of(key)
		if house.pieces[key].kind == HouseSketch.DIG:
			check(house.cell_in_plot(p[1], p[2]), "the mine lies inside its plot")
	for text in [LostMine.LEARN, LostMine.ENTERED, LostMine.GATE_FIRST, LostMine.GATE_AGAIN, LostMine.prompt(LostMine.NOTE), LostMine.prompt(LostMine.GATE)]:
		check(Lang.EN.has(text), "English for: " + text)
	for page: Array in LostMine.NOTES:
		check(Lang.EN.has(page[0]), "English for: " + page[0])


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Lost mine test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var sketcher: HouseSketcher = game.house_sketcher
	var mine := LostMine.sketch()
	# Up on the map: the woods over the tunnels, grass round the hut.
	var under_forest := 0
	for c: Vector2i in LostMine.cells():
		if c == LostMine.SHAFT:
			continue
		var tile := LostMine.PLOT.position + c / HouseSketch.CELLS_PER_TILE
		if level.cell_char(tile) == "#":
			under_forest += 1
	check(under_forest == LostMine.cells().size() - 1, "the tunnels lie under the forest (%d of %d)" % [under_forest, LostMine.cells().size() - 1])
	for y in range(LostMine.HUT.position.y, LostMine.HUT.end.y):
		for x in range(LostMine.HUT.position.x, LostMine.HUT.end.x):
			var tile := LostMine.PLOT.position + Vector2i(x, y) / HouseSketch.CELLS_PER_TILE
			check(level.cell_char(tile) == ".", "the hut stands on grass")
	# No plot over the hut or the tunnels.
	var hut_tile := LostMine.PLOT.position + LostMine.HUT.position / HouseSketch.CELLS_PER_TILE
	var why := Plots.problem(level, Rect2i(hut_tile, Vector2i(2, 2)))
	check(why == "taken", "no plot can be marked out over the hut (%s)" % why)
	# Drawn: the holes for the cellar view, ground only cut over the shaft.
	var view: CellarView = sketcher.cellar_view
	check(view.holes.size() >= LostMine.cells().size(), "the mine's cells are holes in the ground (%d)" % view.holes.size())
	var shaft := mine.cell_world(LostMine.SHAFT.x, LostMine.SHAFT.y)
	var tunnel := LostMine.floor_at(Vector2i(42, 30))
	var space := level.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(tunnel.x, 5, tunnel.z), Vector3(tunnel.x, -10, tunnel.z)))
	check(not down.is_empty() and absf(down.position.y) < 0.2, "the ground over a tunnel is solid to walk on (%s)" % str(down.get("position", "nothing")))
	var into := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(tunnel.x, -0.5, tunnel.z), Vector3(tunnel.x, -10, tunnel.z)))
	check(not into.is_empty() and absf(into.position.y + HouseSketch.DEPTH) < 0.1, "under it the tunnel's floor lies DEPTH down (%s)" % str(into.get("position", "nothing")))
	var hole := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(shaft.x + 0.5, -0.3, shaft.z), Vector3(shaft.x + 0.5, -10, shaft.z)))
	check(not hole.is_empty() and hole.position.y < -HouseSketch.DEPTH + 0.1, "the shaft lies open to its floor")
	check(not sketcher.deep.visible, "on the ground the mine is not drawn")
	check(get_nodes_in_group(Player.LADDER_GROUP).size() >= 1, "the ladder is there to climb")
	var pages := level.stations.filter(func(s): return s.kind == LostMine.NOTE)
	var gates := level.stations.filter(func(s): return s.kind == LostMine.GATE)
	check(pages.size() == LostMine.NOTES.size(), "every page of the log lies down there (%d)" % pages.size())
	check(gates.size() == 1, "the gate is there")
	var chests := level.interactables.filter(func(o): return str(o.id).begins_with("grube:"))
	check(chests.size() >= 3, "a few chests to search (%d)" % chests.size())
	# Each chest stands with its back to a wall and opens (its +Z) into the room.
	for o: Dictionary in chests:
		var c := LostMine.cell_at(o.pos)
		var lid_node: Node3D = (o.lid as Node3D).get_parent() if o.get("lid") != null else null
		if lid_node == null:
			continue
		var front := lid_node.global_basis.z
		var ahead := c + Vector2i(roundi(front.x), roundi(front.z))
		var behind := c - Vector2i(roundi(front.x), roundi(front.z))
		check(LostMine.cells().has(ahead) or not LostMine.cells().has(behind), "a chest opens towards the room, its back to a wall (%s)" % c)
	# Nothing stands in a tunnel's way: where a tunnel cell meets the next open cell, the hero fits
	# through (a rack of picks once stood across the tool store's way out).
	var ball := SphereShape3D.new()
	ball.radius = 0.32
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	var open := LostMine.cells().keys().filter(func(c): return LostMine.cells()[c] != "x")
	# A tunnel cell lies in no open 2 x 2 block (those are rooms, where things stand about).
	var narrow := func(c: Vector2i) -> bool:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			var o := c + corner
			if open.has(o) and open.has(o + Vector2i(1, 0)) and open.has(o + Vector2i(0, 1)) and open.has(o + Vector2i(1, 1)):
				return false
		return true
	for c: Vector2i in open:
		if not narrow.call(c):
			continue
		for d: Vector2i in HouseSketch.DOWN.values():
			if not open.has(c + d):
				continue
			q.transform = Transform3D(Basis(), (LostMine.floor_at(c) + LostMine.floor_at(c + d)) * 0.5 + Vector3(0, 0.9, 0))
			var hit := space.intersect_shape(q, 1)
			check(hit.is_empty(), "the way from tunnel cell %s on to %s is free" % [c, c + d])
	var beds := level.stations.filter(func(s): return s.kind == LostMine.BED)
	check(beds.size() == 3, "the bunks are there to run into (%d)" % beds.size())
	for text in [LostMine.BED_WARN, LostMine.prompt(LostMine.BED)]:
		check(Lang.EN.has(text), "English for: " + text)
	# The hut stands empty: no lit panes.
	check(mine.abandoned, "the hut is marked as empty")
	check(sketcher.get_node_or_null("EmptyHut") != null and sketcher.get_node("EmptyHut").get_child_count() > 10, "dust, debris and cobwebs lie in the hut")
	# The hut from outside.
	var front := mine.cell_world(41, 24)
	if shots != "":
		game.player.global_position = front + Vector3(0, 0.1, 2.0)
		game._snap_camera()
		await _shot("hut")
	# Down the shaft.
	game.player.global_position = shaft + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	game._snap_camera()
	await _wait(20)
	check(view.active, "down the shaft the cellar view is on")
	check(view.pit.size() == LostMine.cells().size(), "the whole mine is one cellar (%d)" % view.pit.size())
	check(sketcher.deep.visible, "down there the mine is drawn")
	check(game.lore.has(LostMine.LEARN), "the compendium learns of the mine")
	check(game._under_roof(), "no weather falls into the mine")
	# Walk the main gallery: a page is read by running into it.
	var page: Dictionary = pages[0]
	game._use_station(page)
	check(game.lore.has(LostMine.NOTES[0][0]), "a page read goes into the compendium")
	game._use_station(beds[0])
	check(game.player.global_position.y < -1.0, "the bed only warns: the hero stays where they are")
	game._use_station(gates[0])
	check(game.lore.has(LostMine.GATE_FIRST), "the gate is looked at")
	check(level.station_at(gates[0].pos + Vector3(0, 0.5, 0)).get("kind", "") == LostMine.GATE, "the gate is run into down there")
	check(level.station_at(Vector3(gates[0].pos.x, 0.5, gates[0].pos.z)).is_empty(), "but not from the ground above it")
	await _check_the_dead(level)
	if shots != "":
		for spot: Array in [["shaft", Vector2i(42, 29)], ["store", Vector2i(45, 30)], ["gallery", Vector2i(31, 31)], ["bunks", Vector2i(35, 34)], ["silver", Vector2i(27, 29)],
				["cart", Vector2i(57, 37)], ["cave_in", Vector2i(64, 41)], ["shrine", Vector2i(4, 35)], ["cleft", Vector2i(9, 22)], ["old_works", Vector2i(12, 10)], ["gate", Vector2i(12, 5)],
				["west_drift", Vector2i(3, 22)], ["ore_chamber", Vector2i(12, 45)], ["east_drift", Vector2i(66, 34)], ["east_vein", Vector2i(69, 29)],
				["powder_room", Vector2i(17, 16)]]:
			game.player.global_position = LostMine.floor_at(spot[1]) + Vector3(0, 0.1, 0)
			game._snap_camera()
			await _wait(10)
			await _shot("mine_" + spot[0])
	# Back up: everything shows again, the mine hides.
	game.player.global_position = front + Vector3(0, 0.1, 2.0)
	game._snap_camera()
	await _wait(20)
	check(not view.active and not sketcher.deep.visible, "back up the mine hides again")
	var standing := LostMine.guards()
	check(not standing.is_empty() and standing.all(func(e): return not e.visible), "up on the ground the dead of the mine do not show")
	check(standing.all(func(e): return not e._awake or e._lost > 0.0), "nor do they see the hero up there")
	# A redraw of the houses (a piece built) is quick: the mine is drawn once.
	var t := Time.get_ticks_msec()
	sketcher.refresh()
	check(Time.get_ticks_msec() - t < 400, "the houses are drawn again quickly (%d ms)" % (Time.get_ticks_msec() - t))
	check(level.stations.filter(func(s): return s.kind == LostMine.NOTE).size() == LostMine.NOTES.size(), "drawing again adds no pages twice")
	print("PASS: lost mine" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The dead of the far drifts: they rise when the hero comes down, stand on the mine's floor,
## find their way along the tunnels and see only down them; up on the ground nobody knows of
## them, and the ore veins they keep give ore once they have fallen, once a day.
func _check_the_dead(level: Outdoor) -> void:
	await _wait(5)
	var dead := LostMine.guards()
	check(dead.size() == LostMine.GUARDS.size(), "the dead stand in the far drifts (%d)" % dead.size())
	for e: Enemy in dead:
		check(MonsterFamilies.family_of(e.kind) == "undead", "the dead of the mine are undead (%s)" % e.kind)
	await _wait(30)
	for e: Enemy in dead:
		check(absf(e.global_position.y + HouseSketch.DEPTH) < 0.3 and LostMine.holds(e.global_position), "one of the dead stands on the mine's floor (%s)" % str(e.global_position))
	# The ways down there run along the tunnels.
	var from := LostMine.floor_at(LostMine.SHAFT + Vector2i(0, 2))
	var to := LostMine.floor_at(Vector2i(69, 28))
	var way := LostMine.route(from, to)
	check(way.size() > 20, "a way runs along the tunnels to the far east drift (%d steps)" % way.size())
	check(way.all(func(p): return LostMine.holds(p + Vector3(0, 0.1, 0))), "every step of the way lies in the tunnels")
	check(LostMine.sight(LostMine.floor_at(Vector2i(58, 34)), LostMine.floor_at(Vector2i(69, 34))), "the long east drift is seen down its length")
	check(not LostMine.sight(LostMine.floor_at(Vector2i(58, 34)), LostMine.floor_at(Vector2i(69, 30))), "but not round its corner")
	check(not level.has_line_of_sight(LostMine.floor_at(Vector2i(58, 34)), Vector3(LostMine.floor_at(Vector2i(58, 34)).x, 0, LostMine.floor_at(Vector2i(58, 34)).z + 4)), "nobody sees through the ground")
	# The hero at the start of the east drift: the dead in it come for them along the tunnel.
	var watcher: Enemy = null
	for g: Dictionary in LostMine._guards:
		if g.cell == Vector2i(63, 34):
			watcher = g.enemy
	game.player.global_position = LostMine.floor_at(Vector2i(57, 36)) + Vector3(0, 0.1, 0)
	game.player.reset_physics_interpolation()
	var start := watcher.global_position.distance_to(game.player.global_position)
	game.player.godmode = true
	await _wait(2)
	# Heard round the corner: it walks the drift and turns the corner, not through the rock.
	watcher.alert(game.player.global_position)
	await _wait(120)
	var near := watcher.global_position.distance_to(game.player.global_position)
	check(near < start - 2.0, "one of the dead comes for the hero along the drift (%.1f m to %.1f m)" % [start, near])
	check(LostMine.holds(watcher.global_position), "and stays down in the mine")
	# A vein is theirs while they walk: nothing to hack.
	var veins := level.stations.filter(func(s): return s.kind == LostMine.VEIN)
	check(veins.size() == LostMine.VEINS.size(), "an ore vein at the end of each far drift (%d)" % veins.size())
	var east: Dictionary = veins.filter(func(s): return s.vein == Vector2i(69, 28))[0]
	var ores_before := _ore_count()
	game._use_station(east)
	check(_ore_count() == ores_before, "no ore while the dead walk near the vein")
	for e: Enemy in LostMine.guards():
		if e.global_position.distance_to(east.pos) < LostMine.VEIN_GUARD + 30.0:
			e.take_hit(999, e.global_position + Vector3(1, 0, 0))
	await _wait(5)
	game._use_station(east)
	check(_ore_count() > ores_before, "once they fell the vein gives ore (%d lumps)" % (_ore_count() - ores_before))
	var once := _ore_count()
	game._use_station(east)
	check(_ore_count() == once, "but only once a day")
	await _wait(5)
	check(LostMine.guards().size() < LostMine.GUARDS.size(), "the fallen stay down today")
	for k in [LostMine.VEIN_GUARDED, LostMine.VEIN_SPENT, LostMine.VEIN_FOUND, LostMine.prompt(LostMine.VEIN)]:
		check(Lang.EN.has(k), "English for: " + k)
	game.player.godmode = false
	game.player.global_position = LostMine.floor_at(LostMine.SHAFT + Vector2i(0, 2)) + Vector3(0, 0.1, 0)
	game.player.reset_physics_interpolation()
	await _wait(5)


func _ore_count() -> int:
	var n := 0
	for id in Ore.LUMPS:
		n += int(game.crafting.pouch.get(id, 0))
	return n


## The game's own camera, as the player sees it.
func _shot(name: String) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.level.set_hour(12.0)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
