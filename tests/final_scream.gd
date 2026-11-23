extends SceneTree
## Headless test: someone who goes down in a fight lets out a final scream.
## - A monster that falls cries out in a speech bubble over itself (named
##   after it), and the hero does the same when felled.
## - The moment it shows, every other speech bubble and comic word is gone,
##   and no new one appears while it lasts.
## - It lasts one and a half times as long as a normal line; once it is over,
##   people can talk again.
## Run with: godot --headless --fixed-fps 60 -s tests/final_scream.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		if game.state == game.State.TITLE:
			game._start_playing()
		game.load_level(game._outdoor_index(), false)
	if frames == 10:
		_test()
		print("PASS: final scream" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
		return true
	return false


func _test() -> void:
	check(FinalScream.SECONDS == Villager.SAY_TIME * 1.5, "the scream lasts one and a half normal lines")
	var lvl: Level = game.level
	var v: Villager = lvl.villagers[0]
	v.hush()
	v.say("Schönes Wetter heute.")
	check(v._bubble.is_shown(), "a villager's line shows before the fall")
	Comic.pop(game.player.global_position, "hit")
	check(not Comic.current._pops.is_empty(), "a comic word pops before the fall")

	var foe := Enemy.new()
	foe.kind = "krieger"
	foe.level = lvl
	lvl.add_child(foe)
	lvl.enemies.append(foe)
	foe.global_position = game.player.global_position + Vector3(2.0, 0, 0)
	foe.set_physics_process(false)
	foe._die()
	var scream: FinalScream = FinalScream.current
	check(scream != null and scream.is_shown(), "the falling monster screams")
	if scream == null:
		return
	check(scream.text != "", "the scream carries a cry (%s)" % scream.text)
	check(scream._bubble is Control and scream._bubble.get_parent() == Comic.current, "the scream is a comic action bubble")
	check(FinalScream.showing(), "the scream holds the stage")
	check(not v._bubble.is_shown(), "the villager's bubble vanished at the scream")
	check(Comic.current._pops.size() == 1, "the comic words vanished at the scream, only the scream is left")

	v.hush()
	v.say("Was war das?")
	check(not v._bubble.is_shown(), "no new bubble while the scream shows")
	Comic.pop(game.player.global_position, "hit")
	check(Comic.current._pops.size() == 1, "no new comic word while the scream shows")

	# Most of its time later it is still there.
	scream._process(FinalScream.SECONDS - 1.0)
	check(scream.is_shown() and FinalScream.showing(), "the scream is still there after %.0f s" % (FinalScream.SECONDS - 1.0))
	# Over: it lets go of the stage, then people talk again.
	for i in 12:
		scream._process(0.1)
	check(not FinalScream.showing(), "the scream lets go of the stage when its time is up")
	v.hush()
	v.say("Na endlich Ruhe.")
	check(v._bubble.is_shown(), "people talk again once the scream is over")

	# The hero cries out too when felled.
	game.player.godmode = false
	game.player.hp = 1
	game.player._invulnerable = 0.0
	game.player.take_damage(99, game.player.global_position + Vector3(1, 0, 0), null, false)
	var hero_scream: FinalScream = FinalScream.current
	check(hero_scream != null and is_instance_valid(hero_scream) and hero_scream != scream and hero_scream.is_shown(), "the felled hero screams")
