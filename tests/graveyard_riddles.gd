extends SceneTree
## Headless test of the graveyards' riddle prize (see GraveyardRiddles): one solved riddle teaches nothing, the second
## teaches Necromancy at level 0 and says so, the same riddle twice counts once, unknown ids count for nothing, and the
## count is kept in the saved game and cleared with it.
## Run with: godot --headless -s tests/graveyard_riddles.gd

var failures := 0
var game: Node
var frames := 0
var told: Array[String] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: graveyard riddles" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	game.hero_name = "Graveyard riddles test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.graveyard_riddles.clear()
	game.player.xp.erase(GraveyardRiddles.SKILL)
	Events.bus().news_told.connect(func(text: String, _c: Color, _d: float): told.append(text))
	check(Training.CRAFTS.has(GraveyardRiddles.SKILL) and SkillTrees.ALL.has(GraveyardRiddles.SKILL), "Necromancy is a skill of the game")
	check(not GraveyardRiddles.knows(game.player), "not known to begin with")
	Events.bus().graveyard_riddle.emit(GraveyardRiddles.BELL)
	check(game.graveyard_riddles.count() == 1 and not GraveyardRiddles.knows(game.player), "one riddle teaches nothing")
	Events.bus().graveyard_riddle.emit(GraveyardRiddles.BELL)
	Events.bus().graveyard_riddle.emit("no such riddle")
	check(game.graveyard_riddles.count() == 1 and not GraveyardRiddles.knows(game.player), "the same riddle twice and unknown ones count for nothing")
	Events.bus().graveyard_riddle.emit(GraveyardRiddles.SPIRIT)
	check(game.graveyard_riddles.count() == 2 and GraveyardRiddles.knows(game.player), "the second teaches Necromancy")
	check(Training.skill_level(game.player.xp.get(GraveyardRiddles.SKILL, 0.0), GraveyardRiddles.SKILL) == 0, "at level 0")
	check(told.has(Lang.t(GraveyardRiddles.OPENED)), "and says so")
	# A third changes nothing, and what was trained stays.
	game.player.xp[GraveyardRiddles.SKILL] = 12.0
	told.clear()
	Events.bus().riddle_done.emit(RiddleCount.OWL_CLOCK)
	Events.bus().graveyard_riddle.emit(GraveyardRiddles.OWL_CLOCK)
	check(game.graveyard_riddles.count() == 3 and game.player.xp[GraveyardRiddles.SKILL] == 12.0 and told.is_empty(), "a third changes nothing")
	# The quest "Tales of the Crypt" counts the tales, skulls included, and the counter stone every riddle.
	check(game.quests.is_active(Quests.TALES) and game.quests.progress(Quests.TALES) == "3 / 4", "the quest log counts three tales of four")
	check(game.riddles.count() == 3, "and the counter stone counts them (%d)" % game.riddles.count())
	Events.bus().graveyard_riddle.emit(GraveyardRiddles.SKULLS)
	check(game.quests.is_done(Quests.TALES) and game.riddles.count() == 4, "the fourth tale finishes the quest")
	# The skulls are no riddle of the kind that teaches Necromancy.
	var other := GraveyardRiddles.new()
	other.solve(GraveyardRiddles.SKULLS)
	other.solve(GraveyardRiddles.BELL)
	check(other.count() == 2 and other.riddles_solved() == 1, "skulls and one riddle are one riddle for the prize")
	# Saved and cleared.
	var saved: Array = game.graveyard_riddles.for_save()
	var again := GraveyardRiddles.new()
	again.load_from(saved + ["junk"])
	check(again.count() == 4, "the count is saved (junk left out)")
	game.graveyard_riddles.clear()
	check(game.graveyard_riddles.count() == 0, "and cleared with a new game")
