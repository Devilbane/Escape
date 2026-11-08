extends SceneTree
## Headless test for the comparison in the inventories' details box: pointing
## at an item shows green numbers where it beats the worn item in its place,
## red where it is worse, plain words when equal, all green for a free place,
## and nothing for things that are not worn.
## Run with: godot --headless -s tests/item_compare.gd

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


func _test() -> void:
	var p: Player = game.player
	var green := TradeWindow.GREEN.to_html(false)
	var red := TradeWindow.RED.to_html(false)
	p.equipped.clear()

	# A free place: everything the item brings is a gain.
	var line := TradeWindow.compare_bbcode(p, "kupferring")
	check(line.contains(green) and not line.contains(red), "a free place shows only green: %s" % line)
	check(line.contains("+1"), "the free place line names the gain: %s" % line)

	# Better and worse against a worn ring of the same place.
	p.equipped["ring"] = "kupferring"
	line = TradeWindow.compare_bbcode(p, "rubinring")
	check(line.contains("[color=#%s]+1" % green), "a better ring shows a green gain: %s" % line)
	line = TradeWindow.compare_bbcode(p, "kupferring")
	check(line.contains("Gleiche Werte") or line.contains("Same values"), "an equal ring says so in plain words: %s" % line)
	p.equipped["ring"] = "rubinring"
	line = TradeWindow.compare_bbcode(p, "kupferring")
	check(line.contains("[color=#%s]-1" % red), "a worse ring shows a red loss: %s" % line)

	# Things that are not worn have no comparison.
	check(TradeWindow.compare_bbcode(p, "") == "", "no item, no comparison")
	for id in Items.ALL:
		var slot: String = Items.ALL[id].slot
		if not slot in Items.SLOTS and slot != "spezial":
			check(TradeWindow.compare_bbcode(p, id) == "", "%s is not worn, so no comparison" % id)
			break

	# The details box shows it for a bag item, but not for the worn one itself.
	var menus = game.menus
	p.bag.clear()
	p.bag.append("kupferring")
	menus.open("inventar")
	menus._show_info("kupferring")
	check(menus._info.text.contains("[color=#%s]" % red), "the details box shows the comparison")
	menus._show_info("rubinring", false)
	check(not menus._info.text.contains("[color=#%s]" % red), "a worn item is not compared with itself")
	menus.close()

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: item compare")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
