extends SceneTree
## Headless test for torches bundling in the storage chest just as in the bag:
## loose torches from an older save share one slot of five, the chest's count
## and grid show bundles (with "× n"), a torch still fits into a full chest when
## a bundle has room, and moving torches between bag and chest keeps them
## bundled on both sides. Everything is kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/storage_stacking.gd

const HERO := "Storage stacking test"

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


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: storage stacking")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## The texts of the item buttons in the chest's window that show a bundle.
func _bundle_texts() -> Array:
	var out := []
	for b in game.menus._box.find_children("*", "Button", true, false):
		if b.text.contains("× "):
			out.append(b.text)
	return out


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.home_upgrades.clear()
	var size := HomeUpgrades.storage_size(game.home_upgrades)

	# An older save: torches lie loose, one entry each, between other things.
	game.storage.assign(["fackel", "lederwams", "fackel", "kupferring", "fackel", "fackel"])
	check(HomeUpgrades.storage_used(game.storage) == 3, "four loose torches take one slot of the chest")
	var cells := Items.stacks(game.storage)
	check(cells.size() == 3 and cells[0].id == "fackel" and cells[0].count == 4, "the chest's first slot is a bundle of four torches")

	# The window shows the bundle and counts slots, not items.
	p.bag.clear()
	game.menus.open("lager")
	check(_bundle_texts().any(func(t): return t.contains("× 4")), "the chest shows the torches as one bundle of four")
	var heading := Lang.t("Truhe (%d / %d)") % [3, size]
	check(game.menus._box.find_children("*", "Label", true, false).any(func(l): return l.text == heading),
			"the chest's heading counts slots: 3 / %d" % size)

	# A full chest still takes a torch while its bundle has room, nothing else.
	game.storage.assign(["fackel", "fackel", "fackel"])
	while HomeUpgrades.storage_used(game.storage) < size:
		game.storage.append("lederwams")
	p.bag.assign(["fackel", "kupferring"])
	game.menus._store(0)
	check(game.storage.count("fackel") == 4 and not p.bag.has("fackel"), "a torch joins the chest's bundle even when the chest is full")
	game.menus._store(0)
	check(p.bag.has("kupferring") and game.menus._note == Lang.t("Die Truhe ist voll."), "another thing does not fit into the full chest")
	game.storage.append("fackel")
	check(not HomeUpgrades.storage_fits(game.home_upgrades, game.storage, "fackel"), "a full bundle of five opens no slot in a full chest")

	# Taking torches out bundles them in the bag again.
	game.storage.assign(["fackel", "fackel", "fackel", "fackel", "fackel", "fackel", "fackel"])
	check(HomeUpgrades.storage_used(game.storage) == 2, "seven torches are one bundle of five and one of two")
	p.bag.clear()
	game.menus.open("lager")
	for i in 7:
		game.menus._take(game.storage.size() - 1)
	check(game.storage.is_empty() and p.bag.count("fackel") == 7 and p.bag_used() == 2, "the torches taken out bundle in the bag")

	# Kept in the saved game.
	game.storage.assign(["fackel", "lederwams", "fackel"])
	check(game.save_game(), "the game saves")
	game.storage.clear()
	game._apply_save(game._read_save())
	check(game.storage.count("fackel") == 2 and HomeUpgrades.storage_used(game.storage) == 2, "loaded again, the torches still share a slot")
	game.menus.close()
	_finish()
