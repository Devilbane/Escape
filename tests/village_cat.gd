extends SceneTree
## Headless test for the village cat (see VillageCat): it lives at the big smithy, strolls about, and at
## bedtime walks to the old anvil beside the chimney, leaps up, curls up and sleeps; it purrs when the hero
## is near, stretches and hops down when it has slept enough.
## Run with: godot --headless --fixed-fps 60 -s tests/village_cat.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

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


## Runs frames until the cat is in `state`; returns whether it got there within `limit` frames.
func _until(cat: VillageCat, wanted: String, limit: int, seen: Array = []) -> bool:
	for i in limit:
		await process_frame
		if seen.is_empty() or seen[seen.size() - 1] != cat.state:
			seen.append(cat.state)
		if cat.state == wanted:
			return true
	return false


func _set_hour(hour: float) -> void:
	game.day_hour = hour
	game._tick_clock(0.0)


func _shot(name: String, cat: VillageCat, view: Vector3, look := Vector3(0, 0.3, 0)) -> void:
	if shots == "":
		return
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.global_position = cat.global_position + view
	cam.look_at(cat.global_position + look)
	cam.make_current()
	await _wait(6)
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	_set_hour(12.0)
	var cat := lvl.village_cat
	check(cat != null, "the big smithy has a cat")
	if cat == null:
		_finish()
		return
	check(cat.home(), "the cat has a place at home")
	check(cat.foot != Vector3.INF, "the cat has open ground in front of its anvil")
	check(lvl.is_open(lvl.world_to_cell(cat.foot)), "the foot of the anvil is open ground")
	check(cat.global_position.distance_to(cat.foot) < 4.0, "the cat starts near its anvil")
	check(cat.anvil_top.y > 0.5, "the anvil's face is above the ground (%.2f)" % cat.anvil_top.y)
	hero.global_position = cat.anvil_top + cat.out_dir * 12.0
	# By day it sits, then strolls off.
	cat._begin("sit", 0.1)
	cat._strolls = 0
	var seen := []
	var strolled := await _until(cat, "stroll", 120, seen)
	check(strolled, "by day the cat strolls about (%s)" % str(seen))
	await _shot("cat_stroll", cat, Vector3(1.6, 0.9, 2.2))
	for i in 3600:
		await process_frame
		if cat.state != "stroll":
			break
	check(cat.state == "sit", "after a stroll it sits and looks about (%s)" % cat.state)
	await _shot("cat_sit", cat, Vector3(1.4, 0.8, 1.8))
	# Bedtime: it walks to the anvil, crouches, leaps, settles and sleeps on it.
	cat.go_to_bed()
	seen = []
	var napping := await _until(cat, "nap", 3600, seen)
	check(napping, "at bedtime the cat ends up asleep (%s)" % str(seen))
	check(seen.has("leap"), "it leaps up onto the anvil (%s)" % str(seen))
	check(cat.global_position.distance_to(cat.anvil_top) < 0.05, "the sleeping cat lies on the anvil's face (%s vs %s)" % [cat.global_position, cat.anvil_top])
	await _wait(120)
	await _shot("cat_nap", cat, Vector3(1.3, 0.7, 1.6), Vector3(0, 0.1, 0))
	await _shot("cat_nap_wide", cat, Vector3(-3.0, 2.0, 6.0), Vector3(0, 0, 0))
	# It purrs when the hero comes close, and not when the hero is away.
	check(cat._purring < 0.1, "it does not purr with the hero far away")
	hero.global_position = cat.anvil_top + cat.out_dir * 2.0
	hero.global_position.y = 0.0
	await _wait(90)
	check(cat._purring > 0.9, "it purrs when the hero is near (%.2f)" % cat._purring)
	# Purring or not, it lies perfectly still on the anvil: no bouncing, only the breath.
	var low := INF
	var high := -INF
	var bl := INF
	var bh := -INF
	for i in 180:
		await process_frame
		low = minf(low, cat.global_position.y)
		high = maxf(high, cat.global_position.y)
		bl = minf(bl, cat._body.position.y)
		bh = maxf(bh, cat._body.position.y)
	check(bh - bl < 0.0001, "the body does not bob either (%.5f)" % (bh - bl))
	check(high - low < 0.0001, "the sleeping cat does not bounce (%.5f)" % (high - low))
	check(cat.global_position.distance_to(cat.anvil_top) < 0.0001, "it stays put on the anvil while purring")
	hero.global_position = cat.anvil_top + cat.out_dir * 14.0
	await _wait(120)
	check(cat._purring < 0.1, "it stops purring when the hero leaves")
	# By night it sleeps on; by day, once rested, it stretches and hops down.
	_set_hour(23.0)
	cat._timer = 0.1
	await _wait(120)
	check(cat.state == "nap", "at night it sleeps on (%s)" % cat.state)
	_set_hour(12.0)
	seen = []
	var down := await _until(cat, "sit", 600, seen)
	check(down and seen.has("stretch") and seen.has("hop"), "rested by day it stretches and hops down (%s)" % str(seen))
	check(absf(cat.global_position.y) < 0.05, "it is on the ground again")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS" if failures == 0 else "FAIL: %d checks failed" % failures)
	quit(failures)
