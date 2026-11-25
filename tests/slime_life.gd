extends SceneTree
## Slimes dry out and go back to the pond (see SlimeLife): in dry weather a slime loses a level a
## minute, in rain or fog it keeps its level; one with no level left melts away and leaves its loot;
## after an hour it walks to the pond and sinks in with its loot, and the townsfolk come out.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_life.gd

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


func _slime(lvl: Outdoor, at: Vector3, level: int) -> Enemy:
	var e := lvl.spawn_slime("schleim", at, {"kept_level": level})
	e.global_position = at
	return e


func _run() -> void:
	game.hero_name = "Slime life test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false
	check(not lvl._pond_waters.is_empty(), "the map has a pond")
	var far := lvl.player.global_position + Vector3(0, 0, 60)
	var s := _slime(lvl, far, 10)
	await _wait(3)
	var size_before: float = s._stats.size
	var level_before := s.rated_level
	# Wet weather: no drying.
	s.dry_time = 0.0
	for kind in [Weather.RAIN, Weather.FOG, Weather.STORM]:
		lvl.weather = kind
		SlimeLife.tick(s, 130.0)
		check(s.rated_level == level_before, "a slime keeps its level in %s" % kind)
	check(s.dry_time == 0.0, "wet weather does not count as drying")
	# Dry weather: one level a minute, and it shrinks and goes dull.
	lvl.weather = Weather.CLEAR
	s.dry_time = SlimeLife.FADE_SECONDS
	SlimeLife.fade_a_level(s)
	check(s.rated_level == level_before - 1, "a dry minute costs one level (%d, was %d)" % [s.rated_level, level_before])
	check(float(s._stats.size) < size_before, "the slime is smaller")
	check(s.dryness > 0.0, "the slime looks duller")
	lvl.weather = Weather.RAIN
	SlimeLife.tick(s, 30.0)
	check(s.dryness == 0.0, "the colour comes back in the rain")
	lvl.weather = Weather.CLEAR
	# A slime with no level left melts away and leaves its loot.
	var coins_before := lvl._pickups.size()
	var villager: Villager = lvl.villagers[0]
	villager.eaten = true
	s.folk.append(villager)
	s.belly.append({"victim": null, "loot": [["coins", CoinPile.MONEY, 5]]})
	s.rated_level = 1
	SlimeLife.fade_a_level(s)
	check(s.dead and s.vanishing, "a slime at level 1 dries up")
	check(s.belly.is_empty(), "its belly is spilled")
	check(lvl._pickups.size() > coins_before, "the loot lies on the ground")
	check(not villager.eaten and s.folk.is_empty(), "the townsfolk are free")
	# After an hour it retreats to the pond and sinks in with its loot.
	var t := _slime(lvl, far, 6)
	await _wait(3)
	villager.eaten = true
	t.folk.append(villager)
	t.belly.append({"victim": null, "loot": [["coins", CoinPile.MONEY, 5]]})
	lvl.weather = Weather.RAIN
	t.slime_age = SlimeLife.LIFESPAN - 1.0
	SlimeLife.tick(t, 2.0)
	check(t.retreating, "after an hour the slime retreats")
	check(t.shore != Vector3.INF, "it knows its bank")
	check(t.rated_level == 6, "retreating in the rain, it keeps its level")
	var pickups := lvl._pickups.size()
	t.global_position = t.shore + Vector3(0.3, 0, 0)
	await _wait(4)
	check(t.dead and t.vanishing, "at the bank it sinks")
	check(t.belly.is_empty(), "its loot goes with it")
	check(lvl._pickups.size() == pickups, "no loot is left behind")
	check(not villager.eaten, "the townsfolk are let out")
	await _wait(150)
	check(not is_instance_valid(t), "the slime is gone from the world")
	if failures == 0:
		print("PASS: slime life")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
