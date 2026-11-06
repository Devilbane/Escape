extends SceneTree
## Headless test for monster factions (see Factions): rivals such as a wolf
## and a bandit fight each other when they meet, and such a kill counts for
## no task; gifts win the wolves over, after which they leave the hero alone,
## the hero's blade passes them by, and they fall upon a monster that hunts
## the hero. The favour survives the saved game, and slaying rivals alone
## never quite makes a faction a friend.
## Run with: godot --headless --fixed-fps 60 -s tests/factions.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var wolf: Enemy
var bandit: Enemy
var orc: Enemy
## Open ground far from the hero and the monsters of the wild.
var spot := Vector3.INF


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	Factions.clear()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: factions")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _spawn(kind: String, at: Vector3) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	lvl.add_child(e)
	e.global_position = at
	e.died.connect(func(): lvl.enemy_killed.emit(e))
	lvl.enemies.append(e)
	return e


## A row of four free tiles at least `far` metres from the hero and from
## every monster, or INF.
func _open_row(far: float) -> Vector3:
	var lvl: Level = game.level
	for y in range(2, lvl.height - 2):
		for x in range(2, lvl.width - 6):
			var free := true
			for i in 4:
				var c := Vector2i(x + i, y)
				if not lvl.astar.is_in_boundsv(c) or lvl.astar.is_point_solid(c):
					free = false
					break
			if not free:
				continue
			var at := lvl.cell_to_world(Vector2i(x, y))
			if at.distance_to(game.player.global_position) < far:
				continue
			if lvl.enemies.any(func(e): return is_instance_valid(e) and not e.dead and e.global_position.distance_to(at) < far):
				continue
			return at
	return Vector3.INF


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			game.hero_name = "Faction test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			Factions.clear()
			check(Factions.kinds_are_rivals("wolf", "halsabschneider"), "wolves and bandits are rivals")
			check(Factions.kinds_are_rivals("krieger", "fledermaus"), "skeletons and the dragon's brood are rivals")
			check(Factions.kinds_are_rivals("fog_wraith", "ork"), "the dead hate the orcs")
			check(not Factions.kinds_are_rivals("wolf", "ork"), "the beasts share their hollow in peace")
			check(not Factions.kinds_are_rivals("wolf", "wolf"), "a wolf does not fight a wolf")
			check(Factions.can_befriend("wolves") and not Factions.can_befriend("bandits"), "wolves can be won over, bandits cannot")
			for kind in Enemy.KINDS:
				check(Factions.of(kind) != "", "%s belongs to a faction" % kind)
			spot = _open_row(60.0)
			check(spot != Vector3.INF, "there is open ground for the test")
			if spot == Vector3.INF:
				_finish()
				return true
			wolf = _spawn("wolf", spot)
			bandit = _spawn("halsabschneider", spot + Vector3(Level.TILE * 3.0, 0, 0))
			stage_frames = 0
			stage = 1
		1:
			stage_frames += 1
			var someone_fell: bool = wolf.dead or bandit.dead
			if stage_frames == 120:
				check(wolf.foe == bandit or bandit.foe == wolf or someone_fell, "the wolf and the bandit go for each other")
			if not someone_fell:
				if stage_frames > 1800:
					check(false, "neither the wolf nor the bandit fell within 30 seconds")
					_finish()
					return true
				return false
			var fallen: Enemy = wolf if wolf.dead else bandit
			check(fallen.slain_by_rival, "the fallen one was slain by its rival")
			check(Factions.favour_of("wolves") == 0.0 and Factions.favour_of("orcs") == 0.0, "a rival's kill earns the hero no favour")
			# The winner of the fight would only get in the way of what comes
			# next (a bandit left standing hunts the hero): off it goes.
			var winner: Enemy = bandit if fallen == wolf else wolf
			if is_instance_valid(winner) and not winner.dead:
				game.level.enemies.erase(winner)
				winner.queue_free()
			# Next: win the wolves over. The hero stands right by a new wolf.
			wolf = _spawn("wolf", spot + Vector3(0, 0, Level.TILE))
			game.player.global_position = wolf.global_position + Vector3(2.0, 0, 0)
			game.player.velocity = Vector3.ZERO
			game.player.hp = game.player.max_hp
			game.crafting.add("barsch", 3)
			stage_frames = 0
			stage = 2
		2:
			stage_frames += 1
			if stage_frames < 3:
				return false
			check(game.gift_target() == wolf, "the wolf is close enough for a gift")
			for i in 3:
				game.gift_action()
			check(game.crafting.have("barsch") == 0, "three perch went to the wolves")
			check(Factions.is_friendly("wolves"), "three gifts make the wolves friends")
			check(wolf.is_friend(), "the wolf knows it")
			check(Factions.HOW_TO in game.lore, "the compendium explains rivals and friends")
			stage_frames = 0
			stage = 3
		3:
			stage_frames += 1
			game.player.hp = game.player.max_hp
			game.player.global_position = wolf.global_position + Vector3(1.6, 0, 0)
			if stage_frames == 120:
				check(not wolf.is_hunting(), "a friendly wolf does not hunt the hero")
				check(not game.player.enemies_in_reach().has(wolf), "the hero's blade passes a friend by")
				# An orc (no rival of the wolves) comes for the hero.
				orc = _spawn("ork", wolf.global_position + Vector3(-Level.TILE * 2.0, 0, 0))
				orc.alert(game.player.global_position)
				stage_frames = 0
				stage = 4
		4:
			stage_frames += 1
			game.player.hp = game.player.max_hp
			if wolf.foe == orc or orc.dead:
				check(true, "the friendly wolf falls upon the orc")
			elif stage_frames < 180:
				return false
			else:
				check(false, "the friendly wolf falls upon the orc that hunts the hero")
			# The favour is kept in the saved game.
			var saved := Factions.for_save()
			Factions.clear()
			check(not Factions.is_friendly("wolves"), "a new game starts with no friends")
			Factions.load_from(JSON.parse_string(JSON.stringify(saved)))
			check(Factions.is_friendly("wolves"), "the wolves are still friends after loading")
			Factions.load_from({"wolves": "lots", "dragons": 9})
			check(Factions.favour.is_empty(), "nonsense in the saved game is left out")
			# Slaying rivals alone never quite makes friends.
			for i in 20:
				Factions.on_hero_kill("halsabschneider")
			check(not Factions.is_friendly("orcs") and Factions.favour_of("orcs") == Factions.FRIENDLY - Factions.GIFT_FAVOUR, "slaying bandits earns the orcs' favour, but the last step takes a gift")
			Factions.on_hero_kill("ork")
			check(Factions.favour_of("orcs") < Factions.FRIENDLY - Factions.GIFT_FAVOUR, "slaying an orc costs their favour")
			_finish()
			return true
	return false
