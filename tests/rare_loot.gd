extends SceneTree
## Headless test for loot that must not repeat: common things (a plain sword,
## leather boots, a torch) may lie in several containers of one level, but
## anything finer, books included, turns up there once at most. A secret room
## of three chests never holds the same book three times.
## Run with: godot --headless -s tests/rare_loot.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## The game needs a few frames to set itself up first.
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test_rarity()
	_test_picks()
	_test_levels()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: rare loot")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test_rarity() -> void:
	check(Items.is_common("schwert") and Items.is_common("lederstiefel") and Items.is_common("fackel"), "starter gear and torches are common")
	check(not Items.is_common("fechtbuch") and not Items.is_common("schleichbuch"), "books are not common")
	check(not Items.is_common("amulett_leben") and not Items.is_common("kettenhemd"), "uncommon gear is not common")
	check(Items.is_common("axt") and Items.is_common("rundschild") and Items.is_common("lederwams"), "basic gear is common")
	# Every item has a rarity of its own, except the hero's crafted pieces
	# (shown as their own work) and the map workshop's gear.
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.get("crafted", false) or item.get("custom", false):
			continue
		check(Items.RARITY.has(id), "%s has a rarity in Items.RARITY" % id)
	for id in Items.RARITY:
		check(Items.ALL.has(id), "Items.RARITY lists %s, which is no item" % id)
		check(Level.TIERS.has(Items.RARITY[id]), "%s has a known rarity, not %s" % [id, Items.RARITY[id]])


## Many picks for one level, as rich as the richest secret rooms: no fine
## item twice while others still fit, and still an item once all are taken.
func _test_picks() -> void:
	for tier in ["ungewoehnlich", "selten", "episch", "gottgeboren"]:
		for area in [3, 6, 9, 13]:
			var lvl := Level.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%d" % [tier, area])
			var min_rank := Level.tier_rank(tier)
			var pool := {}
			for i in 200:
				pool[Items.random_item(rng, min_rank, "", area)] = true
			var seen := {}
			for i in pool.size():
				var id := lvl.loot_item(rng, min_rank, area)
				check(not seen.has(id), "%s repeats in a %s room of level %d while other gear still fits" % [id, tier, area])
				seen[id] = true
			check(Items.ALL.has(lvl.loot_item(rng, min_rank, area)), "a %s room of level %d still holds gear once all fitting gear is taken" % [tier, area])
			lvl.free()
	# A godborn room on a shallow level (Das Tor): only one piece of gear
	# suits it, so the other chests reach for the nearest finer gear rather
	# than the same book again.
	var gate := Level.new()
	var gate_rng := RandomNumberGenerator.new()
	gate_rng.seed = 10
	var gate_seen := {}
	for i in 3:
		var id := gate.loot_item(gate_rng, Level.tier_rank("gottgeboren"), 6)
		check(not gate_seen.has(id), "%s repeats in a godborn room of level 6" % id)
		gate_seen[id] = true
	gate.free()
	# Common things may still repeat.
	var plain := Level.new()
	var plain_rng := RandomNumberGenerator.new()
	plain_rng.seed = 7
	var common := {}
	var repeated := false
	for i in 200:
		var id := plain.loot_item(plain_rng, 0, 1)
		if Items.is_common(id):
			repeated = repeated or common.has(id)
			common[id] = true
	check(repeated, "common gear may turn up more than once on a level")
	plain.free()


## Every dungeon level as it is built: no fine item in two containers.
func _test_levels() -> void:
	game.hero_name = "Rare loot test"
	game.escaped = false
	var secret_items := 0
	var beginner_floors := 0
	for i in game.level_files.size():
		game.load_level(i, false)
		var lvl: Level = game.level
		var seen := {}
		var file: String = game.level_files[i].get_file()
		if lvl.beginner_dungeon:
			beginner_floors += 1
			# What the skeletons wear, and may drop, is common.
			for spot in lvl._map_enemies:
				var e: Enemy = spot.enemy
				if is_instance_valid(e):
					for g in e.gear:
						check(Items.is_common(g), "a monster on %s wears %s, which is not common" % [file, g])
		for obj in lvl.interactables:
			var id: String = obj.loot.get("item", "")
			if id == "":
				continue
			# The beginner dungeon holds common things only, but for its
			# secret room and a puzzle's gated chest.
			if lvl.beginner_dungeon and not lvl._in_secret_room(obj.cell) and not lvl._behind_gate(obj.cell):
				check(Items.is_common(id), "%s in %s on %s is not common" % [id, obj.id, file])
			if not Level.is_outdoor_file(game.level_files[i]) and lvl._in_secret_room(obj.cell) and obj.label == "Schatztruhe":
				secret_items += 1
			if Items.is_common(id):
				continue
			check(not seen.has(id), "%s lies in two containers of %s (%s and %s)" % [id, game.level_files[i], seen.get(id, ""), obj.id])
			seen[id] = obj.id
	check(secret_items > 0, "secret treasure chests still hold gear")
	check(beginner_floors == 10, "the ten floors from Die Zelle to Das Tor are the beginner dungeon, not %d" % beginner_floors)
