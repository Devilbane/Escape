extends SceneTree
## Headless test: gold glints (CoinShine). Coins on the floor, the heaps of
## gold in the dragons' lairs and the gold in an opened treasure chest catch
## the light: a polished, warm gold and little stars that blink on them now
## and then. Kept cheap: a few particles per heap, no lights of their own.
## Run with: godot --headless --fixed-fps 60 -s tests/coin_shine.gd
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
	seed(3)
	if shots != "":
		Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: coin shine" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## A look at `at` from `from` (relative), without the HUD or the fog of war,
## with the hero (and the lantern) standing just behind the camera.
func _shot(name: String, at: Vector3, from: Vector3, settle := 20) -> void:
	if shots == "":
		return
	var lvl: Level = game.level
	var flat := Vector3(from.x, 0, from.z)
	game.player.global_position = Vector3(at.x, game.player.global_position.y, at.z) + flat * 1.15
	if lvl.fog:
		lvl.fog.visible = false
	var hidden := []
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.global_position = at + from
	cam.look_at(at)
	cam.make_current()
	await _wait(settle)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	if lvl.fog:
		lvl.fog.visible = true
	for layer in hidden:
		layer.visible = true


## With SERIES set as well: frames of the same look a little apart, for an
## animation of the glints blinking.
func _series(name: String, at: Vector3, from: Vector3) -> void:
	if shots == "" or OS.get_environment("SERIES") == "":
		return
	for i in 16:
		await _shot("%s_%02d" % [name, i], at, from, 2)


func _twinkles(node: Node) -> Array:
	return node.find_children(CoinShine.NAME + "*", "CPUParticles3D", true, false)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = "Shine test"
	await _wait(10)
	await _chest()
	await _floor_coins()
	await _dragon_hoard()
	await _elder_hoard()
	_finish()


## The treasure chest of the first floor: shut, nothing blinks; opened, the
## gold inside it does.
func _chest() -> void:
	var lvl: Level = game.level
	var chest := {}
	for obj in lvl.interactables:
		if obj.label == "Schatztruhe":
			chest = obj
	check(not chest.is_empty(), "the first floor has a treasure chest")
	if chest.is_empty():
		return
	# The hero stands by it, so the fog of war does not hide it.
	var front := Vector3(0, 0, 2.6) if lvl.cell_char(chest.cell + Vector2i(0, 1)) != "#" else Vector3(0, 0, -2.6)
	game.player.global_position = Vector3(chest.pos.x, game.player.global_position.y, chest.pos.z) + front
	await _wait(40)
	var shine: CPUParticles3D = chest.get("shine")
	check(shine != null, "the chest has glints for the gold in it")
	if shine:
		check(not shine.emitting, "a shut chest does not blink")
	await _shot("chest_shut", chest.pos + Vector3(0, 0.8, 0), Vector3(0.6, 2.2, 0) + front)
	lvl.search(chest)
	await _wait(60)
	if shine:
		check(shine.emitting, "an opened chest's gold blinks")
	await _shot("chest_open", chest.pos + Vector3(0, 0.8, 0), Vector3(0.6, 2.2, 0) + front)
	await _series("chest_open", chest.pos + Vector3(0, 0.8, 0), Vector3(0.6, 2.2, 0) + front)


## Spilt coins lie on the floor polished and glinting now and then.
func _floor_coins() -> void:
	var lvl: Level = game.level
	var at: Vector3 = lvl.cell_to_world(lvl.start_cell)
	lvl._drop_coins(at, 6)
	await _wait(30)
	var coins := lvl._pickups.filter(func(p): return p.kind == "coin")
	check(not coins.is_empty(), "the coins lie on the floor")
	for p in coins:
		check(_twinkles(p.node).size() == 1, "a coin on the floor glints")
		var mi := p.node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		check(mat != null and mat.metallic > 0.0 and mat.emission_enabled, "a coin is polished gold")
	await _shot("floor_coins", at, Vector3(0.4, 2.6, 2.8))
	await _series("floor_coins", at, Vector3(0.4, 2.6, 2.8))


## The dragon's lair, with a hoard brought in by its helpers.
func _dragon_hoard() -> void:
	game.escaped = true
	game.hoard.clear()
	game.hoard.gold = 120
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	game.player.global_position = game.level.doors.E
	game.go_inside("E")
	await _wait(60)
	var lvl: Level = game.level
	check(lvl._hoard != null, "the lair has its hoard")
	if lvl._hoard == null:
		return
	check(_twinkles(lvl._hoard).size() >= 1, "the hoard glints")
	var heaps := lvl.find_children(CoinShine.NAME + "*", "CPUParticles3D", true, false)
	check(heaps.size() >= 5, "the heaps round the chest glint too (%d)" % heaps.size())
	for p: CPUParticles3D in heaps:
		check(p.amount <= CoinShine.MAX_GLINTS, "a heap keeps to a few glints (%d)" % p.amount)
	for e in lvl.enemies:
		e.visible = false
	await _shot("dragon_hoard", lvl._hoard.global_position + Vector3(0, 0.5, 0), Vector3(1.0, 3.0, 5.0))
	await _shot("dragon_hoard_close", lvl._hoard.global_position + Vector3(0, 0.4, 0), Vector3(0.5, 1.6, 2.6))


## The Great Old One's bed of gold.
func _elder_hoard() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(10)
	game.go_inside("uralt3")
	await _wait(60)
	var lvl: Level = game.level
	var hoard := lvl.find_child("ElderHoard", true, false) as Node3D
	check(hoard != null, "the Great Old One sleeps on its hoard")
	if hoard == null:
		return
	check(_twinkles(hoard).size() >= 1, "the Great Old One's hoard glints")
	for e in lvl.enemies:
		e.visible = false
	await _shot("elder_hoard", hoard.global_position + Vector3(0, 0.5, 0), Vector3(2.0, 6.0, 9.0))
	await _series("elder_hoard", hoard.global_position + Vector3(0, 0.5, 0), Vector3(2.0, 6.0, 9.0))
