extends SceneTree
## Headless test for the Forsaken Wasteland and Mirenna's ruined shrine (see
## Wasteland, RuinedShrine): the gate on the open-air map, the floor with its
## shrine and hermit, praying, and mending the shrine step by step.
## Run with: godot --headless --fixed-fps 60 -s tests/wasteland.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0


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
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			game.hero_name = "Wasteland test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			var out: Level = game.level
			check(out.doors.has(Wasteland.BUILDING), "the open-air map has the wasteland's gate")
			check(out.stations.any(func(s): return s.kind == "eingang" and s.building == Wasteland.BUILDING), "running into the gate goes in")
			game.go_inside(Wasteland.BUILDING)
			wait = 40
			stage = 1
		1:
			var lvl: Level = game.level
			check(lvl.building == Wasteland.BUILDING and lvl.theme == Wasteland.THEME, "inside the wasteland")
			check(not lvl.safe, "the wasteland has monsters")
			check(RuinedShrine.is_here(lvl), "the shrine stands there")
			check(lvl.stations.any(func(s): return s.kind == "figur"), "Old Sarra is there")
			var prayed := [-1]
			Events.bus().mercy_prayed.connect(func(n: int): prayed[0] = n)
			game.player.hp = 1
			RuinedShrine.pray(game)
			check(game.player.hp == game.player.max_hp, "praying heals fully")
			check(prayed[0] == 0, "the prayer is reported on the bus")
			game.coins = 10
			check(RuinedShrine.restore(game, "head") != "", "a part needs the ones before it")
			check(RuinedShrine.restore(game, "lamp") != "", "too little copper")
			game.coins = 500
			check(RuinedShrine.restore(game, "lamp") == "", "the lamp can be lit")
			check(game.coins == 480, "the lamp costs 20")
			check(RuinedShrine.restore(game, "head") == "" and RuinedShrine.restore(game, "spring") == "", "head and spring follow")
			check(RuinedShrine.restored_count(lvl) == 3 and RuinedShrine.next_step(lvl).is_empty(), "the shrine is whole")
			game.menus.open(RuinedShrine.KIND)
			check(game.menus.current == RuinedShrine.KIND, "the shrine window opens")
			game.menus.close()
			print("PASS" if failures == 0 else "FAILED: %d" % failures)
			game.delete_save(game.save_path())
			quit(1 if failures > 0 else 0)
	return false
