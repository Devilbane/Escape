extends SceneTree
## Headless test: the woodcutter's timber stock (see WoodcutterShift). He starts
## with 200 pieces, cuts one every 20 seconds while he chops, up to 999, sells
## only what he has, takes back what the hero sells, and keeps to his trunk
## through his shift except for his breaks.
## Run with: godot --headless --fixed-fps 60 -s tests/woodcutter_stock.gd

var failures := 0
var game: Node
var frames := 0
var started := false


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


func _run() -> void:
	# The shift: at work in the morning and afternoon, off at midday, supper and evening.
	check(WoodcutterShift.at_work(9.0), "at work at 9")
	check(not WoodcutterShift.at_work(12.5) and WoodcutterShift.on_break(12.5), "on his midday break at 12:30")
	check(not WoodcutterShift.at_work(17.2) and WoodcutterShift.on_break(17.2), "at supper at 17:12")
	check(not WoodcutterShift.at_work(20.0) and not WoodcutterShift.on_break(20.0), "his shift is over at 20")
	# Cutting: one piece every 20 seconds, never past the cap.
	check(WoodcutterShift.cut(200, 0.0, 19.0) == [200, 19.0], "nothing before 20 seconds")
	check(WoodcutterShift.cut(200, 19.0, 2.0)[0] == 201, "one piece after 20 seconds")
	check(WoodcutterShift.cut(200, 0.0, 100.0)[0] == 205, "five pieces in 100 seconds")
	check(WoodcutterShift.cut(998, 0.0, 100.0)[0] == WoodcutterShift.CAP, "never more than 999")
	check(game.timber_stock == WoodcutterShift.START, "a new game starts him with 200 (%d)" % game.timber_stock)

	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var p: Player = game.player
	# Selling from his stock: it runs out.
	p.bag.clear()
	var price: int = game.trader_price(Items.buy_price("bauholz"))
	game.coins = price * 100
	game.timber_stock = 3
	game.menus.open("holzfaeller")
	game.menus._buy_timber(10)
	check(p.bag.count("bauholz") == 3 and game.timber_stock == 0, "he sells only the 3 he has (%d)" % p.bag.count("bauholz"))
	game.menus._buy_timber(1)
	check(p.bag.count("bauholz") == 3, "an empty stock sells nothing")
	game.menus._sell_timber()
	check(game.timber_stock == 1 and p.bag.count("bauholz") == 2, "timber sold back goes into his stock")
	game.menus.close()
	# The stock is kept in the saved game.
	game.timber_stock = 321
	var saved: Dictionary = game.hero_record()
	check(int(saved.get("timber_stock", -1)) == 321, "the stock is saved (%s)" % saved.get("timber_stock", "none"))
	# While he chops, the stock grows.
	var cutter: Villager = null
	for v: Villager in game.level.villagers:
		if v.role == "3":
			cutter = v
	check(cutter != null, "the woodcutter is in the village")
	if cutter != null:
		game.timber_stock = 10
		game._timber_carry = 0.0
		# In the morning of his shift he gets to his trunk and chops.
		game.day_hour = 9.0
		for i in 1800:
			if cutter.is_chopping():
				break
			await physics_frame
		check(cutter.is_chopping(), "at 9 in the morning he chops at his trunk")
		game.timber_stock = 10
		game._timber_carry = 0.0
		game._tick_timber(45.0)
		check(game.timber_stock == 12, "chopping for 45 s cuts 2 pieces (%d)" % game.timber_stock)
		# Over his shift he never strays from his trunk.
		var strayed := false
		for i in 1800:
			await physics_frame
			if game.level.world_to_cell(cutter.global_position) != cutter.home and not game.level.village_alarm.raised:
				strayed = true
		check(not strayed, "through his shift he keeps to his trunk")
	print("PASS: woodcutter stock" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
