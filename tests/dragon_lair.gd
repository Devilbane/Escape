extends SceneTree
## Headless test for the dragon's lair: a stone arch in the woods between the
## graveyard and the village leads down into a dungeon of its own, built from
## the dungeon kits, where bats, slimes, skeletons and a fire-spitting dragon
## live. The monsters have every animation they need, a bat notices the hero
## and bites, a fallen monster leaves gold, the dragon spits fire, the stairs
## lead back out of the arch, and the monsters stand ready again next time.
## The fallen dragon wins the lair: a window says so and offers the way out,
## and a golden way out shines up where it fell.
## Run with: godot --headless --fixed-fps 60 -s tests/dragon_lair.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var target: Enemy
var hero_hp := 0
var kills := 0
var struck := false
var first_count := 0
var coins_before := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(13)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: dragon's lair")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _alive(lvl: Level) -> Array:
	return lvl.enemies.filter(func(e): return is_instance_valid(e) and not e.dead)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			game.hero_name = "Lair test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			var lvl: Outdoor = game.level
			check(game.interiors.has("E"), "the lair is a floor below the arch E")
			check(lvl.doors.has("E"), "the arch stands in the woods")
			var door := lvl.stations.filter(func(s): return s.kind == "eingang" and s.building == "E")
			check(door.size() == 1, "running into the arch leads down")
			# The arch can be reached on foot from the graveyard path.
			var way: Array = lvl.astar.get_id_path(lvl.start_cell, lvl.world_to_cell(lvl.doors.E))
			check(not way.is_empty(), "a way leads from the graveyard to the arch")
			game.player.global_position = lvl.doors.E
			game.go_inside("E")
			stage = 1
		1:
			stage_frames += 1
			if stage_frames < 60:
				return false
			var lvl: Level = game.level
			check(lvl.building == "E" and lvl.lair, "the arch led into the dragon's lair (%s)" % lvl.level_name)
			check(not lvl.safe, "the lair is no safe room")
			var kinds := {}
			for e in _alive(lvl):
				kinds[e.kind] = kinds.get(e.kind, 0) + 1
			print("monsters in the lair: ", kinds)
			check(kinds.get("fledermaus", 0) >= 4, "bats flutter through the lair")
			check(kinds.get("schleim", 0) >= 3, "slimes creep through the lair")
			check(kinds.get("drache", 0) == 1, "one dragon guards the hoard")
			check(kinds.has("krieger") and kinds.has("schuetze"), "skeletons haunt the lair too")
			for e in _alive(lvl):
				if e.is_beast():
					for anim in Enemy.KINDS[e.kind].anims.values():
						check(e._anim.has_animation(anim), "%s has the animation %s" % [e.kind, anim])
					check(e._anim.get_animation(Enemy.KINDS[e.kind].anims["Death_A"]).loop_mode == Animation.LOOP_NONE, "%s dies only once" % e.kind)
			# Dressed with pieces of the dungeon kit.
			var props := {}
			for child in lvl.get_children():
				if child.scene_file_path.begins_with(Level.LAIR_DIR):
					props[child.scene_file_path.get_file().get_basename()] = true
			print("kit pieces: ", props.keys())
			check(props.has("Coin_Pile") and props.has("Skull") and props.has("Statue_Horse"), "the lair is dressed with the kit's coins, skulls and statues")
			check(props.has("Cobweb") or props.has("Cobweb2"), "cobwebs hang in the corners")
			# Every part of the lair can be reached from the stairs.
			var dragon: Enemy = _alive(lvl).filter(func(e): return e.kind == "drache")[0]
			check(not lvl.grid_path(lvl.start_cell, lvl.world_to_cell(dragon.global_position)).is_empty(), "a way leads down to the dragon")
			first_count = _alive(lvl).size()
			lvl.enemy_killed.connect(func(_e: Enemy): kills += 1)
			# The dragon spits fire when it sees the hero from afar.
			var player: Player = game.player
			player.global_position = dragon.global_position + Vector3(-9.0, 0, 0)
			player.hp = player.max_hp
			dragon._wake(player.global_position)
			stage = 2
			stage_frames = 0
		2:
			stage_frames += 1
			var lvl: Level = game.level
			var fire := lvl.get_children().filter(func(c): return c is Projectile and c.fire)
			if not fire.is_empty():
				check(fire[0].magic and not fire[0].from_player, "the dragon's fire flies at the hero")
				stage = 3
				stage_frames = 0
			elif stage_frames > 600:
				check(false, "the dragon spat no fire within 10 seconds")
				stage = 3
				stage_frames = 0
		3:
			# A bat bites the hero standing next to it and falls to the sword.
			var lvl: Level = game.level
			var player: Player = game.player
			if target == null:
				var bats := _alive(lvl).filter(func(e): return e.kind == "fledermaus")
				target = bats[0]
				player.global_position = target.global_position + Vector3(1.8, 0, 0)
				player.velocity = Vector3.ZERO
				player.hp = player.max_hp
				hero_hp = player.hp
				coins_before = lvl._pickups.filter(func(p): return p.kind == "coin").size()
				return false
			stage_frames += 1
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
					check(target.is_hunting(), "the bat notices the hero next to it")
				if stage_frames > 1800:
					check(false, "the bat did not fall within 30 seconds")
					_finish()
					return true
				return false
			check(struck, "the bat bit")
			check(kills >= 1, "the fallen bat counts as a kill")
			check(target.fall_text() == Lang.t("Die Fledermaus fällt zu Boden."), "the message says the bat fell")
			# The dragon falls too and leaves a heap of gold.
			var dragon: Enemy = _alive(lvl).filter(func(e): return e.kind == "drache")[0]
			var before := lvl._pickups.filter(func(p): return p.kind == "coin").size()
			dragon.take_hit(99, player.global_position)
			var after := lvl._pickups.filter(func(p): return p.kind == "coin").size()
			check(after - before >= Enemy.KINDS.drache.purse[0], "the dragon leaves a heap of gold (%d coins)" % (after - before))
			check(dragon.fall_text() == Lang.t("Der Drache stürzt brüllend zu Boden!"), "the message says the dragon fell")
			check(lvl.lair_cleared, "the fallen dragon wins the lair")
			stage = 6
			stage_frames = 0
		6:
			# A window says the lair is won and offers the way out.
			stage_frames += 1
			if game.menus.current != "hoehle":
				if stage_frames > 360:
					check(false, "no lair-complete window within 6 seconds")
					_finish()
					return true
				return false
			var lvl: Level = game.level
			check(is_instance_valid(lvl.lair_exit), "a golden way out shines where the dragon fell")
			if is_instance_valid(lvl.lair_exit):
				var dragon_spot := lvl.world_to_cell(lvl.lair_exit.global_position)
				check(not lvl.astar.is_point_solid(dragon_spot), "the way out stands on free floor")
			# "Leave the lair".
			game.menus.close()
			game.leave_lair()
			stage = 4
			stage_frames = 0
		4:
			stage_frames += 1
			if stage_frames < 90:
				return false
			var lvl: Level = game.level
			check(lvl is Outdoor, "leaving the won lair leads back out into the woods")
			if lvl is Outdoor:
				check(game.player.global_position.distance_to(lvl.doors.E) < 3.0, "the hero comes out in front of the arch")
			game.go_inside("E")
			stage = 5
			stage_frames = 0
		5:
			stage_frames += 1
			if stage_frames < 60:
				return false
			var lvl: Level = game.level
			check(_alive(lvl).size() == first_count, "the monsters stand ready again on the next visit")
			check(not lvl.lair_cleared and lvl.lair_exit == null, "the lair waits to be won again")
			# Win it again, then step into the golden way out.
			var dragon: Enemy = _alive(lvl).filter(func(e): return e.kind == "drache")[0]
			dragon.take_hit(99, game.player.global_position)
			stage = 7
			stage_frames = 0
		7:
			stage_frames += 1
			var lvl: Level = game.level
			if not is_instance_valid(lvl.lair_exit):
				if stage_frames > 150:
					check(false, "the way out did not open")
					_finish()
					return true
				return false
			game.player.global_position = lvl.lair_exit.global_position
			game.player.velocity = Vector3.ZERO
			stage = 8
			stage_frames = 0
		8:
			stage_frames += 1
			var lvl: Level = game.level
			if not lvl is Outdoor:
				if stage_frames > 150:
					check(false, "the golden way out led nowhere")
					_finish()
					return true
				return false
			if stage_frames < 60:
				return false
			check(game.player.global_position.distance_to(lvl.doors.E) < 3.0, "the way out leads to the arch")
			check(game.menus.current != "hoehle", "no lair window left open outside")
			game.go_inside("E")
			stage = 9
			stage_frames = 0
		9:
			stage_frames += 1
			if stage_frames < 60:
				return false
			# The stairs lead out too, won or not.
			game._next_level()
			stage = 10
			stage_frames = 0
		10:
			stage_frames += 1
			if stage_frames < 30:
				return false
			var lvl: Level = game.level
			check(lvl is Outdoor, "the lair's stairs lead back out into the woods")
			_finish()
			return true
	return false
