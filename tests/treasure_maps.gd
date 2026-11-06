extends SceneTree
## Headless test for the treasure maps from messages in a bottle (see
## TreasureMaps): a bottle now and then holds a map instead of a note, each
## map turns up once only, the village spot is marked and the chest dug up
## and opened there, the boulder in the western woods rolls aside and the
## hole beneath it leads down into the hidden grotto and back out, the spots
## carry a cross on the journal's map until done, and it all stays in the
## saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/treasure_maps.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Treasure map test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _station(kind: String, id := "") -> Dictionary:
	for s in game.level.stations:
		if s.kind == kind and (id == "" or s.get("building", s.get("treasure", "")) == id):
			return s
	return {}


func _outdoor_file() -> String:
	return game.level_files[game._outdoor_index()].get_file()


func _run() -> void:
	game.hero_name = HERO
	game.escaped = true
	game.treasure_maps.clear()
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	_texts()
	_map_letters()
	_picking()
	await _village_chest()
	await _hidden_grotto()
	await _saved()
	game.delete_save(game.save_path())
	print("PASS: treasure maps" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _texts() -> void:
	for id in TreasureMaps.MAPS:
		var map: Dictionary = TreasureMaps.MAPS[id]
		for key in ["title", "where", "lore"]:
			check(Lang.EN.has(map[key]), "%s: the %s has English" % [id, key])
	for text in ["Eine Flaschenpost, und darin eine alte Schatzkarte: „%s“!", "Die Stelle ist jetzt auf deiner Karte im Tagebuch markiert.",
			"Schatzkarte gefunden: %s", "Du gräbst eine alte Truhe aus!", "Schatz gehoben: %s", "Verborgene Grotte gefunden",
			"Der Findling rollt beiseite. Darunter führt ein Loch in die Tiefe!", "Dagegenlaufen, um nach dem Schatz zu graben",
			"Dagegenlaufen, um den Findling beiseitezurollen", TreasureMaps.CAVE_NAME]:
		check(Lang.EN.has(text), "\"%s\" has English" % text)


## Each map's letter is on the open-air map exactly once, and the grotto is
## a floor of its own.
func _map_letters() -> void:
	var lvl: Outdoor = game.level
	for id in TreasureMaps.MAPS:
		var cells := TreasureMaps.cells_on(lvl.grid, id)
		check(cells.size() == 1, "%s: its letter is on the map once (%d)" % [id, cells.size()])
		check(lvl.treasure_cells.has(id), "%s: the village knows its spot" % id)
		check(Tiles.OUTDOOR.has(TreasureMaps.MAPS[id].letter), "%s: its letter is claimed in Tiles" % id)
	check(game.interiors.has(TreasureMaps.CAVE), "the hidden grotto has a floor of its own")
	# Before a map is found there is nothing to see or do.
	check(_station(TreasureMaps.DIG).is_empty() and _station(TreasureMaps.BOULDER).is_empty(), "no treasure spot before a map is found")
	check(_station("eingang", TreasureMaps.CAVE).is_empty(), "the grotto is hidden before its map is found")
	check(game.journal.treasure_spots(_outdoor_file()).is_empty(), "no cross on the map before a map is found")


func _picking() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var maps := 0
	for i in 2000:
		if game.treasure_maps.pick(rng) != "":
			maps += 1
	check(maps > 2000 * (TreasureMaps.MAP_CHANCE - 0.06) and maps < 2000 * (TreasureMaps.MAP_CHANCE + 0.06), "a bottle holds a map now and then (%d of 2000)" % maps)
	for id in TreasureMaps.MAPS:
		game.treasure_maps.state[id] = TreasureMaps.DONE
	var none := true
	for i in 300:
		if game.treasure_maps.pick(rng) != "":
			none = false
	check(none, "once every map is found, a bottle never holds one again")
	game.treasure_maps.clear()
	# Fishing up bottles until one holds a map: it is read at once.
	var fishing: Fishing = game.fishing
	var found := ""
	for i in 200:
		fishing.take("flasche", game.player.global_position, game.level)
		if not game.treasure_maps.left().has("dorf") or not game.treasure_maps.left().has("grotte"):
			found = "dorf" if not game.treasure_maps.left().has("dorf") else "grotte"
			break
	check(found != "", "a fished-up bottle can hold a treasure map")
	if found != "":
		check(game.treasure_maps.state[found] == TreasureMaps.READ, "the map from the bottle is read")
		check(game.lore.has(TreasureMaps.MAPS[found].lore), "the map goes into the compendium")
	# Start the rest from no map found.
	game.treasure_maps.clear()
	game.load_level(game._outdoor_index(), false)


func _village_chest() -> void:
	await _wait()
	var lvl: Outdoor = game.level
	Events.bus().treasure_map_found.emit("dorf")
	check(game.treasure_maps.state.get("dorf", "") == TreasureMaps.READ, "the village map is read")
	var spot := _station(TreasureMaps.DIG)
	check(not spot.is_empty(), "the village spot is marked once the map is read")
	if spot.is_empty():
		return
	var cell: Vector2i = lvl.treasure_cells.dorf
	check(spot.cell == cell, "the mark is on the map's tile")
	check(game.journal.treasure_spots(_outdoor_file()).has(cell), "the spot has a cross on the journal's map")
	check(lvl.astar.is_point_solid(cell), "villagers walk round the marked spot")
	check(game.journal.entries.any(func(e): return e.t == "Schatzkarte gefunden: %s"), "the journal tells of the map")
	# Digging: the chest comes up and opens.
	game.player.bag.clear()
	game.player.global_position = spot.pos + Vector3(0, 0, 2.4)
	var coins_before: int = game.coins
	game._use_station(spot)
	await create_timer(TreasureMaps.DIG_TIME + 0.5).timeout
	check(game.treasure_maps.state.get("dorf", "") == TreasureMaps.DONE, "the dug-up chest is opened")
	check(game.coins > coins_before, "the chest holds copper")
	# (A trained eye may find a torch beside it.)
	check(game.player.bag.size() >= 1, "the chest holds a piece of gear")
	if game.player.bag.size() >= 1:
		check(Items.ALL.has(game.player.bag[0]), "what the chest holds is gear")
	check(_station(TreasureMaps.DIG).is_empty(), "the spot is dug up")
	check(not game.journal.treasure_spots(_outdoor_file()).has(cell), "the cross is gone from the map once the chest is opened")
	# A chest dug up with a full bag waits in its pit, also after a reload.
	game.treasure_maps.state.dorf = TreasureMaps.DUG
	(game.looted[_outdoor_file()] as Dictionary).erase("Schatztruhe:%d,%d" % [cell.x, cell.y])
	game.load_level(game._outdoor_index(), false)
	await _wait()
	var waiting := false
	for obj in game.level.interactables:
		if obj.get("treasure", "") == "dorf" and not obj.searched:
			waiting = true
	check(waiting, "a dug-up chest that was not opened is still there")
	game.treasure_maps.state.dorf = TreasureMaps.DONE
	game.load_level(game._outdoor_index(), false)
	await _wait()
	check(not game.level.interactables.any(func(o): return o.get("treasure", "") == "dorf"), "the opened chest is gone the next time")


func _hidden_grotto() -> void:
	var lvl: Outdoor = game.level
	check(_station(TreasureMaps.BOULDER).is_empty(), "the boulder is just a boulder before its map is read")
	Events.bus().treasure_map_found.emit("grotte")
	var boulder := _station(TreasureMaps.BOULDER)
	check(not boulder.is_empty(), "once its map is read, the boulder can be rolled aside")
	if boulder.is_empty():
		return
	check(game.journal.treasure_spots(_outdoor_file()).has(lvl.treasure_cells.grotte), "the boulder has a cross on the journal's map")
	game.player.global_position = boulder.pos + Vector3(Level.TILE, 0, 0)
	game._use_station(boulder)
	await create_timer(TreasureMaps.ROLL_TIME + 0.5).timeout
	check(game.treasure_maps.state.get("grotte", "") == TreasureMaps.OPEN, "the boulder is rolled aside")
	var hole := _station("eingang", TreasureMaps.CAVE)
	check(not hole.is_empty(), "a hole opens under the boulder")
	check(lvl.doors.has(TreasureMaps.CAVE), "the hole has a way back out")
	check(game.journal.treasure_spots(_outdoor_file()).is_empty(), "no cross once the hole is open")
	# Down into the grotto and back out.
	game.go_inside(TreasureMaps.CAVE)
	await create_timer(1.2).timeout
	check(game.level.building == TreasureMaps.CAVE, "the hole leads down into the hidden grotto")
	check(not game.level.enemies.is_empty(), "something lives in the grotto")
	for e in game.level.enemies:
		check(MonsterFamilies.family_of(e.kind) == "wildlife", "%s in the grotto is wildlife" % e.kind)
	check(game.level.interactables.any(func(o): return o.label == "Schatztruhe"), "a treasure chest waits in the grotto")
	game._leave_building()
	await _wait()
	check(game.level is Outdoor, "out of the grotto into the open air")
	if game.level is Outdoor:
		check(game.player.global_position.distance_to(game.level.doors[TreasureMaps.CAVE]) < 1.0, "the hero comes out beside the hole")
		check(not _station("eingang", TreasureMaps.CAVE).is_empty(), "the hole stays open")
		check(_station(TreasureMaps.BOULDER).is_empty(), "the boulder stays rolled aside")


func _saved() -> void:
	game.save_game()
	var data: Dictionary = game._read_save(game.save_path())
	check(data.has("treasure_maps"), "the treasure maps are saved")
	var before: Dictionary = game.treasure_maps.state.duplicate()
	game.treasure_maps.clear()
	game.treasure_maps.load_from(data.get("treasure_maps", {}))
	check(game.treasure_maps.state == before, "the treasure maps come back from the saved game")
	await _wait()
