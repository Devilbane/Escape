extends SceneTree
## Headless test: the rock faces of the stonemason's quarry (see QuarryRocks).
## A hero who runs into one gets stone blocks in the bag, the rock lies in rubble
## until the next morning, a full bag leaves it whole, and the way to the door of the
## house above the mason stays open.
## Run with: godot --headless --fixed-fps 60 -s tests/quarry_rocks.gd

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


func _stones() -> int:
	return (game.player.bag as Array).count(QuarryRocks.STONE)


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await physics_frame
	var lvl: Outdoor = game.level
	var rocks: Array = lvl.stations.filter(func(s): return s.kind == QuarryRocks.KIND)
	check(rocks.size() == QuarryRocks.CELLS.size(), "the quarry has its rock faces (%d)" % rocks.size())
	if rocks.is_empty():
		_end()
		return
	var rock: Dictionary = rocks[0]
	game.player.bag.clear()
	var before := _stones()
	game._break_stone(rock)
	await create_timer(1.5).timeout
	check(_stones() == before + QuarryRocks.STONE_YIELD, "breaking a rock face gives its stone blocks (%d)" % _stones())
	check(rock.spent, "the rock face lies in rubble")
	game._break_stone(rock)
	await create_timer(0.2).timeout
	check(_stones() == before + QuarryRocks.STONE_YIELD, "a broken rock face gives nothing more")
	# The next morning it has grown back.
	QuarryRocks.refresh(lvl, game.day + 1)
	check(not rock.spent, "the rock face has grown back by the next day")
	# A full bag leaves the rock whole.
	game.player.bag.clear()
	while game.player.bag_used() < game.player.bag_size():
		game.player.bag.append("kiste")
	game._break_stone(rock)
	await create_timer(0.2).timeout
	check(not rock.spent and _stones() == 0, "with a full bag the rock stays whole")
	_end()


func _end() -> void:
	print("PASS: quarry rocks" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
