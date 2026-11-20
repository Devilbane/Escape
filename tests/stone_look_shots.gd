extends SceneTree
## Headless test: the natural stonework (StoneLook): the village's stone buildings,
## a house the hero builds (walls, garden wall, stone cellar) and a dungeon wall all
## wear it, and the buildings' meshes carry the distances to their rounded edges.
## Run with: godot --headless --fixed-fps 60 -s tests/stone_look_shots.gd
## With SHOTS=<folder> and a display it also saves pictures; STONE_STYLE picks the
## look (see StoneLook.STYLES) and ONLY=<name,...> limits the pictures taken.

## name: [map letter of the door, camera offset from the front, look-at offset from the front]
const VILLAGE := {
	"village_wide": ["w", Vector3(-14, 16, 26), Vector3(-6, 2, -8)],
	"guild": ["w", Vector3(-6, 5.5, 10), Vector3(0, 3.5, -3)],
	"guild_corner": ["w", Vector3(-3, 3.0, 4.0), Vector3(1, 3.5, -3)],
	"castle_close": ["k", Vector3(0, 6, 8), Vector3(0, 8, -6)],
	"smithy": ["j", Vector3(3, 5, 9), Vector3(0, 2.5, -3)],
	"tavern": ["n", Vector3(-4, 5, 10), Vector3(0, 3, -3)],
	"house": ["h", Vector3(4, 4.5, 9), Vector3(0, 3, -3)],
	"house_corner": ["h", Vector3(6.5, 2.5, 3.5), Vector3(2.5, 2.5, -2.5)],
}

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var only := OS.get_environment("ONLY").split(",", false)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
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


func _wanted(name: String) -> bool:
	return shots != "" and (only.is_empty() or only.has(name))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Mason"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(20)
	var lvl: Outdoor = game.level
	lvl.set_hour(10.5)
	# The village's stone buildings carry their edges (CUSTOM0) once rounded.
	var rounded := 0
	for mi: MeshInstance3D in lvl.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is ArrayMesh and mi.mesh.get_surface_count() > 0 \
				and mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0:
			rounded += 1
	check(rounded > 20, "the village's buildings carry their rounded edges (%d meshes)" % rounded)
	for name: String in VILLAGE:
		var key: String = VILLAGE[name][0]
		if not _wanted(name) or not lvl.doors.has(key):
			continue
		var front: Vector3 = lvl.doors[key]
		game.player.global_position = front + Vector3(0, 0, 3)
		await _shot(name, front + (VILLAGE[name][1] as Vector3), front + (VILLAGE[name][2] as Vector3))
	# A terrace of town houses along a lane.
	if _wanted("terrace") and lvl.doors.has("^1"):
		var door: Vector3 = lvl.doors["^1"]
		game.player.global_position = door
		await _shot("terrace", door + Vector3(5, 4.5, 8), door + Vector3(-2, 3, -2))
	await _build_house()
	await _dungeon()
	game.delete_save(game.save_path())
	print("PASS: stone look shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## A house on a plot with stone walls, a window, a stone garden wall and a stone cellar.
func _build_house() -> void:
	var found := Rect2i()
	for y in range(game.level.height - 5):
		for x in range(game.level.grid[y].length() - 5):
			if Plots.problem(game.level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sketcher: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sketcher.plan
	var n := plan.nodes()
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch([[4, 2, "y"]], HouseSketch.WINDOW)
	plan.floor_surface = "stone"
	plan.wall_surface = "stone"
	plan.sketch_dig(plan.cells_between(Vector2i(5, 1), Vector2i(6, 2)))
	plan.sketch(plan.run_between(Vector2i(0, 0), Vector2i(n.x, 0)) + plan.run_between(Vector2i(n.x, 0), Vector2i(n.x, n.y)), HouseSketch.STONE_FENCE)
	plan.deposit(HouseSketch.STONE, 400)
	plan.deposit(HouseSketch.TIMBER, 400)
	plan.order()
	for i in 300:
		if not sketcher.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(2)
	var walls := 0
	for m: MeshInstance3D in sketcher._solid.find_children("*", "MeshInstance3D", false, false):
		if m.material_override == HouseLooks.temple_stone():
			walls += 1
	check(walls > 20, "walls, garden walls and stone cellar walls are stone (%d)" % walls)
	var mid := plan.node_world(n.x / 2, n.y / 2)
	game.player.global_position = mid + Vector3(0, 0, Level.TILE * 4)
	if _wanted("own_house"):
		await _shot("own_house", mid + Vector3(6, 6, 13), mid + Vector3(0, 1, 0))
	if _wanted("own_walls_close"):
		await _shot("own_walls_close", plan.node_world(4, 4) + Vector3(3.0, 2.0, 4.0), plan.node_world(4, 4) + Vector3(-1, 1.3, -1))
	if _wanted("own_cellar"):
		await _shot("own_cellar", plan.cell_world(5, 1) + Vector3(1, 4.5, 4.5), plan.cell_world(5, 1) + Vector3(1, -2.4, 0.5))
	Plots.release(game.hero_name)


## A wall of the first dungeon, the cell.
func _dungeon() -> void:
	if not _wanted("dungeon"):
		return
	game.load_level(0, false)
	await _wait(20)
	var lvl: Level = game.level
	var start: Vector3 = game.player.global_position
	await _shot("dungeon", start + Vector3(3, 5, 6), start + Vector3(0, 1, -2))


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
