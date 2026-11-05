extends SceneTree
## Headless test: coins look like their metal (CoinPile.METALS). Copper is a
## warm reddish brown, iron a dull dark grey that hardly shines, silver a
## bright polished white-grey and gold a polished gold that blinks the most.
## Holds for piles on the floor, coins the hero puts down and the icons.
## Run with: godot --headless --fixed-fps 60 -s tests/coin_metals.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
const ORDER := ["kupfermuenze", "eisenmuenze", "silbermuenze", "goldmuenze"]


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


func _piles(lvl: Level, metal := "") -> Array:
	return lvl._pickups.filter(func(p): return p.kind == "coin" and p.has("floor") and (metal == "" or p.metal == metal))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = "Metal test"
	await _wait(10)
	_rules()
	var lvl: Level = game.level
	for p in _piles(lvl):
		lvl.take_from_floor(p)
	var at: Vector3 = lvl.cell_to_world(lvl.start_cell) + Vector3(0, 0, 3.0)
	game.player.global_position = Vector3(at.x + 30.0, game.player.global_position.y, at.z + 30.0)
	for i in ORDER.size():
		lvl.lay_coins(at + Vector3(i * 1.3 - 1.95, 0, -1.2), 1, ORDER[i])
		lvl.lay_coins(at + Vector3(i * 1.3 - 1.95, 0, 0.0), 4, ORDER[i])
	await _wait()
	_on_the_floor(lvl)
	_map_coin(lvl, at)
	await _shot("metals_loose", at + Vector3(0, 0, -0.6), Vector3(0.0, 2.6, 3.2))
	for p in _piles(lvl):
		lvl.take_from_floor(p)
		p.node.queue_free()
	for i in ORDER.size():
		lvl.lay_coins(at + Vector3(i * 2.6 - 3.9, 0, 0), 300, ORDER[i])
	await _wait()
	_on_the_floor(lvl)
	await _shot("metals_heaps", at, Vector3(0.0, 3.6, 5.0))
	game.delete_save(game.save_path())
	print("PASS: coin metals" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## What the metals are: iron the dullest and never blinking, copper with a
## soft sheen, silver and gold polished, gold blinking the most and fastest.
func _rules() -> void:
	var m := CoinPile.METALS
	check(m.eisenmuenze.roughness > m.kupfermuenze.roughness and m.kupfermuenze.roughness > m.silbermuenze.roughness, "iron is duller than copper, copper duller than silver")
	check(m.goldmuenze.roughness <= 0.2 and m.silbermuenze.roughness <= 0.2, "silver and gold are polished")
	for n in [1, 4, 30, 300, CoinPile.MAX]:
		var gold := CoinPile.glints_of(n, CoinPile.GOLD)
		var silver := CoinPile.glints_of(n, "silbermuenze")
		var copper := CoinPile.glints_of(n, "kupfermuenze")
		check(CoinPile.glints_of(n, "eisenmuenze").amount == 0, "iron never blinks (%d coins)" % n)
		check(gold.amount >= silver.amount and silver.amount >= copper.amount and copper.amount >= 1, "gold glints most, then silver, then copper (%d coins)" % n)
		check(gold.lifetime < silver.lifetime and silver.lifetime < copper.lifetime, "gold blinks fastest, copper slowest (%d coins)" % n)
	var tints := {}
	for metal in ORDER:
		tints[str(CoinPile.METALS[metal].tint)] = true
	check(tints.size() == ORDER.size(), "every metal has its own colour")
	var red: Color = m.kupfermuenze.tint
	var iron: Color = m.eisenmuenze.tint
	check(red.r > red.g * 1.6 and red.g > red.b, "copper is a reddish brown")
	check(absf(iron.r - iron.b) < 0.05 and iron.v < (m.silbermuenze.tint as Color).v, "iron is a grey darker than silver")
	var gold: Color = m.goldmuenze.tint
	check(gold.r > gold.g and gold.g > gold.b * 2.0, "gold is a rich yellow")


## The piles on the floor wear their metal: its colour, smoothness and
## glints (none on iron).
func _on_the_floor(lvl: Level) -> void:
	for metal in ORDER:
		var piles := _piles(lvl, metal)
		check(not piles.is_empty(), "%s lies on the floor" % metal)
		for p in piles:
			var node: Node3D = p.node
			var glints := node.find_children(CoinShine.NAME + "*", "CPUParticles3D", true, false)
			check(glints.size() == (0 if metal == "eisenmuenze" else 1), "%s: %d glint emitters" % [metal, glints.size()])
			var mat := _coin_material(node)
			check(mat != null, "%s: the coins have a material" % metal)
			if mat == null:
				continue
			check(mat.albedo_color == CoinPile.METALS[metal].tint, "%s coins are tinted like their metal" % metal)
			check(is_equal_approx(mat.roughness, CoinPile.METALS[metal].roughness), "%s coins are as smooth as their metal" % metal)
			check(mat.emission_enabled and mat.emission == CoinPile.METALS[metal].glow, "%s coins glow faintly in their colour" % metal)


## A coin the map places (tile "c") is the money: copper, and looks it.
func _map_coin(lvl: Level, at: Vector3) -> void:
	var before := lvl._pickups.size()
	lvl._build_coin(at + Vector3(0, 0, 2.0))
	check(lvl._pickups.size() == before + 1, "the map's coin lies on the floor")
	var coin: Dictionary = lvl._pickups[-1]
	var mat := _coin_material(coin.node)
	check(mat != null and mat.albedo_color == CoinPile.METALS[CoinPile.MONEY].tint, "a map coin is copper like the money it is")
	check(coin.node.find_children(CoinShine.NAME + "*", "CPUParticles3D", true, false).size() == 1, "a map coin glints now and then")


func _coin_material(node: Node) -> StandardMaterial3D:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "Mound" and mi.material_override is StandardMaterial3D:
			return mi.material_override
	for mmi: MultiMeshInstance3D in node.find_children("Coins", "MultiMeshInstance3D", true, false):
		return mmi.material_override as StandardMaterial3D
	return null


## A look at `at` from `from` (relative), without the HUD or the fog of war.
func _shot(name: String, at: Vector3, from: Vector3, settle := 30) -> void:
	if shots == "":
		return
	var lvl: Level = game.level
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
