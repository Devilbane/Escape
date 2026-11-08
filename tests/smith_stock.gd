extends SceneTree
## Headless test for the needed-and-missing lines in the forge and Gorm's shelf
## of finished pieces: every piece lists its materials as green "✓" or red "✗"
## lines with the number that is missing, Gorm restocks a few pieces each
## morning up to a cap, a finished piece can be bought for copper, and an old
## save without a shelf gets one.
## Run with: godot --headless --fixed-fps 60 -s tests/smith_stock.gd

const HERO := "Stock test"

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
	var p: Player = game.player
	game.hero_name = HERO

	# The lines.
	var short := Needs.line("Eisen", 1, 3)
	check(short[0].begins_with("✗") and short[0].contains("1/3") and short[1] == TradeWindow.RED, "a missing material is a red cross with its numbers")
	var enough := Needs.line("Eisen", 5, 3)
	check(enough[0].begins_with("✓") and enough[1] == TradeWindow.GREEN, "enough is a green tick")

	# The shelf.
	var stock := {}
	Forge.restock(stock, 1, HERO)
	check(not stock.is_empty() and stock.size() <= Forge.RESTOCK_PER_DAY, "a morning puts a few pieces on the shelf")
	var again := {}
	Forge.restock(again, 1, HERO)
	check(again == stock, "the same day brings the same pieces")
	for day in 40:
		Forge.restock(stock, day, HERO)
	var capped := true
	for id in stock:
		capped = capped and int(stock[id]) <= Forge.STOCK_CAP
	check(capped, "a kind never goes over the cap")

	# Buying a finished piece.
	var id: String = Forge.recipes().filter(func(i): return not Forge.is_steel(i) and int(Items.ALL[i].get("thunder", 0)) == 0)[0]
	game.smith_stock = {id: 1}
	p.bag.clear()
	game.coins = 0
	check(Forge.buy_finished(game, id) != "" and Forge.in_stock(game, id) == 1, "without copper nothing is bought")
	game.coins = Forge.ware_price(game, id)
	check(Forge.buy_finished(game, id) == "" and p.bag.has(id) and game.coins == 0, "copper buys the finished piece")
	check(Forge.in_stock(game, id) == 0, "it leaves the shelf")
	check(Forge.buy_finished(game, id) != "", "an empty shelf sells nothing")

	# The window.
	game.smith_stock = {id: 1}
	game.coins = 1
	game.menus._forge_tab = "schmieden"
	game.menus.open("schmied")
	game.menus._forge_tab = "schmieden"
	game.menus._rebuild()
	check(game.menus._box != null and game.menus._box.get_child_count() > 0, "the forge window builds with the needs lines and the ready-made section")
	game.menus.close()

	game.delete_save(game.save_path())
	print("PASS: smith_stock" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
