extends SceneTree
## A slime down in the sewers lies under the village's cells but is not in the village: the villagers
## above must not rally against it, fight it through the floor or be bitten by it (it cannot be seen).
## Run with: godot --headless --fixed-fps 60 -s tests/slime_underground.gd

var game: Node
var frames := 0
var started := false
var failures := 0


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
	game.hero_name = "Underground test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for i in 3:
		await physics_frame
	var lvl: Outdoor = game.level
	var cell: Vector2i = Sewers.cells().keys()[0]
	var below := Sewers.floor_at(cell)
	check(Sewers.holds(below), "the sewer floor lies in the sewers (%s)" % below)
	var above := Vector3(below.x, 0.0, below.z)
	check(SlimeGrowth.same_world(above, above + Vector3(2, 0, 0)), "two points in the open air are one world")
	check(not SlimeGrowth.same_world(below, above), "the sewers and the street above are two worlds")
	var slime := Enemy.new()
	slime.kind = "schleim"
	slime.level = lvl
	slime.custom = {}
	lvl.add_child(slime)
	slime.global_position = below
	lvl.enemies.append(slime)
	check(not VillageAlarm.intruders(lvl).has(slime), "a slime in the sewers is no intruder of the village")
	var v: Villager = lvl.villagers[0]
	v.global_position = above
	v.at_home = false
	v.brave = true
	v.alarm(slime)
	check(v.threat == null, "a villager above takes up no arms against a slime below")
	v.threat = slime
	v._task = "fight"
	v._fight(0.1)
	check(v.threat == null, "a fight through the floor is dropped")
	# Nothing else up here reacts to it either: the wall, the gate bell, the hunting mages and the hero's blows.
	check(not SlimeGrowth.above(below) and SlimeGrowth.above(above), "the sewers are not up in the open air")
	check(not lvl.village_wall.slime_at_the_wall(lvl), "a slime below is no slime at the wall")
	check(VillageWall.nearest_slime(lvl, below, 60.0) == null, "the wall's nearest slime ignores the sewers")
	check(not VillageWall.slime_near(lvl, below, 60.0), "no slime is near a gate when it is below")
	check(lvl.village_wall.threatened_brick(lvl) == null, "no brick is threatened by a slime below")
	var hero: Player = game.player
	hero.global_position = above
	check(not hero.enemies_in_reach().has(slime), "the hero's blows do not reach through the floor")
	check(hero._nearest_enemy(50.0, false) != slime, "the hero does not pick a target in the sewers")
	var peer := Enemy.new()
	peer.kind = "schleim"
	peer.level = lvl
	peer.custom = {}
	lvl.add_child(peer)
	peer.global_position = above
	lvl.enemies.append(peer)
	check(not SlimeGrowth._mergeable(slime, peer), "a slime below does not merge with one above")
	print("PASS: slime_underground" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
