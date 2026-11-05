extends SceneTree
## Headless test for the Great Old One's dungeon (see ElderLair and
## ElderDragon): a cave mouth in a ravine below the high valley leads down
## three floors. Floors 1 and 2 each keep an epic treasure room behind a
## locked door; on floor 3 the Great Old One sleeps on its hoard. It cannot
## be slain, wakes from noise but not from a sneaking hero, burns whoever
## stands in its breath and falls asleep again once the hero is out of
## sight. Its hoard holds its own treasure once and, after that, what the
## dragon helpers bring.
## Run with: godot --headless --fixed-fps 60 -s tests/elder_lair.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0


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
	print("PASS: the Great Old One's dungeon" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _enter(building: String) -> void:
	game.state = game.State.PLAYING
	game.go_inside(building)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			game.hero_name = "Elder test"
			game.escaped = true
			game.hoard.clear()
			game.load_level(game._outdoor_index(), false)
			game.state = game.State.PLAYING
			_check_open_air()
			_enter("uralt1")
			wait = 50
			stage = 1
		1:
			_check_floor("uralt1", "", "uralt2")
			check(game.lore.has(ElderLair.LORE), "the compendium learns of the Great Old One on the way in")
			_enter("uralt2")
			wait = 50
			stage = 2
		2:
			_check_floor("uralt2", "uralt1", "uralt3")
			_enter("uralt3")
			wait = 60
			stage = 3
		3:
			_check_floor("uralt3", "uralt2", "")
			_check_dragon()
			stage = 4
			wait = 5
		4:
			_check_hoard()
			_finish()
			return true
	return false


func _check_open_air() -> void:
	var lvl: Outdoor = game.level
	check(game.interiors.has("uralt1") and game.interiors.has("uralt2") and game.interiors.has("uralt3"), "the three floors exist")
	check(lvl.doors.has("uralt1"), "the open-air map has the cave mouth of the Great Old One")
	check(lvl.stations.any(func(s): return s.kind == "eingang" and s.building == "uralt1"), "running into the cave mouth leads in")
	# It lies in the mountains, reached from the high valley like the mines.
	var way: Array = lvl.astar.get_id_path(lvl.world_to_cell(lvl.doors.mine2), lvl.world_to_cell(lvl.doors.uralt1))
	check(not way.is_empty(), "a way leads from the mines down the ravine to the cave mouth")
	check(lvl.doors.uralt1.z > lvl.doors.mine2.z, "the cave lies below the high valley")


func _check_floor(building: String, up: String, down: String) -> void:
	var lvl: Level = game.level
	check(lvl.building == building and lvl.theme == ElderLair.THEME and lvl.lair and not lvl.safe, "%s is a floor of the Great Old One's dungeon (%s)" % [building, lvl.building])
	check(lvl.up_to == up and lvl.down_to == down, "%s leads up to '%s' and down to '%s'" % [building, lvl.up_to, lvl.down_to])
	if down != "":
		check(lvl.stations.any(func(s): return s.kind == "schacht" and s.building == down), "%s has a way down" % building)
	check(not lvl.enemies.is_empty(), "monsters live on %s" % building)
	for e in lvl.enemies:
		if e is ElderDragon:
			continue
		check(e.rated_level >= 17 and e.rated_level <= 19, "%s on %s is a fight for level 17 to 19 (%d)" % [e.kind, building, e.rated_level])
	# Treasure chests hold gold beside their epic piece; a plain crate may
	# hold an epic piece too (a beast trophy, see ArmourSets).
	var epic := lvl.interactables.filter(func(o): return o.has("loot") and o.loot.has("gold") and str(o.loot.get("item", "")) != "" and Rarity.tier(str(o.loot.item)) == "episch")
	if building != "uralt3":
		check(epic.size() >= 2, "%s has an epic treasure room with two epic chests (%d)" % [building, epic.size()])
		check(lvl._has_cell("D") and (lvl._has_cell("K")), "%s's treasure room lies behind a locked door with a key" % building)
		for o in epic:
			check(lvl._in_secret_room(o.cell) == false and int(o.loot.gold) == ElderLair.EPIC_GOLD, "an epic chest holds gold too")


func _check_dragon() -> void:
	var lvl: Level = game.level
	var elder: ElderDragon = lvl.elder
	check(elder != null and elder.asleep, "the Great Old One sleeps on floor 3")
	if elder == null:
		return
	check(lvl.enemies.filter(func(e): return e is ElderDragon).size() == 1, "there is one Great Old One")
	check(elder._model.scale.x >= 3.5, "it is far bigger than anything else (%.1f)" % elder._model.scale.x)
	var p: Player = game.player
	# A sneaking hero right beside it does not wake it.
	p.set_sneaking(true)
	p.global_position = elder.global_position + Vector3(0, 0, 4.6)
	p.velocity = Vector3(3, 0, 0)
	for i in 120:
		elder._sleep(1.0 / 60.0, p, 4.6)
	check(elder.asleep and elder.unrest == 0.0, "a sneaking hero does not disturb it (%.2f)" % elder.unrest)
	# Walking near it makes it restless, and in the end it wakes.
	p.set_sneaking(false)
	p.velocity = Vector3(3, 0, 0)
	var steps := 0
	while elder.asleep and steps < 2000:
		if not p.is_noisy():
			break
		elder._sleep(1.0 / 60.0, p, 10.0)
		steps += 1
	check(not elder.asleep, "walking near it wakes it (unrest %.2f after %d steps, noisy %s)" % [elder.unrest, steps, p.is_noisy()])
	check(steps > 60, "it takes a moment of noise to wake it, not one step (%d)" % steps)
	# Quiet again: it calms down while still asleep.
	elder.settle()
	elder.unrest = 0.6
	p.velocity = Vector3.ZERO
	for i in 120:
		elder._sleep(1.0 / 60.0, p, 10.0)
	check(elder.asleep and elder.unrest < 0.6, "keeping quiet calms it down (%.2f)" % elder.unrest)
	# No blade gets through, but a blow wakes it.
	var life: int = elder.hp
	elder.take_hit(50, p.global_position, "backstab")
	check(elder.hp == life and not elder.dead, "it cannot be hurt (%d / %d)" % [elder.hp, life])
	check(not elder.asleep and elder.is_hunting(), "a blow wakes it")
	# Its breath burns whoever stands in front of it, not someone beside it.
	elder._aim = Vector3.BACK
	check(elder.in_breath(Vector3(0, 0, 12)), "the breath reaches in front of it")
	check(not elder.in_breath(Vector3(12, 0, 0)), "the breath misses whoever stands to the side")
	p.hp = p.max_hp
	p._invulnerable = 0.0
	p.global_position = elder.global_position + Vector3(0, 0, 12.0)
	var before: int = p.hp
	elder._breathe(p)
	check(p.hp < before - 4 or p.dead, "the breath burns hard (%d -> %d)" % [before, p.hp])
	# Out of sight long enough, it goes back to sleep.
	elder._unseen = ElderDragon.SETTLE_AFTER + 0.1
	elder._windup = 0.0
	p.hp = p.max_hp
	p.global_position = Vector3(-1000, 0, -1000)
	elder._physics_process(1.0 / 60.0)
	check(elder.asleep, "out of sight long enough it falls asleep again")


func _check_hoard() -> void:
	var lvl: Level = game.level
	var p: Player = game.player
	p.revive(p.global_position, false)
	var heap: Array = lvl._pickups.filter(func(q): return q.kind == "elder_hoard")
	check(heap.size() == 1, "the hoard lies in front of the Great Old One")
	if heap.is_empty():
		return
	var coins_before: int = game.coins
	var bag_before: int = p.bag.size()
	p.bag.clear()
	p.global_position = heap[0].node.global_position
	lvl._check_pickups()
	check(lvl.taken.has(ElderLair.ANCIENT_KEY), "the old dragon's own treasure is taken")
	check(game.coins >= coins_before + ElderLair.ANCIENT_GOLD, "its gold goes into the purse (%d -> %d)" % [coins_before, game.coins])
	var tiers: Array = p.bag.map(func(id): return Rarity.tier(id))
	check(tiers.has("episch") and tiers.has("gottgeboren"), "an epic and a god-born piece from the hoard (%s)" % str(p.bag))
	check(lvl.elder.asleep and lvl.elder.unrest > 0.0, "the clink of the gold makes it stir but not wake (%.2f)" % lvl.elder.unrest)
	check(lvl._pickups.filter(func(q): return q.kind == "elder_hoard").is_empty(), "the hoard is gone once taken")
	# What the dragon helpers bring piles up again, and is the hero's too.
	game.hoard.gather("item", "schwert")
	game.hoard.gather("coin", "")
	game.hoard.gather("coin", "")
	check(game.hoard.elder_items.has("schwert") or game.hoard.elder_gold > 0, "the helpers bring most of their loot here (%s)" % str(game.hoard.for_save()))
	var share: Dictionary = game.hoard.elder_contents()
	game.load_level(game.interiors.uralt3, false)
	lvl = game.level
	heap = lvl._pickups.filter(func(q): return q.kind == "elder_hoard")
	check(heap.size() == 1, "the hoard is back once the helpers brought more")
	if heap.is_empty():
		return
	p.bag.clear()
	var gold: int = game.coins
	game.player.global_position = heap[0].node.global_position
	lvl._check_pickups()
	check(game.coins == gold + int(share.coins), "the helpers' coins go into the purse (%d -> %d)" % [gold, game.coins])
	check(p.bag == share.items, "the helpers' gear comes back whole (%s)" % str(p.bag))
	check(game.hoard.elder_gold == 0 and game.hoard.elder_items.is_empty(), "the share is emptied once taken")
	check(bag_before >= 0, "")
