extends SceneTree
## Headless test for the compact trading window that every merchant uses
## (see TradeWindow): categories fold, a picked row shows its cards, the
## comparison with the worn item is right, buying still works, and Gorm's,
## Hagen's and Benno's windows open in the same layout.
## Run with: godot --headless -s tests/merchant_window.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
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
	if frames < 5:
		return false
	if frames == 5:
		_test()
	return false


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: merchant window")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _texts(node: Node) -> Array:
	var out := []
	if node is Label or node is Button:
		out.append(node.text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


func _has_text(text: String) -> bool:
	for t in _texts(game.menus._box):
		if t.contains(text):
			return true
	return false


## The window's size once it has laid itself out.
func _window_size() -> Vector2:
	await process_frame
	await process_frame
	return game.menus._panel.size


## The list of rows (the first scroll container in the window).
func _list_scroll() -> ScrollContainer:
	return game.menus._box.find_children("*", "ScrollContainer", true, false)[0]


## Where every row of the list is on screen.
func _row_rects() -> Array:
	var out := []
	for grid in game.menus._box.find_children("*", "GridContainer", true, false):
		for row in grid.get_children():
			out.append((row as Control).get_global_rect())
	return out


## The key of the first row showing an item.
func _key_of(id: String) -> String:
	for key in game.menus.trade._entries:
		if game.menus.trade._entries[key].get("id", "") == id:
			return key
	return ""


func _shot(name: String) -> void:
	if shots == "":
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _test() -> void:
	Lang.language = "en"
	Lang._apply()
	game.hero_name = "Merchant window test"
	var p: Player = game.player
	var menus: Menus = game.menus
	var trade: TradeWindow = menus.trade
	game.load_level(game._outdoor_index(), false)
	game.coins = 379
	p.bag.clear()
	p.equipped.clear()
	p.bag.append("rundschild")
	p.equip("rundschild")
	game.shop_stock.assign(["schwert", "wappenschild", "stachelschild", "lederstiefel", "eilstiefel", "amulett_leben", "baerenkappe", "lederwams", "wurfbuch", "schildbuch"])

	# Mira: gold on top, two categories in two columns, no cards yet.
	menus.open("haendler")
	check(_has_text("Your copper: 379"), "the money is shown at the top")
	check(_has_text("Equipment") and _has_text("Consumables"), "the categories are shown")
	check(_has_text("Point at an item"), "the panel shows a hint before a row is picked")
	var start_size := await _window_size()
	await _shot("merchant_grid")

	# Picking the crest shield compares it with the worn round shield.
	trade.pick(_key_of("wappenschild"))
	check(_has_text("Crest Shield") or _has_text(Items.item_name("wappenschild")), "the picked item has a card")
	check(_has_text("Currently Equipped") and _has_text("Comparison"), "the worn shield is compared")
	var diffs := TradeWindow.diffs("wappenschild", "rundschild")
	check(diffs.any(func(d): return d[0] and d[1].contains("Block chance")), "more block chance is better")
	check(TradeWindow.is_upgrade(TradeWindow.compare_with_worn(p, "wappenschild")), "the crest shield is an upgrade")
	check(_has_text("Upgrade"), "the upgrade badge shows")
	check(await _window_size() == start_size, "picking a row keeps the window's size")
	await _shot("merchant_compare_shield")

	# Boots: nothing worn on the feet yet.
	trade.pick(_key_of("lederstiefel"))
	check(_has_text("No Item Equipped") and _has_text("new item"), "an empty place says it is new")
	await _shot("merchant_new_item")

	# A worse item shows red arrows and no badge.
	p.bag.append("plattenpanzer")
	p.equip("plattenpanzer")
	trade.pick(_key_of("lederwams"))
	check(not TradeWindow.is_upgrade(TradeWindow.compare_with_worn(p, "lederwams")), "a leather jerkin is no upgrade on plate")
	check(not _has_text("Upgrade"), "no badge for a worse item")
	await _shot("merchant_compare_worse")

	# Folding a category hides its rows.
	trade.collapsed["gear"] = true
	menus._rebuild()
	check(not _has_text("Swift Boots"), "a folded category hides its rows")
	check(await _window_size() == start_size, "folding a category keeps the window's size")
	trade.collapsed["gear"] = false

	# Buying from the card still works.
	var before: int = game.coins
	menus._buy(game.shop_stock.find("schwert"))
	check(game.coins == before - Items.buy_price("schwert") and p.bag.has("schwert"), "buying takes the gold and gives the item")

	# Buying keeps everything in place: rows keep their order, a sold-out
	# row stays (dimmed), the pick, the scroll and every row's place stay.
	menus.close()
	game.shop_stock.assign(["schwert", "lederwams", "lederwams", "wappenschild", "stachelschild", "lederstiefel", "kupferring", "bronzearmreif", "wurfbuch", "schildbuch", "axtbuch"])
	game.coins = 300
	p.bag.clear()
	menus.open("haendler")
	await _window_size()
	var order: Array = trade._entries.keys()
	check(order.has("ware:wurst") and order.count("ware:lederwams") == 1, "sausages and a stack each have one row")
	check(_has_text("×2"), "a stack shows how many there are")
	trade.pick("ware:lederwams")
	var list := _list_scroll()
	await _window_size()
	list.scroll_vertical = 60
	var size_before := await _window_size()
	var rects := _row_rects()
	var scrolled := list.scroll_vertical
	menus._buy(game.shop_stock.find("wurst"))
	await _window_size()
	check(game.shop_stock.count("wurst") == 2 and p.bag.has("wurst"), "sausages never run out")
	check(trade._entries.keys() == order, "buying a sausage moves no row")
	check(await _window_size() == size_before, "buying a sausage keeps the window's size")
	check(_row_rects() == rects, "buying a sausage keeps every row in its place")
	check(_list_scroll().scroll_vertical == scrolled and scrolled > 0, "buying keeps the list's scroll position")
	menus._buy(game.shop_stock.find("lederwams"))
	menus._buy(game.shop_stock.find("lederwams"))
	check(not game.shop_stock.has("lederwams") and p.bag.count("lederwams") == 2, "the whole stack can be bought")
	check(trade._entries.keys() == order, "a sold-out item keeps its row")
	check(trade._entries["ware:lederwams"].has("gone") and _has_text("Sold out"), "the sold-out row says so")
	check(trade.selected == "ware:lederwams", "the picked row stays picked")
	check(await _window_size() == size_before and _row_rects() == rects, "selling out moves nothing")
	await _shot("merchant_sold_out")

	# Selling keeps its rows in place too.
	menus._show_shop_page("verkaufen")
	await _window_size()
	var sell_order: Array = trade._entries.keys()
	var sell_rects := _row_rects()
	menus._sell(p.bag.find("lederwams"))
	menus._sell(p.bag.find("lederwams"))
	check(trade._entries.keys() == sell_order and trade._entries["sell:lederwams"].has("gone"), "a sold-off item keeps its row")
	await _window_size()
	check(_row_rects() == sell_rects, "selling moves no row")
	menus.close()
	p.bag.append("schwert")
	menus.open("haendler")

	# Selling is a page of its own: the bag, not the wares.
	check(not _has_text("Sell") or not _key_of("schwert").begins_with("sell"), "the buy page shows no bag items")
	menus._show_shop_page("verkaufen")
	check(_key_of("schwert").begins_with("sell:") and not _has_text(Items.item_name("lederwams")), "the sell page shows the bag only")
	await _shot("merchant_sell")
	before = game.coins
	menus._sell(p.bag.find("schwert"))
	check(game.coins == before + Menus.sell_price("schwert") and not p.bag.has("schwert"), "selling gives gold for the item")
	menus.close()
	menus.open("haendler")
	check(menus._shop_page == "kaufen", "the window opens on the buy page")
	menus.close()

	# Merchants sell only plain gear: no specials, magic, unique or top tier.
	for id in ["vampirzahn", "phoenixfeder", "rabenklinge", "zauberhut", "amulett_kraft", "schattenumhang", "plattenpanzer", "eilstiefel", "rubinring", "kriegshammer", "drachenschild"]:
		check(not Items.merchant_sells(id), "%s is not sold by merchants" % id)
	for id in ["schwert", "rundschild", "lederwams", "kettenhemd", "kupferring", "bronzearmreif", "wurfbuch"]:
		check(Items.merchant_sells(id), "%s is sold by merchants" % id)
	var rng := RandomNumberGenerator.new()
	for i in 500:
		rng.seed = i
		check(Items.merchant_sells(Items.random_ware(rng)), "random stock is plain gear")
	game.load_level(game._outdoor_index(), true)
	if not game.shop_stock.is_empty():
		check(game.shop_stock.all(func(id): return Items.merchant_sells(id)), "the restocked shop sells only plain gear")

	# Gorm, Hagen and Benno use the same window.
	for kind in ["schmied", "steinmetz", "barbier"]:
		menus.open(kind)
		check(menus.is_open() and _has_text("Your copper"), "%s opens the trading window" % kind)
		await _shot("merchant_" + kind)
		menus.close()
	_finish()
