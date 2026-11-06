extends SceneTree
## Headless test for growing slimes (see SlimeGrowth): plain slimes come in
## many colours and sizes; a slime hunts what it can swallow, swallows what
## it fells (no corpse, and the prey's loot stays in its belly until the
## slime falls), grows a level or more per meal up to level 25 and is a
## sparkling, harder-hitting Blob from level 15 on; and it smells corpses
## and eats them, growing from them too and slurping up the loot by them;
## two slimes that notice each other come together and merge; and the
## slimes stay in the world while the hero is away and in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_growth.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var slime: Enemy
var bandit: Enemy
var wolf: Enemy
var corpse: Corpse
var coins_before := 0
var level_before := 0
var spot := Vector3.INF
var kept := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: slime growth")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _spawn(kind: String, at: Vector3, custom := {}) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	e.custom = custom
	lvl.add_child(e)
	e.global_position = at
	# As the level wires its own (see Level._spawn_enemy): the kill and the
	# loot (which a slime keeps in its belly).
	e.died.connect(func():
		lvl.enemy_killed.emit(e)
		var purse: Array = e.custom.get("purse", Enemy.KINDS[e.kind].get("purse", [0, 0]))
		lvl.drop_kill_loot(e, randi_range(purse[0], purse[1])))
	lvl.enemies.append(e)
	return e


## The slime noted in `kept` is back on the open-air map: same spot, level,
## colour, and the sword in its belly.
func _kept_slime_back(when: String) -> bool:
	var lvl: Level = game.level
	check(lvl.slimes_about() >= int(kept.count), "every slime is back %s (%d of %d)" % [when, lvl.slimes_about(), kept.count])
	for e in lvl.enemies:
		if not is_instance_valid(e) or e.dead or not SlimeGrowth.grows(e.kind):
			continue
		if e.global_position.distance_to(kept.at) > 0.5:
			continue
		check(e.rated_level == int(kept.level), "it keeps its level %s (%d, was %d)" % [when, e.rated_level, kept.level])
		var tint: Color = e._stats.get("tint", Color.BLACK)
		check(tint.is_equal_approx(kept.tint) or tint.to_html() == (kept.tint as Color).to_html(), "it keeps its colour %s" % when)
		var things := []
		for meal in e.belly:
			things.append_array(meal.loot)
		check(things.any(func(t): return t[0] == "item" and t[1] == "schwert"), "the sword is still in its belly %s" % when)
		check(things.any(func(t): return t[0] == "find" and int(t[3]) == 2), "the jelly is still in its belly %s" % when)
		return true
	return false


## The copper coins (the money) lying on the floor.
func _money_on_floor() -> int:
	var sum := 0
	for p in game.level._pickups:
		if p.get("kind", "") == "coin" and p.get("metal", "") == CoinPile.MONEY:
			sum += CoinPile.count_of(p.floor)
	return sum


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


func _check_looks() -> void:
	var tints := {}
	var sizes := {}
	var slimes: Array[Enemy] = []
	for i in 40:
		var e := _spawn("schleim", spot + Vector3(0, -50, 0))
		slimes.append(e)
		tints[str(e._stats.get("tint", "plain"))] = true
		sizes[snappedf(float(e._stats.size), 0.01)] = true
		check(e.rated_level <= SlimeGrowth.MAX_LEVEL, "a slime is born at level 25 at most")
	check(tints.size() >= 5, "plain slimes come in many colours (%d seen)" % tints.size())
	check(sizes.size() >= 8, "plain slimes come in many sizes (%d seen)" % sizes.size())
	check(SlimeGrowth.size_for(1.0, 25) > SlimeGrowth.size_for(1.0, 15) and SlimeGrowth.size_for(1.0, 15) > SlimeGrowth.size_for(1.0, 1),
		"a slime is bigger the higher its level")
	for e in slimes:
		game.level.enemies.erase(e)
		e.queue_free()


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			game.hero_name = "Slime test"
			game.escaped = true
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			spot = _open_row(60.0)
			check(spot != Vector3.INF, "there is open ground for the test")
			if spot == Vector3.INF:
				_finish()
				return true
			_check_looks()
			# A slime of level 14 and a bandit with a fat purse next to it.
			slime = _spawn("schleim", spot)
			bandit = _spawn("halsabschneider", spot + Vector3(Level.TILE * 2.0, 0, 0), {"purse": [40, 40]})
			stage = 1
		1:
			stage_frames += 1
			if stage_frames < 3:
				return false
			slime.rated_level = 14
			bandit.rated_level = 6
			check(SlimeGrowth.can_eat(slime, bandit), "a slime of level 14 would eat a bandit of level 6")
			check(slime.wanders, "in the open air a slime wanders the whole map")
			check(not SlimeGrowth.can_eat(bandit, slime), "a bandit does not eat slimes")
			var other := _spawn("schleim", spot + Vector3(0, -50, 0), {"tint": Color(0.1, 0.2, 0.9)})
			other.rated_level = 13
			other.rated_level = 5
			check(not SlimeGrowth.can_eat(slime, other), "a slime does not hunt its own kind: they merge instead")
			game.level.enemies.erase(other)
			other.queue_free()
			stage_frames = 0
			stage = 2
		2:
			stage_frames += 1
			if stage_frames == 90:
				check(slime.foe == bandit or bandit.foe == slime, "the slime goes for the bandit")
				coins_before = _money_on_floor()
				level_before = slime.rated_level
				slime.rated_level = 14
				bandit.hit_by_rival(999, slime)
				check(bandit.dead, "the bandit falls")
				check(bandit.swallowed_by == slime, "the slime swallows the bandit")
				check(slime.belly.size() == 1, "the bandit is in the slime's belly")
				check(not game.level.corpses.any(func(c): return is_instance_valid(c) and c.enemy == bandit), "a swallowed one leaves no corpse")
				check(_money_on_floor() == coins_before, "the bandit's coins stay inside the slime")
				check(int(slime._model.get_meta("shown", 0)) > 0, "the bandit's coins show inside the slime")
				check(slime.rated_level >= SlimeGrowth.BLOB_LEVEL, "the meal lifts the slime to level 15 (now %d)" % slime.rated_level)
				check(slime.blob and slime._sparkles != null, "at level 15 the slime is a sparkling Blob")
				check(slime.fall_text() == Lang.t("Der Blob zerplatzt."), "a Blob bursts when it falls")
				check(slime.hp == slime.max_hp() or slime.hp > 0, "the slime is alive and fed")
				stage_frames = 0
				stage = 3
		3:
			stage_frames += 1
			if stage_frames < 60:
				return false
			check(not bandit.visible, "the swallowed bandit is out of sight")
			check(is_instance_valid(bandit), "the bandit's body waits in the belly")
			check(float(slime._model.scale.x) > 1.0, "the slime has swollen")
			slime.hp = 1
			slime.take_hit(5, game.player.global_position, "hit", false)
			check(slime.dead, "the Blob falls")
			check(_money_on_floor() >= coins_before + 40, "the Blob gives back the bandit's 40 coins")
			check(bandit.is_queued_for_deletion(), "the bandit's body goes once spilt")
			# The cap: a slime of level 25 eats and stays at 25.
			var big := _spawn("schleim", spot + Vector3(0, -50, 0))
			big.rated_level = 25
			var snack := _spawn("fledermaus", spot + Vector3(0, -50, 3))
			snack.hit_by_rival(999, big)
			check(big.rated_level == SlimeGrowth.MAX_LEVEL, "a slime grows no higher than level 25")
			game.level.enemies.erase(big)
			big.queue_free()
			# Corpses: a wolf falls to the hero; a new slime goes for it.
			wolf = _spawn("wolf", spot + Vector3(Level.TILE * 3.0, 0, Level.TILE))
			wolf.take_hit(999, game.player.global_position, "hit", false)
			corpse = null
			for c in game.level.corpses:
				if is_instance_valid(c) and c.enemy == wolf:
					corpse = c
			check(corpse != null, "the wolf lies as a corpse")
			# Loot lying by the body: a pile of 7 coins and a sword.
			game.level.lay_coins(wolf.global_position + Vector3(0.5, 0, 0), 7)
			game.level._drop_item("schwert", wolf.global_position + Vector3(-0.6, 0, 0.3))
			coins_before = _money_on_floor()
			slime = _spawn("schleim", spot)
			stage_frames = 0
			stage = 4
		4:
			stage_frames += 1
			if stage_frames == 3:
				level_before = slime.rated_level
			if stage_frames == 40:
				check(slime.meal != null, "the slime smells a corpse (the Blob's puddle or the wolf) and goes for it")
			if is_instance_valid(wolf) and wolf.swallowed_by == null:
				if stage_frames > 900:
					check(false, "the slime did not eat the corpse within 15 seconds")
					_finish()
					return true
				return false
			check(wolf.swallowed_by == slime, "the slime eats the corpse")
			check(slime.rated_level > level_before, "the corpse makes the slime grow")
			check(not game.level.corpses.has(corpse), "the eaten corpse is gone")
			# (It may have eaten the Blob's puddle first, with the Blob's coins.)
			check(_money_on_floor() <= coins_before - 7, "the slime slurps up the coins by the corpse")
			check(not game.level.lies_on_floor("schwert"), "the slime slurps up the sword by the corpse")
			var slurped: Array = slime.belly.back().loot if not slime.belly.is_empty() else []
			check(slurped.any(func(t): return t[0] == "item" and t[1] == "schwert"), "the sword is in the slime's belly")
			check(slurped.any(func(t): return t[0] == "coins" and int(t[2]) == 7), "the 7 coins are in the slime's belly")
			# Merging: a red slime and a blue one a few tiles apart.
			game.level.enemies.erase(slime)
			slime.queue_free()
			wolf = _spawn("schleim", spot + Vector3(0, 0, Level.TILE), {"tint": Color(1, 0, 0)})
			slime = _spawn("schleim", spot + Vector3(Level.TILE * 3.0, 0, Level.TILE), {"tint": Color(0, 0, 1)})
			stage_frames = 0
			stage = 5
		5:
			stage_frames += 1
			if stage_frames == 3:
				wolf.rated_level = 4
				slime.rated_level = 8
				level_before = slime.rated_level
			if stage_frames == 40:
				check(slime.drawn_to == wolf or wolf.drawn_to == slime or wolf.dead, "the slimes notice each other and come together")
			if not wolf.dead:
				if stage_frames > 900:
					check(false, "the two slimes did not merge within 15 seconds")
					_finish()
					return true
				return false
			check(wolf.merged and wolf.swallowed_by == slime, "the smaller slime flows into the bigger one")
			check(slime.rated_level > level_before, "the merged slime is bigger")
			var tint: Color = slime._stats.tint
			check(tint.r > 0.1 and tint.b > 0.1, "their colours mix (%s)" % tint)
			check(tint.b > tint.r, "the bigger one's colour wins out")
			check(wolf.fall_text() == Lang.t("Zwei Schleime fließen zusammen."), "the message says they flowed together")
			# Lasting: the merged slime, with a sword in its belly, waits while
			# the hero is in a dungeon, and in the saved game.
			slime.belly.append({"victim": null, "loot": [["item", "schwert"], ["find", "schleimgelee", Color(0.5, 0.9, 0.4), 2]]})
			kept = {"level": slime.rated_level, "tint": slime._stats.tint, "at": slime.global_position, "count": game.level.slimes_about()}
			game.load_level(0, false)
			game.load_level(game._outdoor_index(), false)
			check(_kept_slime_back("after a dungeon"), "the slime is still there after the hero was in a dungeon")
			check(game.save_game(), "the game saves")
			game._apply_save(game._read_save(game.save_path()))
			game.load_level(game._outdoor_index(), false)
			check(_kept_slime_back("after loading"), "the slime is still there after saving and loading")
			_finish()
			return true
	return false
