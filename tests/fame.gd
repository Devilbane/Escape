extends SceneTree
## Fame (see Fame, FamePage): four ratings with a level, a title and a hint, shown on the Fame page of the quests
## window, which keeps the window's size and the cards' sizes whatever the hero has done.
## Run with: godot --headless -s tests/fame.gd

const HERO := "Fame test"

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _texts(node: Node) -> Array:
	var out := []
	for l in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _test() -> void:
	# The data is whole.
	for id in Fame.IDS:
		check(Fame.THRESHOLDS[id].size() == Fame.MAX_LEVEL, "%s has a threshold for each level" % id)
		check(Fame.TITLES[id].size() == Fame.MAX_LEVEL, "%s has a title for each level" % id)
		check(Fame.NAMES.has(id) and Fame.HINTS.has(id) and Fame.DONE.has(id), "%s has a name, a hint and a closing line" % id)
		var steps: Array = Fame.THRESHOLDS[id]
		for i in range(1, steps.size()):
			check(float(steps[i]) > float(steps[i - 1]), "%s: the thresholds rise" % id)
	for m in Fame.MASTERS:
		check(Training.SKILLS.has(m.skill) or Training.CRAFTS.has(m.skill), "a master's skill exists: %s" % m.skill)
		check(Villager.ROLES.has(m.role), "a master is a villager: %s" % m.role)
		check(int(m.level) >= 1 and int(m.level) <= Training.SKILL_MAX, "a master's level is within the skills' range: %s" % m.skill)
	check(Fame.REGIONS.has(Fame.DEFAULT_REGION), "the default region exists")

	# Levels and progress.
	check(Fame.level_for("hero", 0.0) == 1, "everybody starts on level 1")
	check(Fame.level_for("hero", 0.3) == 3 and Fame.level_for("hero", 0.29) == 2, "a level begins at its threshold")
	check(Fame.level_for("hero", 5.0) == Fame.MAX_LEVEL, "the top level is the last")
	check(is_equal_approx(Fame.progress_for("hero", 0.2), 0.5), "halfway between two levels is half way (%f)" % Fame.progress_for("hero", 0.2))
	check(Fame.progress_for("hero", 5.0) == 1.0, "the top level is a full bar")
	check(Fame.level_for("richness", 2000.0) == 3 and Fame.level_for("richness", 1999.0) == 2, "richness levels count copper")

	# The ratings of a hero.
	game.hero_name = HERO
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	root.size = Vector2i(1280, 720)
	Lang.language = "en"
	Lang._apply()
	var p: Player = game.player
	p.bag.clear()
	p.equipped.clear()
	game.storage.clear()
	game.piece_stores = {}
	game.home_stores = HomeStores.empty()
	game.coins = 0
	game.crafting.purse.clear()
	game.quests.clear()
	game.riddles.clear()
	var first := Fame.ratings(game)
	check(first.size() == 4, "four ratings")
	for r in first:
		check(r.level == 1 and r.title != "" and r.next != "" and r.hint != "", "a beginner is on level 1 with a title and a hint (%s)" % r.id)
	var hero0: float = Fame.hero(Fame.DEFAULT_REGION, game.quests, game.riddles).value
	var some: String = Quests.ALL.keys()[0]
	game.quests.state[some] = {"state": "done", "count": 0}
	game.riddles.solve(RiddleCount.IDS[0])
	var hero1: Dictionary = Fame.hero(Fame.DEFAULT_REGION, game.quests, game.riddles)
	check(hero0 == 0.0 and hero1.quests == 1 and hero1.riddles == 1 and float(hero1.value) > 0.0, "a task and a riddle raise the Regional Hero value (%s)" % [hero1])
	var worth0: float = Fame.richness(game).value
	game.coins = 1000
	check(float(Fame.richness(game).value) >= worth0 + 1000.0 and Fame.ratings(game)[1].level >= 3, "coins raise Richness")
	var stand := Fame.standings(Fame.DEFAULT_REGION, p)
	check(stand.size() == Fame.MASTERS.size() and float(stand[0].ratio) >= float(stand.back().ratio), "the standings list the best first")
	check(float(Fame.crafts(Fame.DEFAULT_REGION, p).value) == 0.0, "an untrained hero is no match for the masters")
	for m in Fame.MASTERS:
		p.xp[m.skill] = 1.0e9
	var best := Fame.crafts(Fame.DEFAULT_REGION, p)
	check(float(best.value) > 0.0 and Fame.level_for("crafts", float(best.value)) > 1, "trained skills raise Mastery of Crafts (%s)" % [best])
	var seen: Dictionary = Fame.exploration(game)
	check(int(seen.total) > 0 and float(seen.value) >= 0.0 and float(seen.value) <= 1.0, "exploration is a share of the game's squares (%s)" % [seen])

	# The page: one window size, four cards of one size, whatever the hero has done.
	game.menus.quests_page = "log"
	game.menus.open("auftraege")
	await _wait()
	var log_size: Vector2 = (game.menus._panel as Control).size
	game.menus.quests_page = "ruhm"
	game.menus._rebuild()
	await _wait()
	var page_size: Vector2 = (game.menus._panel as Control).size
	check(page_size == log_size, "the Fame page keeps the window's size (%s vs %s)" % [page_size, log_size])
	var texts := _texts(game.menus._box)
	for name in [Lang.t("Regionale Heldenstufe"), Lang.t("Reichtum"), Lang.t("Meisterschaft im Handwerk"), Lang.t("Entdeckergeist")]:
		check(texts.has(name), "the page shows %s" % name)
	check(texts.any(func(t): return t.begins_with("Level ")), "a level is written out")
	var cards: Array = game.menus._box.find_children("*", "PanelContainer", true, false).filter(func(c): return (c as Control).custom_minimum_size.y == FamePage.CARD_HEIGHT)
	check(cards.size() == 4, "four cards (%d)" % cards.size())
	var sizes := {}
	for c in cards:
		sizes[(c as Control).size] = true
	check(sizes.size() == 1, "the cards are of one size (%s)" % [sizes.keys()])
	for id in Quests.ALL:
		game.quests.state[id] = {"state": "done", "count": 0}
	game.coins = 99999
	game.menus._rebuild()
	await _wait()
	check((game.menus._panel as Control).size == page_size, "a changed standing does not resize the window")
	game.menus.quests_page = "log"
	game.menus.close()

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: fame")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
