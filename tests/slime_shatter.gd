extends SceneTree
## In winter a slain slime of the open air shatters and leaves slime crystals (see SlimeShatter); out
## of winter it melts as ever. The shattering draws no random numbers, and the crystal teaches a recipe.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_shatter.gd

var game: Node
var frames := 0
var started := false
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _crystals(lvl: Outdoor) -> int:
	var n := 0
	for p in lvl._pickups:
		if p.get("ingredient", "") == SlimeShatter.CRYSTAL:
			n += int(p.count)
	return n


func _run() -> void:
	game.hero_name = "Slime shatter test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var far := lvl.player.global_position + Vector3(0, 0, 60)
	# Out of winter: the usual death, and no crystal.
	game.day = 0
	lvl.day = 0
	var a := lvl.spawn_slime("schleim", far, {"kept_level": 12})
	a.global_position = far
	await _wait(3)
	check(not SlimeShatter.applies(a), "no shattering out of winter")
	a.hp = 0
	a._die()
	await _wait(2)
	check(_crystals(lvl) == 0, "no crystal out of winter")
	# In winter: it bursts into shards without touching the random stream.
	game.day = Weather.YEAR_DAYS - Weather.WINTER_DAYS
	lvl.day = game.day
	check(Weather.is_winter(game.day), "the test day is a winter day")
	var b := lvl.spawn_slime("schleim", far + Vector3(10, 0, 0), {"kept_level": 12})
	b.global_position = far + Vector3(10, 0, 0)
	await _wait(3)
	check(SlimeShatter.applies(b), "a winter slime shatters")
	var kids := lvl.get_child_count()
	seed(11)
	var first := randi()
	seed(11)
	SlimeShatter.shatter(b)
	check(randi() == first, "shattering draws no random numbers")
	check(lvl.get_child_count() > kids, "shards fly")
	await _wait(80)
	check(not is_instance_valid(b), "the slime is gone")
	check(SlimeShatter.crystals(5) == 1 and SlimeShatter.crystals(12) == 2 and SlimeShatter.crystals(25) == 3, "crystals by level")
	# A kill in winter leaves the crystals, and the first one teaches the recipe.
	var c := lvl.spawn_slime("schleim", far + Vector3(0, 0, 10), {"kept_level": 12})
	c.global_position = far + Vector3(0, 0, 10)
	await _wait(3)
	c.hp = 0
	lvl.drop_kill_loot(c)
	check(_crystals(lvl) == 2, "a level 12 slime leaves two crystals (%d)" % _crystals(lvl))
	check(Crafting.INGREDIENTS.has(SlimeShatter.CRYSTAL), "the crystal is a listed ingredient")
	check(Crafting.RECIPES.frosttrank.ingredients.has(SlimeShatter.CRYSTAL), "the frost potion needs it")
	game.crafting.add(SlimeShatter.CRYSTAL, 1)
	game.crafting.learn_from_find(SlimeShatter.CRYSTAL)
	check(game.crafting.knows("frosttrank"), "the first crystal teaches the frost potion")
	if failures == 0:
		print("PASS: slime shatter")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
