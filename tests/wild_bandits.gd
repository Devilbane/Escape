extends SceneTree
## Headless test for the robbers' pass east of the village: bandits roam
## there, far from the village, notice the hero, fight back, drop gold or
## gear when they fall, and another takes a fallen one's place after a
## while. Run with: godot --headless --fixed-fps 60 -s tests/wild_bandits.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var target: Enemy
var hero_hp := 0
var pickups_before := 0
var kills := 0
var killed_kind := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: wild bandits")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _nearest_bandit(from: Vector3) -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in game.level.enemies:
		if is_instance_valid(e) and not e.dead and e.is_human():
			var d: float = from.distance_to(e.global_position)
			if d < best_d:
				best = e
				best_d = d
	return best


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			game.hero_name = "Bandit test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			game.level.enemy_killed.connect(func(e: Enemy):
				kills += 1
				killed_kind = e.kind)
			var lvl: Outdoor = game.level
			var kinds := {}
			for e in lvl.enemies:
				kinds[e.kind] = kinds.get(e.kind, 0) + 1
			print("bandits on the pass: ", kinds)
			check(lvl.bandits_alive() >= 5, "at least five bandits roam the pass")
			check(kinds.has("hauptmann") and kinds.has("halsabschneider") and kinds.has("wilderer") and kinds.has("schlaeger"), "every kind of bandit is there")
			check(lvl.enemies.all(func(e): return e.is_human()), "no skeletons in the open")
			# The village stays safe: the market square is far out of reach.
			var square: Vector3 = lvl.spots.square[0]
			for e in lvl.enemies:
				check(lvl._flat_distance(e.global_position, square) > Enemy.LEASH_ROAM + Enemy.SIGHT, "%s keeps far enough from the market square" % e.kind)
			# The hoard is in the camp, and the chest can be searched.
			var chests: Array = lvl.interactables.filter(func(o): return o.label == "Schatztruhe")
			check(chests.size() == 1 and chests[0].loot.get("gold", 0) >= 20, "the camp has a chest with the robbers' hoard")
			stage = 1
		1:
			# Walk the hero up to the nearest bandit, far from the camp: it
			# must notice the hero and strike. The hero fights back.
			var lvl: Outdoor = game.level
			var player: Player = game.player
			target = _nearest_bandit(lvl.cell_to_world(Vector2i(70, 34)))
			check(target != null, "a bandit roams near the entrance of the pass")
			if target == null:
				_finish()
				return true
			player.global_position = target.global_position + Vector3(2.5, 0, 0.5)
			player.velocity = Vector3.ZERO
			player.hp = player.max_hp
			hero_hp = player.hp
			pickups_before = lvl._pickups.size()
			stage_frames = 0
			stage = 2
		2:
			stage_frames += 1
			var lvl: Outdoor = game.level
			var player: Player = game.player
			if player.hp <= 2:
				player.hp = player.max_hp
			if is_instance_valid(target) and not target.dead:
				if stage_frames > 30:
					# Keep the fight going, blade first, knives from afar.
					if player.global_position.distance_to(target.global_position) < Player.MELEE_RANGE + target.girth():
						player.melee()
					else:
						player.walk_to(target.global_position)
				if stage_frames == 90:
					check(target.is_hunting(), "the bandit notices the hero standing next to it")
				if stage_frames > 1800:
					check(false, "the bandit did not fall within 30 seconds")
					_finish()
					return true
				return false
			check(kills >= 1 and killed_kind == target.kind, "the fallen bandit counts as a kill")
			check(player.hp < hero_hp or player.knockdowns > 0 or player.xp.get("blocken", 0.0) > 0.0, "the bandit struck back")
			# Loot: coins or gear lie where it fell.
			var dropped: int = lvl._pickups.size() - pickups_before
			print("the %s fell after %d frames and dropped %d things" % [target.kind, stage_frames, dropped])
			check(dropped >= 1, "a fallen bandit drops gold or gear")
			var spot: Dictionary = lvl._wild.filter(func(s): return s.kind == target.kind and s.enemy == null)[0]
			check(spot.timer > 0.0, "the fallen bandit's spot waits for the next one")
			# Picked up: the gold counts.
			var gold_before: int = game.coins
			var coins_dropped: int = lvl._pickups.slice(pickups_before).filter(func(p): return p.kind == "coin").size()
			for p in lvl._pickups.duplicate():
				if p.kind == "coin" and is_instance_valid(p.node):
					player.global_position = p.node.global_position
					lvl._check_pickups()
			check(game.coins == gold_before + coins_dropped, "the dropped gold (%d coins) is picked up" % coins_dropped)
			# Respawn: once the time is up and the hero is away, another comes.
			spot.timer = 0.1
			player.global_position = lvl.cell_to_world(lvl.start_cell)
			stage_frames = 0
			stage = 3
		3:
			stage_frames += 1
			var lvl: Outdoor = game.level
			if stage_frames == 30:
				var spots: Array = lvl._wild.filter(func(s): return s.enemy != null and is_instance_valid(s.enemy) and not s.enemy.dead)
				check(spots.size() == lvl._wild.size(), "a new bandit took the fallen one's place")
				check(lvl.enemies.filter(func(e): return is_instance_valid(e) and not e.dead).size() == lvl._wild.size(), "the level lists every living bandit")
				_finish()
				return true
	return false
