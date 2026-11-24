extends SceneTree
## Pictures of the cows and the bull (see FarmAnimal._fur): close up and from a game-like camera, and a
## check that each coat surface wears the fur material.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/cow_fur_shots.gd

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
	HouseFurniture.reload()
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


## Moves the game's season to season day `d` (by the day count, or the season shift where the
## seasons follow the calendar).
func _season(d: int) -> void:
	if "season_shift" in game:
		game.season_shift += d - game.level.season_day
	else:
		game.day = d
	game.day_hour = 12.0
	await _wait(30)


func _first(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d + 2
	return 0


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Fur shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	await _season(_first(Weather.SUMMER))
	for kind in ["cow", "bull"]:
		var herd := level.farm_animals.filter(func(a): return a.kind == kind)
		check(herd.size() >= 1, "there is a %s" % kind)
		if herd.is_empty():
			continue
		var a: FarmAnimal = herd[0]
		game.player.global_position = a.global_position + Vector3(30, 0, 0)
		await _wait(30)
		var furry := 0
		for mi in a.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				if (mi as MeshInstance3D).get_surface_override_material(s) is ShaderMaterial:
					furry += 1
		check(furry >= 3, "%s: the coat surfaces wear fur (%d)" % [kind, furry])
		var at := a.global_position
		await _shot(kind + "_game", at + Vector3(0, 5.5, 5.5), at + Vector3(0, 0.6, 0))
		var side := a.global_transform.basis.x.normalized()
		await _shot(kind + "_close", at + side * 2.6 + Vector3(0, 1.2, 0), at + Vector3(0, 0.7, 0))
		await _shot(kind + "_close2", at - side * 2.6 + Vector3(0, 1.2, 0), at + Vector3(0, 0.7, 0))
	print("PASS: cow fur shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
