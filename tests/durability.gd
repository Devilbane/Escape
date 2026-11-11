extends SceneTree
## Headless test for item durability: the condition of a piece, the rim overlay that dims it
## from the top down, and the destroyed state (no equipping, no mending, only melting).
## Run with: godot --headless -s tests/durability.gd

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
	elif frames == 8:
		game.delete_save(game.save_path())
		print("PASS: durability" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
	return false


func _test() -> void:
	game.hero_name = "Durability test"
	var p: Player = game.player
	var id := "rundschild"
	check(Items.condition(id, 0) == 1.0, "a new piece is intact")
	check(is_equal_approx(Items.condition(id, 1), 0.8), "one of five points gone leaves 80%")
	check(Items.condition("kettenhemd", 99) == 0.0, "condition never drops below 0")
	check(Items.condition("fackel", 3) == 1.0, "a piece that does not wear is always intact")
	check(not Items.is_broken(id, 4) and Items.is_broken(id, 5), "broken at 0 points")

	var rim := DurabilityRim.make(0.6, 5, 5)
	check(is_equal_approx(rim.anchor_bottom, 0.4), "the dimmed part is the worn share, from the top")
	check(DurabilityRim.make(0.0, 5, 5).anchor_bottom == 1.0, "a destroyed piece is dimmed all round")
	rim.free()

	# A piece worn through comes off and waits in the bag.
	p.bag.clear()
	p.equipped["schild"] = id
	p.wear[id] = 4
	p._wear_down("schild")
	check(not p.equipped.has("schild") and p.bag.has(id), "a worn-through piece moves to the bag")
	check(Items.is_broken(id, p.wear.get(id, 0)), "and stays destroyed")
	check(not p.equip(id), "a destroyed piece cannot be put on")
	check(Forge.melt_into(id, true).size() > 0, "a destroyed piece melts into its parts")
	check(Forge.worn_down(p).is_empty(), "the smith does not mend a destroyed piece")
	check(Forge.mend(game, id) != "", "mending a destroyed piece is refused")
	check(Forge.melt(game, p.bag.find(id)) == "", "it can be melted down")
	check(not p.bag.has(id) and not p.wear.has(id), "and is gone with its wear")
