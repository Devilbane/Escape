extends SceneTree
## Test of the owl clock riddle (see OwlClock, GraveLore, RiddleCount): the clock owl keeps time with the
## pattern on a full-moon night only, the woods' owls keep quiet while it strikes, every gravestone of the
## graveyard has its own text, the counter stone counts and the pieces of the riddle exist. The answers are
## never written here: the test asks the riddle for them.
## Run with: godot --headless -s tests/owl_clock.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The pattern: its rounds and gaps agree.
	var pattern := OwlClock.pattern()
	check(pattern.size() >= 2 and OwlClock.hoots() > pattern.size(), "a pattern of groups")
	var long_gaps := 0
	for i in OwlClock.hoots():
		if OwlClock.gap_after(i) > OwlClock.HOOT_GAP:
			long_gaps += 1
	check(long_gaps == pattern.size(), "one long gap after each group")
	check(OwlClock.gap_after(OwlClock.hoots() - 1) == OwlClock.ROUND_PAUSE, "the round ends with the long pause")
	check(OwlClock.striking(23.0) and OwlClock.striking(2.0) and not OwlClock.striking(12.0), "the hours of the clock")
	check(OwlClock.GROUP_GAP > OwlClock.HOOT_GAP * 2.0, "groups can be told apart")
	# The grave and the tree stand on the map.
	var rows := FileAccess.get_file_as_string("res://levels/11_die_freiheit.txt").split("\n")
	var body := rows.slice(rows.find("") + 1)
	var grave := OwlClock.grave_cell()
	check(body[grave.y][grave.x] == "g", "the grave is a grave on the map")
	var tree := OwlClock.OWL_TREE_CELL
	check(body[tree.y][tree.x] == "d", "the owl's tree is a dead tree")
	var counter := RiddleCount.grave_of("Apfeltal")
	check(body[counter.y][counter.x] == "g" and counter != grave, "the counter has a grave of its own")
	# Every grave of the graveyard has a text of its own.
	var seen := {}
	var graves := 0
	for y in 22:
		for x in 24:
			if body[y][x] == "g":
				var entry := OwlClock.inscription(graves, Vector2i(x, y), "Apfeltal")
				var key := String(entry.name) + String(entry.text)
				check(not seen.has(key), "a text of its own for grave %d" % graves)
				seen[key] = true
				graves += 1
	check(graves <= GraveLore.OTHERS.size(), "enough texts for %d graves" % graves)
	# The clock owl.
	var cell := func(c: Vector2i) -> Vector3: return Vector3(c.x * 4.0, 0.0, c.y * 4.0)
	var trees := []
	for i in 8:
		trees.append({"pos": Vector3((i % 4) * 24.0, 0.0, (i / 4) * 24.0), "height": 7.0, "cell": Vector2i(i % 4 * 5, i / 4 * 5 + 1), "in_village": false})
	var owls := Owls.new(trees, cell, 4.0, "test")
	root.add_child(owls)
	var tree_at := Vector3(200, 0, 200)
	owls.add_clock_owl(tree_at + Vector3(0, OwlClock.OWL_HEIGHT, 0), tree_at + Vector3(10, 0, 0))
	await process_frame
	check(owls.clock_owl == owls.owls.size() - 1, "the clock owl is the last owl")
	var hoots := {}
	var times := []
	var clock := [0.0]
	owls.hooted.connect(func(i: int, sound: String):
		hoots[i] = int(hoots.get(i, 0)) + 1
		if i == owls.clock_owl:
			check(sound == OwlClock.SOUND, "the clock owl's own sound")
			times.append(clock[0]))
	var hero := tree_at + Vector3(8, 0, 6)
	# Not a full moon: the clock keeps still.
	for i in 200:
		owls.tick(0.25, hero, 23.0)
	check(not hoots.has(owls.clock_owl), "the clock owl keeps still at other moons")
	# A full-moon night: the pattern, and the others quiet.
	owls.clock_on = true
	hoots.clear()
	times.clear()
	clock[0] = 0.0
	var rounds := 2
	var length := OwlClock.START_DELAY
	for i in OwlClock.hoots():
		length += OwlClock.gap_after(i)
	for i in int((length * rounds + 1.0) / 0.1):
		clock[0] += 0.1
		owls.tick(0.1, hero, 23.0)
	for k in owls.owls.size():
		if k != owls.clock_owl:
			check(not hoots.has(k), "the woods' owl %d keeps quiet while the clock strikes" % k)
	check(times.size() >= OwlClock.hoots() * rounds, "the owl strikes %d hoots, heard %d" % [OwlClock.hoots() * rounds, times.size()])
	# Group sizes from the gaps heard.
	var groups: Array[int] = []
	var run := 1
	for i in range(1, OwlClock.hoots()):
		var gap: float = times[i] - times[i - 1]
		if gap > OwlClock.HOOT_GAP * 1.5:
			groups.append(run)
			run = 1
		else:
			run += 1
	groups.append(run)
	check(groups == pattern, "the hoots come in the pattern's groups")
	# Daytime: no hoots even on a full moon.
	hoots.clear()
	times.clear()
	for i in 200:
		owls.tick(0.25, hero, 12.0)
	check(times.is_empty(), "no clock by day")
	# The counter stone.
	var count := RiddleCount.new()
	check(count.card("Apfeltal").contains("00/%02d" % RiddleCount.TOTAL), "the counter starts at nothing: %s" % count.card("Apfeltal"))
	var begin := count.card("Apfeltal")
	check(count.solve(RiddleCount.OWL_CLOCK) and not count.solve(RiddleCount.OWL_CLOCK), "a riddle counts once")
	check(count.card("Apfeltal").contains("01/%02d" % RiddleCount.TOTAL) and count.card("Apfeltal") != begin, "one solved changes the stone")
	check(not count.solve("nonsense") and RiddleCount.IDS.size() == RiddleCount.TOTAL, "only official riddles count")
	var again := RiddleCount.new()
	again.load_from(count.for_save())
	check(again.count() == 1, "the count is saved")
	# The pieces: bell recipe, items, Death and the crypt.
	check(Items.ALL.has(OwlClock.BELL) and Items.ALL.has(OwlClock.REWARD), "the bell and the reward are items")
	check(Crafting.RECIPES.has(OwlClock.BELL) and Crafting.RECIPES[OwlClock.BELL].result == OwlClock.BELL, "the bell has a recipe")
	for ingredient in Crafting.RECIPES[OwlClock.BELL].ingredients:
		check(Crafting.INGREDIENTS.has(ingredient) or Loot.COIN_COLORS.has(ingredient) or ingredient in ["silber", "eisen", "gold"], "ingredient %s exists" % ingredient)
	check(Enemy.KINDS.has(OwlClock.DEATH_KIND) and MonsterFamilies.KINDS.get(OwlClock.DEATH_KIND, "") != "", "Death is a monster of a family")
	check(FileAccess.file_exists("res://levels/42_owlavs_gruft.txt"), "the crypt's map exists")
	# The seal covers the answer.
	check(RiddleSeal.open("") == "" and RiddleSeal.numbers(OwlClock._PATTERN).size() == pattern.size(), "the seal opens")
	print("PASS: owl clock" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
