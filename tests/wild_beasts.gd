extends SceneTree
## Headless test for the wolf hollow north of the robbers' pass: wolves,
## orcs, spiders and a yeti roam there, every animation they need is in their model,
## they notice the hero and bite, fall, and another takes a fallen one's
## place after a while.
## Run with: godot --headless --fixed-fps 60 -s tests/wild_beasts.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var target: Enemy
var hero_hp := 0
var kills := 0
var struck := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: wild beasts")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			game.hero_name = "Beast test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			game.level.enemy_killed.connect(func(_e: Enemy): kills += 1)
			var lvl: Outdoor = game.level
			var kinds := {}
			for e in lvl.enemies:
				# The monsters of the mountain pass further east are not the
				# hollow's (see tests/mountains.gd).
				if e.is_beast() and not Enemy.KINDS[e.kind].get("mountain", false):
					kinds[e.kind] = kinds.get(e.kind, 0) + 1
			print("beasts in the hollow: ", kinds)
			check(kinds.get("wolf", 0) >= 3, "a pack of wolves roams the hollow")
			check(kinds.has("ork") and kinds.has("yeti") and kinds.has("spinne"), "orcs, spiders and a yeti roam the hollow")
			check(lvl.beasts_alive() == kinds.values().reduce(func(a, b): return a + b, 0), "beasts_alive counts every beast")
			check(lvl.bandits_alive() >= 5, "the bandits are still on the pass")
			var square: Vector3 = lvl.spots.square[0]
			for e in lvl.enemies:
				if e.is_beast():
					check(lvl._flat_distance(e.global_position, square) > Enemy.LEASH_ROAM + Enemy.SIGHT, "%s keeps far enough from the market square" % e.kind)
					# Every animation the class plays is in the model.
					for anim in Enemy.KINDS[e.kind].anims.values():
						check(e._anim.has_animation(anim), "%s has the animation %s" % [e.kind, anim])
					check(e._anim.get_animation(Enemy.KINDS[e.kind].anims["Death_A"]).loop_mode == Animation.LOOP_NONE, "%s dies only once" % e.kind)
			# The hero can walk from the pass up into the hollow.
			var wolf_spot: Dictionary = lvl._wild.filter(func(s): return s.kind == "wolf")[0]
			var way: Array = lvl.astar.get_id_path(Vector2i(80, 34), wolf_spot.cell)
			check(not way.is_empty(), "a way leads from the pass into the hollow")
			stage = 1
		1:
			var lvl: Outdoor = game.level
			var player: Player = game.player
			for e in lvl.enemies:
				if is_instance_valid(e) and e.kind == "wolf" and not e.dead:
					target = e
					break
			check(target != null, "a wolf is there to meet")
			if target == null:
				_finish()
				return true
			player.global_position = target.global_position + target.ahead() * 1.8
			player.velocity = Vector3.ZERO
			player.hp = player.max_hp
			hero_hp = player.hp
			stage_frames = 0
			stage = 2
		2:
			stage_frames += 1
			var lvl: Outdoor = game.level
			var player: Player = game.player
			if player.hp < hero_hp or player.knockdowns > 0 or player.xp.get("blocken", 0.0) > 0.0:
				struck = true
			if player.hp <= 2:
				player.hp = player.max_hp
			if is_instance_valid(target) and not target.dead:
				if stage_frames > 30 and struck:
					if player.global_position.distance_to(target.global_position) < Player.MELEE_RANGE + target.girth():
						player.melee()
					else:
						player.walk_to(target.global_position)
				if stage_frames == 90:
					check(target.is_hunting(), "the wolf notices the hero standing next to it")
				if stage_frames > 1800:
					check(false, "the wolf did not fall within 30 seconds")
					_finish()
					return true
				return false
			check(kills >= 1, "the fallen wolf counts as a kill")
			check(struck, "the wolf bit")
			check(target.fall_text() == Lang.t("Der Wolf bleibt liegen."), "the message says the wolf fell")
			var empty: Array = lvl._wild.filter(func(s): return s.enemy == null)
			check(empty.any(func(s): return s.kind == "wolf") and empty.all(func(s): return s.timer > 0.0), "the fallen wolf's spot waits for the next one")
			for s in empty:
				s.timer = 0.1
			player.global_position = lvl.cell_to_world(lvl.start_cell)
			stage_frames = 0
			stage = 3
		3:
			stage_frames += 1
			var lvl: Outdoor = game.level
			if stage_frames == 30:
				var spots: Array = lvl._wild.filter(func(s): return s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead)
				check(spots.size() == lvl._wild.size(), "a new wolf took the fallen one's place")
				_finish()
				return true
	return false
