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
	game.delete_save(game.save_path(game.hero_name))
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
	check(_has_text("Your gold: 379"), "the gold is shown at the top")
	check(_has_text("Equipment") and _has_text("Consumables"), "the categories are shown")
	check(trade._detail_box == null, "no cards before a row is picked")
	await _shot("merchant_grid")

	# Picking the crest shield compares it with the worn round shield.
	trade.pick(_key_of("wappenschild"))
	check(_has_text("Crest Shield") or _has_text(Items.item_name("wappenschild")), "the picked item has a card")
	check(_has_text("Currently Equipped") and _has_text("Comparison"), "the worn shield is compared")
	var diffs := TradeWindow.diffs("wappenschild", "rundschild")
	check(diffs.any(func(d): return d[0] and d[1].contains("Block chance")), "more block chance is better")
	check(TradeWindow.is_upgrade(TradeWindow.compare_with_worn(p, "wappenschild")), "the crest shield is an upgrade")
	check(_has_text("Upgrade"), "the upgrade badge shows")
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
	trade.collapsed["gear"] = false

	# Buying from the card still works.
	var before: int = game.coins
	menus._buy(game.shop_stock.find("schwert"))
	check(game.coins == before - Items.ALL["schwert"].price and p.bag.has("schwert"), "buying takes the gold and gives the item")

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

	# Gorm, Hagen and Benno use the same window.
	for kind in ["schmied", "steinmetz", "barbier"]:
		menus.open(kind)
		check(menus.is_open() and _has_text("Your gold"), "%s opens the trading window" % kind)
		await _shot("merchant_" + kind)
		menus.close()
	_finish()
