extends SceneTree
## The wealth tracker (see Wealth, WealthWindow, WealthChart): the sum of coins and sale values over the hero's
## belongings (bag, gear, chest, house stores, bank), one log point per day kept in the saved game, and the chart
## window that keeps one size whatever range or language.
## Run with: godot --headless -s tests/wealth.gd

const HERO := "Wealth test"

var failures := 0
var game: Node
var frames := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Bank.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _size() -> Vector2:
	return (game.menus._panel as Control).size


func _open(kind: String) -> Vector2:
	game.menus.open(kind)
	await _wait()
	return _size()


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _test() -> void:
	# The pure parts.
	check(Wealth.nice_top(0) == 4 and Wealth.nice_top(4) == 4, "a small scale tops at 4")
	check(Wealth.nice_top(5) == 5 and Wealth.nice_top(101) == 200 and Wealth.nice_top(2300) == 2500 and Wealth.nice_top(2501) == 4000, "the scale tops at a round number (%d %d)" % [Wealth.nice_top(101), Wealth.nice_top(2300)])
	check(Wealth.compact(950) == "950" and Wealth.compact(1200) == "1.2k" and Wealth.compact(3000) == "3k" and Wealth.compact(2500000) == "2.5M", "axis numbers are short")
	check(Wealth.grouped(1234567) == "1 234 567" and Wealth.grouped(12) == "12" and Wealth.grouped(-1500) == "-1 500", "numbers are grouped by thousands")
	check(Wealth.coins_worth({"kupfermuenze": 10, "silbermuenze": 2, "goldmuenze": 1}) == 10 + 50 + 250, "coins at their rate")
	var log := []
	Wealth.record(log, 1, 100)
	Wealth.record(log, 1, 140)
	Wealth.record(log, 2, 90)
	Wealth.record(log, 0, 5)
	check(log == [[1, 140], [2, 90]], "one point per day, the last reading of a day wins, the past is left alone (%s)" % [log])
	for d in range(3, Wealth.KEEP + 20):
		Wealth.record(log, d, d)
	check(log.size() == Wealth.KEEP and int(log.back()[0]) == Wealth.KEEP + 19, "the log keeps the newest %d days" % Wealth.KEEP)
	check(Wealth.load_from([[1, 5], [0, 9], "x", [3, 7.0], [3, 8], [4]]) == [[1, 5], [3, 7]], "a damaged log keeps only its sound pairs, in order")
	check(Wealth.load_from(null) == [] and Wealth.load_from({}) == [], "no log, an empty one")
	var win := [[1, 1], [5, 2], [9, 3], [10, 4]]
	check(Wealth.window(win, 3) == [[9, 3], [10, 4]] and Wealth.window(win, 0).size() == 4, "a range shows the last days")

	# The sum over a hero's belongings.
	game.hero_name = HERO
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	root.size = Vector2i(1280, 720)
	Lang.language = "en"
	Lang._apply()
	var p: Player = game.player
	p.bag.clear()
	p.equipped.clear()
	game.storage.clear()
	game.piece_stores = {}
	game.home_stores = HomeStores.empty()
	game.coins = 0
	game.crafting.purse.clear()
	var empty := Wealth.compute(game)
	check(int(empty.total) == 0, "a hero with nothing is worth nothing (%s)" % [empty])
	var priced := ""
	var quest := ""
	for id in Items.ALL:
		if priced == "" and Items.ALL[id].price >= 10 and not Items.is_quest(id):
			priced = id
		if quest == "" and Items.is_quest(id):
			quest = id
	var each := Menus.sell_price(priced)
	game.coins = 7
	p.bag.append(priced)
	p.bag.append(quest)
	game.storage.append(priced)
	game.piece_stores = {"crate1": [priced, priced]}
	game.home_stores[HomeStores.METAL][HomeStores.COINS] = 30
	Bank.deposit(HERO, 11)
	check(Bank.store(HERO, priced), "an item goes into the vault")
	var sum: Dictionary = Wealth.compute(game)
	check(int(sum.purse) == 7, "the purse counts the copper (%s)" % [sum])
	check(int(sum.carried) == each, "the bag counts what a merchant pays, a quest item nothing (%d vs %d)" % [sum.carried, each])
	check(int(sum.home) == 3 * each + 30, "chest, crate and house coins count (%d vs %d)" % [sum.home, 3 * each + 30])
	check(int(sum.bank) == 11 + each, "bank balance and vault count (%d)" % sum.bank)
	check(int(sum.total) == 7 + each + 3 * each + 30 + 11 + each, "the parts add up to the total")

	# Mornings and saving write the log and the saved game keeps it.
	game.wealth_log = []
	var day_before: int = game.day
	game._new_day(true)
	check(game.wealth_log.size() == 1 and int(game.wealth_log[0][0]) == day_before + 1 and int(game.wealth_log[0][1]) == int(sum.total), "a new morning writes a point (%s)" % [game.wealth_log])
	game.coins += 100
	var record: Dictionary = game.hero_record()
	check(record.get("wealth", []) == [[day_before + 1, int(sum.total) + 100]], "the saved game carries today's reading (%s)" % [record.get("wealth")])
	game.wealth_log = []
	game._new_day(true)
	game.coins -= 100
	var lines := [[1, 10], [2, 30], [3, 20]]
	record.wealth = lines
	check(Wealth.load_from(JSON.parse_string(JSON.stringify(record)).wealth) == lines, "the log survives the JSON round trip")

	# The window: one size for every range, with and without a chart, in both languages.
	check(Menus.fixed_size(WealthWindow.KIND) == WealthWindow.SIZE, "the window has a fixed size")
	var sizes := []
	for lang in ["en", "de"]:
		Lang.language = lang
		Lang._apply()
		for days in [0, 3, 40]:
			game.wealth_log = []
			for d in days:
				Wealth.record(game.wealth_log, d, 1000 + d * d * 37 % 5000)
			for key in ["7", "30", "all"]:
				WealthWindow.range_key = key
				sizes.append(await _open(WealthWindow.KIND))
				game.menus.close()
	for s in sizes:
		check(s == sizes[0], "the wealth window keeps its size (%s vs %s)" % [sizes[0], s])
	check(sizes[0] != Vector2.ZERO, "the window opens")
	# Opening it writes today's point; choosing a range rebuilds in place.
	Lang.language = "en"
	Lang._apply()
	game.wealth_log = [[0, 100], [1, 300], [2, 250], [3, 900]]
	game.day = 3
	WealthWindow.range_key = "7"
	var full := await _open(WealthWindow.KIND)
	check(int(game.wealth_log.back()[0]) == 3, "opening records today")
	await _shot("wealth")
	WealthWindow.range_key = "all"
	game.menus._rebuild()
	await _wait()
	check(_size() == full, "switching the range does not resize the window")
	var chart: WealthChart = _find_chart(game.menus._box)
	check(chart != null and chart.points.size() >= 2, "the chart holds the readings")
	if chart != null:
		check(chart.size == WealthChart.SIZE, "the chart keeps its size")
		var first: Vector2 = chart.point_at(0)
		var last: Vector2 = chart.point_at(chart.points.size() - 1)
		check(first.x < last.x and chart.plot().grow(1.0).has_point(first) and chart.plot().grow(1.0).has_point(last), "the chart draws inside its plot")
		check(chart.nearest(first.x + 1.0) == 0 and chart.nearest(last.x) == chart.points.size() - 1, "pointing finds the nearest day")
	# Reachable from the banker's window.
	game.menus.open("bank")
	await _wait()
	check(_has_button(game.menus._box, "Financial report"), "Goldwin offers the financial report")
	game.menus.close()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: the wealth tracker works")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _find_chart(node: Node) -> WealthChart:
	if node is WealthChart:
		return node
	for child in node.get_children():
		var found: WealthChart = _find_chart(child)
		if found != null:
			return found
	return null


func _has_button(node: Node, text: String) -> bool:
	if node is Button and node.text == text:
		return true
	for child in node.get_children():
		if _has_button(child, text):
			return true
	return false
