extends SceneTree
## Headless test for lightning hitting creatures (see LightningStrike): a bolt
## glows, scares and hurts whoever stands under it, spares the far ones, never
## fells the hero, and a thunderstorm's strokes sometimes seek a creature out.
## Run with: godot --headless --fixed-fps 60 -s tests/lightning_strike.gd

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
	if frames < 5:
		return false
	game.hero_name = "Lightning test"
	game.day_hour = 12.0
	game.set_weather(Weather.STORM, 4.0)
	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	var spot := hero.global_position + Vector3(60, 0, 0)

	var foe := Enemy.new()
	foe.kind = "krieger"
	foe.level = lvl
	lvl.add_child(foe)
	foe.global_position = spot
	lvl.enemies.append(foe)
	var far := Enemy.new()
	far.kind = "krieger"
	far.level = lvl
	lvl.add_child(far)
	far.global_position = spot + Vector3(10, 0, 0)
	lvl.enemies.append(far)
	var hp := foe.hp
	var struck := LightningStrike.hit(lvl, spot, hero)
	check(struck == 1, "only the creature under the bolt is struck (%d)" % struck)
	check(foe.dead or foe.hp == hp - LightningStrike.MONSTER_DAMAGE, "a monster loses some life")
	check(far.hp == hp, "the far one is spared")
	if not foe.dead:
		check(foe.find_children("*", "OmniLight3D", true, false).size() > 0, "the struck monster lights up")

	if not lvl.animals.is_empty():
		var deer: Animal = lvl.animals[0]
		LightningStrike.hit(lvl, deer.global_position, hero)
		check(deer.state == "flee", "a struck animal bolts")
		check(deer.is_inside_tree(), "an animal is not killed by it")

	hero.global_position = spot + Vector3(0, 0, 100)
	hero.hp = hero.max_hp
	hero._invulnerable = 0.0
	LightningStrike.hit(lvl, hero.global_position, hero)
	check(hero.hp < hero.max_hp or hero.armour_value > 0, "the hero under the bolt is hurt")
	hero.hp = 1
	hero._invulnerable = 0.0
	LightningStrike.hit(lvl, hero.global_position, hero)
	check(hero.hp == 1 and not hero.dead, "lightning never fells the hero")

	hero.global_position += Vector3(0, 0, 100)
	hero.hp = hero.max_hp
	for i in 60:
		lvl.strike()
	check(hero.hp >= hero.max_hp - 2 and not hero.dead, "a stormy hour costs the hero at most a scratch or two")

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: lightning_strike")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true
