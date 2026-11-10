extends SceneTree
## Headless test: the shopkeeper always has a backpack of each kind for sale, and
## buying one never runs the shelf dry.
## Run with: godot --headless -s tests/shop_backpacks.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var kinds := Items.shop_backpacks()
	check(kinds.size() >= 3, "the shop offers several backpacks")
	check(not kinds.has("reiserucksack"), "the biggest backpack is never sold")
	for i in kinds.size() - 1:
		check(Items.ALL[kinds[i]].bag < Items.ALL[kinds[i + 1]].bag, "backpacks are listed smallest first")
	var stock: Array = ["schwert"]
	Items.restock_backpacks(stock)
	for id in kinds:
		check(stock.count(id) == 1, "empty shelf gets one %s" % id)
	Items.restock_backpacks(stock)
	check(stock.size() == 1 + kinds.size(), "restocking twice adds nothing")
	stock.erase(kinds[0])
	Items.restock_backpacks(stock)
	check(stock.has(kinds[0]), "a sold backpack is back at once")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)
