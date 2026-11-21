extends SceneTree
## Pictures of the chests with metal fittings (see FittedChest): a treasure chest on the first floor
## shut and opened, the three styles side by side in that room, and the storage chests of the
## hero's town house (ornate brass) and its steel-banded store (dark reinforced).
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/fitted_chest_shots.gd

const HERO := "Chest shots"

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
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = HERO
	await _wait(10)
	await _dungeon()
	print("dungeon done")
	await _house()
	_end()


func _dungeon() -> void:
	var lvl: Level = game.level
	var chest := {}
	for obj in lvl.interactables:
		if obj.label == "Schatztruhe":
			chest = obj
	check(not chest.is_empty(), "the first floor has a treasure chest")
	if chest.is_empty():
		return
	var node: Node3D = chest.lid.get_parent()
	var front := node.global_transform.basis * Vector3(0, 0, 1)
	var side := node.global_transform.basis * Vector3(1, 0, 0)
	# The hero stands back, behind the camera, so the fog of war does not hide the chest.
	game.player.global_position = chest.pos + front * 6.0
	await _wait(40)
	await _game_view("dungeon_game_view")
	await _shot("dungeon_shut", chest.pos + front * 3.6 + side * 1.8 + Vector3(0, 2.6, 0), chest.pos + Vector3(0, 0.6, 0), 40.0)
	lvl.search(chest)
	await _wait(60)
	await _shot("dungeon_open", chest.pos + front * 3.6 + side * 1.8 + Vector3(0, 3.0, 0), chest.pos + Vector3(0, 0.6, 0), 40.0)
	# The three styles side by side, the dark and brass ones set down beside it for the picture.
	var row := []
	for i in 2:
		var style: String = ["dark", "brass"][i]
		var at: Vector3 = chest.pos + side * (2.2 * (i + 1) * (1.0 if lvl.cell_char(lvl.world_to_cell(chest.pos + side * 4.4)) != "#" else -1.0))
		row.append(FittedChest.place(lvl, style, at, node.global_rotation.y))
	var middle: Vector3 = (row[0] as Node3D).global_position
	game.player.global_position = middle + front * 6.5
	await _wait(30)
	await _shot("styles_side_by_side", middle + front * 5.2 + Vector3(0, 3.2, 0), middle + Vector3(0, 0.5, 0), 50.0)
	for n: Node3D in row:
		n.queue_free()


func _house() -> void:
	game.escaped = true
	game.home_stores = HomeStores.empty()
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(HERO, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	var lvl: Level = game.level
	for kind: String in ["lager", HomeStores.STATIONS[HomeStores.METAL]]:
		var found: Array = lvl.stations.filter(func(s): return s.kind == kind)
		check(found.size() > 0, "the house has its %s" % kind)
		if found.is_empty():
			continue
		var at: Vector3 = found[0].pos
		var chest: Node3D = null
		for n: Node3D in lvl.find_children("Chest", "Node3D", true, false):
			if n.global_position.distance_to(at) < 0.5:
				chest = n
		check(chest != null, "the %s is a fitted chest" % kind)
		if chest == null:
			continue
		var front := chest.global_transform.basis * Vector3(0, 0, 1)
		var side := chest.global_transform.basis * Vector3(1, 0, 0)
		game.player.global_position = at + front * 5.0
		await _wait(30)
		await _game_view("house_%s_game_view" % kind)
		await _shot("house_%s_close" % kind, at + front * 3.4 + side * 1.6 + Vector3(0, 2.4, 0), at + Vector3(0, 0.6, 0), 40.0)


func _end() -> void:
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	print("PASS: fitted chest shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _hide_hud() -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false


## What the player sees in the normal view.
func _game_view(name: String) -> void:
	if shots == "":
		return
	_hide_hud()
	await _wait(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _shot(name: String, from: Vector3, to: Vector3, fov: float) -> void:
	if shots == "":
		return
	_hide_hud()
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
