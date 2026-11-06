extends SceneTree
## Headless test for the healing fountains: the one in the refuge of the
## first dungeon (Die Zuflucht, header "fountain: 5") gives back 5 life per
## drink; a fountain without that header still heals fully.
## Run with: godot --headless --fixed-fps 60 -s tests/fountain.gd

var failures := 0
var game: Node
var frames := 0


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
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _fountain() -> Dictionary:
	for s in game.level.stations:
		if s.kind == "brunnen":
			return s
	return {}


func _test() -> void:
	game.hero_name = "Fountain test"
	game.load_level(4, false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	check(game.level.level_name == "Die Zuflucht", "level 5 is the refuge (%s)" % game.level.level_name)
	check(game.level.fountain_heal == 5, "the refuge's fountain gives 5 life (%d)" % game.level.fountain_heal)
	var fountain := _fountain()
	check(not fountain.is_empty(), "the refuge has a fountain")
	if fountain.is_empty():
		_finish()
		return

	# Lots of life missing: one drink gives back exactly 5.
	p.gift_hp = 20
	p.refresh_stats()
	p.hp = 1
	game._drink(fountain)
	check(p.hp == 6, "one drink gives back 5 life (1 -> %d)" % p.hp)
	game._drink(fountain)
	check(p.hp == 11, "each drink gives 5 more (-> %d)" % p.hp)
	# Never more than the most life.
	p.hp = p.max_hp - 2
	game._drink(fountain)
	check(p.hp == p.max_hp, "a drink stops at the most life (%d / %d)" % [p.hp, p.max_hp])
	# It still cures ailments.
	p.ailments["gift"] = 5.0
	game._drink(fountain)
	check(not p.ailments.has("gift"), "the water still cures poison")

	# Without the header a fountain heals fully, as before.
	game.level.fountain_heal = 0
	p.hp = 1
	game._drink(fountain)
	check(p.hp == p.max_hp, "a fountain without the header heals fully (%d / %d)" % [p.hp, p.max_hp])
	p.gift_hp = 0
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: fountain")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
