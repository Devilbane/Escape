extends SceneTree
## Pictures of the bookshelf in the town house (see Bookshelf): half full and full, from the game's
## own camera and close up, so its turned posts and the books' bindings can be judged.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/bookshelf_shots.gd

const HERO := "Bookshelf shots"

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
	var shelf: Array = lvl.stations.filter(func(s): return s.kind == Bookshelf.KIND)
	check(shelf.size() == 1, "the house has its bookshelf")
	if shelf.is_empty():
		_end()
		return
	var at: Vector3 = shelf[0].pos
	var pivot: Node3D = lvl.get_node(Bookshelf.NODE)
	var front := pivot.global_transform.basis * Vector3(0, 0, 1)
	game.player.global_position = at + front * 3.0 + Vector3(2.5, 0, 0)
	for count: int in [38]:
		game.home_stores[HomeStores.BOOKS] = {"fechtbuch": count}
		game.refresh_bookshelf()
		await _wait(30)
		await _game_view("game_view_%d" % count)
		await _shot("front_%d" % count, at + front * 5.5 + Vector3(0, 1.8, 0), at + Vector3(0, 1.6, 0), 45.0)
		await _shot("close_%d" % count, at + front * 1.4 + Vector3(1.3, 1.5, 0), at - front * 1.0 + Vector3(0.1, 1.0, 0), 45.0)
	_end()


func _end() -> void:
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	print("PASS: bookshelf shots" if failures == 0 else "FAILED: %d" % failures)
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
