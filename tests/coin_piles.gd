extends SceneTree
## Headless test: coin piles (CoinPile). Coins of one metal that come down on
## the same spot join one pile, up to CoinPile.MAX; the bigger the pile, the
## bigger it looks and the more it glints and blinks; every pile glows in its
## metal's colour. The hero puts coins down from the coin tab of the
## inventory, and picks the pile up again after stepping away.
## Run with: godot --headless --fixed-fps 60 -s tests/coin_piles.gd
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
	seed(5)
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
	print("PASS: coin piles" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


func _piles(lvl: Level, metal := "") -> Array:
	return lvl._pickups.filter(func(p): return p.kind == "coin" and p.has("floor") and (metal == "" or p.metal == metal))


func _total(lvl: Level) -> int:
	var n := 0
	for p in _piles(lvl):
		n += CoinPile.count_of(p.floor)
	return n


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = "Pile test"
	await _wait(10)
	_rules()
	await _joining()
	await _put_down()
	await _coin_tab()
	await _night_shot()
	_finish()


## The look follows the count: bigger, more glints, faster blinking, brighter
## glow; the biggest pile holds CoinPile.MAX.
func _rules() -> void:
	var counts := [1, 5, 20, 100, 1000, CoinPile.MAX]
	for i in range(1, counts.size()):
		var a: int = counts[i - 1]
		var b: int = counts[i]
		check(CoinPile.radius(b) > CoinPile.radius(a), "a pile of %d is bigger than one of %d" % [b, a])
		check(CoinPile.glints_of(b).amount >= CoinPile.glints_of(a).amount, "a pile of %d glints at least as much as one of %d" % [b, a])
		check(CoinPile.glints_of(b).lifetime < CoinPile.glints_of(a).lifetime, "a pile of %d blinks faster than one of %d" % [b, a])
		check(CoinPile.glow_of(b).alpha > CoinPile.glow_of(a).alpha, "a pile of %d glows brighter than one of %d" % [b, a])
	var grows := true
	for n in range(2, CoinPile.MAX + 1):
		grows = grows and CoinPile.radius(n) >= CoinPile.radius(n - 1)
	check(grows, "a pile never gets smaller as coins are added")
	check(CoinPile.glints_of(1).amount == 1, "a lone coin has one glint")
	check(CoinPile.metal_of("") == CoinPile.MONEY and CoinPile.count_of(["coin", "", 1.0, 1.0]) == 1, "an old save's coin is one gold coin")


## Coins on one spot join one pile; another metal or another spot makes its
## own; a full pile starts a new one beside it.
func _joining() -> void:
	var lvl: Level = game.level
	var at: Vector3 = lvl.cell_to_world(lvl.start_cell) + Vector3(0, 0, 3.0)
	game.player.global_position = Vector3(at.x + 30.0, game.player.global_position.y, at.z + 30.0)
	for p in _piles(lvl):
		lvl.take_from_floor(p)
	lvl.lay_coins(at, 3)
	lvl.lay_coins(at + Vector3(0.5, 0, 0.3), 4)
	check(_piles(lvl).size() == 1 and _total(lvl) == 7, "coins on one spot join one pile (%d in %d)" % [_total(lvl), _piles(lvl).size()])
	var pile: Dictionary = _piles(lvl)[0]
	check(pile.node.find_children(CoinPile.GLOW, "CPUParticles3D", true, false).size() == 1, "a pile glows")
	var small: int = pile.node.find_children(CoinShine.NAME + "*", "CPUParticles3D", true, false)[0].amount
	lvl.lay_coins(at, 500)
	check(_piles(lvl).size() == 1 and CoinPile.count_of(pile.floor) == 507, "more coins on the spot make the pile bigger (%d)" % CoinPile.count_of(pile.floor))
	var glints: Array = pile.node.find_children(CoinShine.NAME + "*", "CPUParticles3D", true, false)
	check(glints.size() == 1 and glints[0].amount > small, "a bigger pile has more glints")
	check(pile.radius > 1.5, "a big pile is picked up from a little further off (%.2f)" % pile.radius)
	lvl.lay_coins(at + Vector3(6.0, 0, 0), 2)
	check(_piles(lvl).size() == 2, "coins on another spot make their own pile")
	lvl.lay_coins(at, 3, "silbermuenze")
	check(_piles(lvl, "silbermuenze").size() == 1 and _piles(lvl, CoinPile.MONEY).size() == 2, "another metal makes its own pile")
	lvl.lay_coins(at, CoinPile.MAX)
	var gold := _piles(lvl, CoinPile.MONEY)
	var full := gold.filter(func(p): return CoinPile.count_of(p.floor) == CoinPile.MAX)
	check(full.size() == 1 and _total(lvl) == 7 + 500 + 2 + 3 + CoinPile.MAX, "a pile holds at most %d, the rest starts a new one (%s)" % [CoinPile.MAX, str(gold.map(func(p): return CoinPile.count_of(p.floor)))])
	# Kept on the floor list as they are, piled.
	var kept: Array = lvl.floor_items.duplicate(true)
	check(kept.filter(func(e): return e[0] == "coin").size() == _piles(lvl).size(), "one floor entry per pile")
	for p in _piles(lvl):
		lvl.take_from_floor(p)
		p.node.queue_free()
	await _wait()
	lvl.floor_items = kept
	lvl.restore_floor()
	check(_piles(lvl).size() == kept.filter(func(e): return e[0] == "coin").size() and _total(lvl) == 7 + 500 + 2 + 3 + CoinPile.MAX, "the piles come back as they were (%d)" % _total(lvl))
	await _shot("piles_dungeon", at + Vector3(0.6, 0.4, 0), Vector3(0.0, 4.2, 6.0))
	for p in _piles(lvl):
		lvl.take_from_floor(p)
		p.node.queue_free()
	await _wait()


## The hero puts coins down, steps off and comes back for them; the lucky
## clover does not double what was the hero's own.
func _put_down() -> void:
	var lvl: Level = game.level
	var p: Player = game.player
	var start := p.global_position
	game.coins = 50
	check(game.put_coins_down(CoinPile.MONEY, 20) == 20 and game.coins == 30, "twenty coins go down (%d left)" % game.coins)
	check(game.put_coins_down(CoinPile.MONEY, 500) == 30 and game.coins == 0, "no more than carried go down")
	var piles := _piles(lvl)
	check(piles.size() == 1 and CoinPile.count_of(piles[0].floor) == 50 and CoinPile.own_of(piles[0].floor) == 50, "they lie in one pile at the hero's feet")
	await _wait(10)
	check(game.coins == 0, "not picked up again right away")
	# Found coins join the hero's own.
	lvl.lay_coins(piles[0].node.position, 10)
	p.global_position = start + Vector3(8.0, 0, 0)
	await _wait(10)
	p.global_position = start
	await _wait(10)
	check(game.coins == 60 and _piles(lvl).is_empty(), "stepping off and back picks the pile up (%d)" % game.coins)


## The coin tab of the inventory: amounts and the button to put them down.
func _coin_tab() -> void:
	var menus: Menus = game.menus
	game.coins = 120
	menus.open("inventar")
	await _wait()
	menus._show_inventory_tab("tasche")
	await _wait()
	var size: Vector2 = menus._panel.size
	menus._show_inventory_tab("muenzen")
	await _wait()
	check(menus._panel.size == size, "the coin tab keeps the window's size (%s, was %s)" % [menus._panel.size, size])
	var edits := menus._box.find_children("Amount", "LineEdit", true, false)
	check(edits.size() == game.coin_metals().size(), "a field for each metal carried")
	menus._set_coin_amount(CoinPile.MONEY, 100)
	await _wait()
	check((menus._box.find_children("Amount", "LineEdit", true, false)[0] as LineEdit).text == "100", "the quick amount shows in the field")
	await _shot_ui("coin_tab")
	menus._put_coins_down(CoinPile.MONEY)
	await _wait()
	check(game.coins == 20 and _total(game.level) == 100, "the button puts them down (%d left, %d on the floor)" % [game.coins, _total(game.level)])
	check(menus._note != "", "a note says what went down")
	check(int(menus.coin_amounts[CoinPile.MONEY]) == 20, "the amount shrinks to what is left")
	menus.close()
	for p in _piles(game.level):
		game.level.take_from_floor(p)
		p.node.queue_free()
	await _wait()


## Piles of every metal and size at night in the open air.
func _night_shot() -> void:
	if shots == "":
		return
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Level = game.level
	lvl.set_hour(23.5)
	game.day_hour = 23.5
	var at: Vector3 = lvl.doors.E + Vector3(10.0, 0, 12.0)
	game.player.global_position = Vector3(at.x, game.player.global_position.y, at.z + 9.0)
	var row := [[CoinPile.MONEY, 1], [CoinPile.MONEY, 12], [CoinPile.MONEY, 300], [CoinPile.MONEY, CoinPile.MAX],
		["silbermuenze", 4], ["silbermuenze", 800], ["kupfermuenze", 30], ["eisenmuenze", 2500]]
	for i in row.size():
		var spot := at + Vector3((i % 4) * 3.2 - 4.8, 0, (i / 4) * 3.4 - 1.7)
		lvl.lay_coins(spot, row[i][1], row[i][0])
	await _shot("piles_night", at, Vector3(0.0, 7.0, 9.0), 40)
	lvl.set_hour(13.0)
	game.day_hour = 13.0
	await _shot("piles_day", at, Vector3(0.0, 7.0, 9.0), 40)
	lvl.set_hour(23.5)
	game.day_hour = 23.5
	game.player.global_position = Vector3(at.x, game.player.global_position.y, at.z - 30.0)
	await _shot("piles_night_dark", at, Vector3(0.0, 7.0, 9.0), 40)


func _shot_ui(name: String) -> void:
	if shots == "":
		return
	await _wait(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


## A look at `at` from `from` (relative), without the HUD or the fog of war.
func _shot(name: String, at: Vector3, from: Vector3, settle := 20) -> void:
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
