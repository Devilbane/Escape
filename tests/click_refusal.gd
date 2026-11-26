extends SceneTree
## Headless test: a click on open ground walks the hero there or says why not (see ClickRefusal).
## A reachable spot gives no refusal; water, rock and an off-map spot do, with the right text and
## a red cross; a refused click still walks the hero as far as the path leads.
## Run with: godot --headless --fixed-fps 60 -s tests/click_refusal.gd

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


## The first cell of the level whose letter is in `letters`, as a world point (null for none).
func _find(lvl: Level, letters: String):
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if letters.contains(lvl.cell_char(c)) and lvl.astar.is_point_solid(c):
				return lvl.cell_to_world(c)
	return null


func _verdict_for(point: Vector3) -> String:
	var hero: Node = game.player
	hero.walk_to(point)
	var why := ClickRefusal.verdict(game.level, hero.global_position, point, hero.path)
	hero.path.clear()
	return why


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var lvl: Level = game.level
	var hero: Node = game.player

	# Open ground a few tiles away on a free cell: no refusal.
	var near: Vector3 = hero.global_position + Vector3(Level.TILE * 2.0, 0.0, 0.0)
	var cell := lvl.world_to_cell(near)
	if lvl.astar.is_in_boundsv(cell) and not lvl.astar.is_point_solid(cell):
		check(_verdict_for(lvl.cell_to_world(cell)) == "", "a free reachable cell is no refusal")
	check(_verdict_for(hero.global_position) == "", "clicking where the hero stands is no refusal")

	var water = _find(lvl, ClickRefusal.WATER)
	check(water != null, "the outdoor map has water")
	if water != null:
		check(_verdict_for(water) == ClickRefusal.TEXT_WATER, "water says it is water")
	var rock = _find(lvl, ClickRefusal.MOUNTAIN)
	check(rock != null, "the outdoor map has mountain rock")
	if rock != null:
		check(_verdict_for(rock) == ClickRefusal.TEXT_STEEP, "rock says it is too steep")

	# Off the map: refused, never silent.
	var off := Vector3(-Level.TILE * 40.0, 0.0, -Level.TILE * 40.0)
	check(_verdict_for(off) != "", "a spot far off the map is refused")

	# A walled-off cell with no way in: unreachable or partial, never silent.
	var sealed := Vector3.ZERO
	var have_sealed := false
	for y in range(1, lvl.height - 1):
		for x in range(1, lvl.width - 1):
			var c := Vector2i(x, y)
			if lvl.astar.is_point_solid(c):
				continue
			var boxed := true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if not lvl.astar.is_point_solid(c + d):
					boxed = false
			if boxed:
				sealed = lvl.cell_to_world(c)
				have_sealed = true
				break
		if have_sealed:
			break
	if have_sealed:
		check(_verdict_for(sealed) != "", "a free cell walled in on all sides is refused")

	# The cross appears, and goes again.
	var before := lvl.get_child_count()
	var cross := ClickRefusal.mark(lvl, Vector3(4.0, 0.0, 4.0))
	check(lvl.get_child_count() == before + 1 and cross.get_child_count() == 2, "the refusal cross is a two-bar mark")

	# Every text has an English entry.
	for key in [ClickRefusal.TEXT_WATER, ClickRefusal.TEXT_STEEP, ClickRefusal.TEXT_BLOCKED, ClickRefusal.TEXT_UNREACHABLE, ClickRefusal.TEXT_PARTIAL, ClickRefusal.TEXT_SKY, ClickRefusal.TEXT_WALL]:
		check(Lang.EN.has(key), "English text for " + key)

	print("PASS: click refusal" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
