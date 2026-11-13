extends SceneTree
## Headless test for wishes and the fighting style: Guild Master Ragna asks
## how the hero likes to fight (with a ! over her head until then), helps
## with wishes only once she thinks well enough of the hero, lists her
## wishes best fit first (the named style first, then what the hero really
## trains), starts a wish's quest when the hero asks for it, rewards it
## with a recipe and a hint at the next wish, and everything is kept in the
## saved game.
## Run with: godot --headless -s tests/wishes.gd

var failures := 0
var game: Node
var frames := 0
## Set at the very end of _test: a script error stops the test early.
var finished := false
const HERO := "Wishes test"


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
	check(finished, "the whole test ran through")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: wishes")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


## Runs into a villager the way the game does it.
func _bump(role: String) -> void:
	for s in game.level.stations:
		if s.get("npc") == _villager(role):
			s.npc._update_bubble(Villager.MIN_SAY_TIME)
			game._use_station(s)
			return
	check(false, "villager %s has a station" % role)


func _said(role: String) -> String:
	return _villager(role)._bubble.text


func _test() -> void:
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.crafting.clear()
	game.wishes.clear()
	game.reputation.clear()
	game.player.xp.clear()
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor and _villager("G") != null, "Ragna is in the village")

	# Every text has its English, and every wish points at things that exist.
	for id in Wishes.STYLES:
		check(Training.SKILLS.has(id), "style %s is a combat skill" % id)
		check(Lang.EN.has(Wishes.STYLES[id].name) and Lang.EN.has(Wishes.STYLES[id].say), "style %s has English texts" % id)
	for role in Wishes.MASTERS:
		check(Villager.ROLES.has(role) and Lang.EN.has(Wishes.MASTERS[role].ask), "master %s exists and has an English line" % role)
	check(Lang.EN.has(Wishes.NOT_YET), "the not-yet line has an English text")
	var styles_covered := {}
	for id in Wishes.ALL:
		var w: Dictionary = Wishes.ALL[id]
		check(Lang.EN.has(w.wish) and Lang.EN.has(w.hint), "wish %s has English texts" % id)
		check(Quests.ALL.has(w.quest) and Quests.ALL[w.quest].get("wish", false), "wish %s has a wish quest" % id)
		check(Quests.ALL[w.quest].giver == w.master, "wish %s: its quest comes from its master" % id)
		var recipe: String = Quests.ALL[w.quest].get("recipe", "")
		check(Crafting.RECIPES.has(recipe) and Crafting.RECIPES[recipe].giver == "", "wish %s rewards a recipe only wishes give" % id)
		for skill in w.fits:
			styles_covered[skill] = true
		for key in ["title", "goal", "offer", "remind", "done"]:
			check(Lang.EN.has(Quests.ALL[w.quest][key]), "wish quest %s: the %s has an English text" % [w.quest, key])
	check(styles_covered.size() == Wishes.STYLES.size(), "every style has a wish")

	# Wish quests are never offered by simply running into Ragna.
	for id in Quests.ALL:
		if Quests.ALL[id].get("wish", false):
			check(not game.quests.is_available(id), "wish quest %s is not offered on its own" % id)

	# Ragna asks the fighting style first.
	game.refresh_quest_marks()
	check(_villager("G").quest_mark() == "!", "Ragna shows a ! until the style is named")
	_bump("G")
	check(game.menus.current == "kampfstil", "running into Ragna asks the fighting style")
	game.menus._choose_style("aexte")
	check(game.wishes.style == "aexte", "the named style is kept")
	check(not game.menus.is_open(), "naming the style closes the window")
	check(_said("G").contains(Wishes.STYLES.aexte.say), "Ragna answers the style")
	check(not game.wishes.choose_style("bogen"), "an unknown style cannot be named")

	# She helps with wishes only once she thinks well of the hero.
	game.refresh_quest_marks()
	check(_villager("G").quest_mark() == "", "no ! while Ragna does not know the hero yet")
	_villager("G")._update_bubble(Villager.MIN_SAY_TIME)
	_bump("G")
	check(not game.menus.is_open() and _said("G").contains(Wishes.NOT_YET), "a stranger is told to help the village first")
	game.reputation.gain("G", 15)
	check(game.wishes.willing("G"), "a friendly Ragna is willing")
	game.refresh_quest_marks()
	check(_villager("G").quest_mark() == "!", "a willing Ragna shows a ! until her wishes were seen")

	# The named style comes first; what the hero trains takes over.
	check(game.wishes.open_wishes("G")[0] == "axtreif", "the named style's wish comes first")
	check(game.wishes.is_best_fit("axtreif") and not game.wishes.is_best_fit("klingenring"), "only the first wish is marked as fitting")
	check(game.wishes.leading_style() == "aexte", "the named style leads before any training")
	game.player.xp["klingen"] = Training.skill_xp_for(6)
	var blades := Training.skill_level(Training.skill_xp_for(6), "klingen")
	check(blades > Wishes.STATED_BONUS, "the blades are trained beyond the named style's bonus (%d)" % blades)
	check(game.wishes.open_wishes("G")[0] == "klingenring", "a well trained skill puts its wish first")
	check(game.wishes.leading_style() == "klingen", "what the hero really does leads now")
	check(game.wishes.open_wishes("G").size() == Wishes.ALL.size(), "every wish is open")

	# The wish window, and asking for a wish.
	_villager("G")._update_bubble(Villager.MIN_SAY_TIME)
	_bump("G")
	check(game.menus.current == "wunsch" and game.menus.wish_master == "G", "a willing Ragna opens her wish window")
	check(game.wishes.seen.has("G"), "her wishes count as seen")
	game.menus.close()
	game.refresh_quest_marks()
	check(_villager("G").quest_mark() == "", "the ! is gone once her wishes were seen")
	game.menus.wish_master = "G"
	game.menus.open("wunsch")
	game.menus._ask_wish("klingenring")
	check(not game.menus.is_open(), "asking for a wish closes the window")
	check(game.quests.is_active("wunsch_klingen") and game.wishes.running("G") == "klingenring", "the wish's quest starts")
	check(game.wishes.ask("axtreif", _villager("G")) != "", "only one wish at a time with a master")
	check(game.wishes.ask("klingenring", _villager("G")) != "", "a wish is asked for only once")
	check(game.quests.log_entries().has("wunsch_klingen"), "the wish's quest is in the quest log")
	check(Quests.reward_text("wunsch_klingen").contains("Klingenring"), "the quest log names the recipe as reward")
	_villager("G")._update_bubble(Villager.MIN_SAY_TIME)
	_bump("G")
	check(not game.menus.is_open() and _said("G").contains("Noch 5 Skelettkrieger"), "while the wish runs, Ragna reminds instead of opening the window")

	# Done: the recipe, and a hint at the next wish.
	for i in 5:
		game.quests.on_kill("krieger")
	game.refresh_quest_marks()
	check(_villager("G").quest_mark() == "?", "Ragna shows a ? when the wish's quest can be handed in")
	_villager("G")._update_bubble(Villager.MIN_SAY_TIME)
	_bump("G")
	check(game.quests.is_done("wunsch_klingen"), "the wish's quest is done")
	check(game.crafting.knows("klingenring"), "the reward is the recipe")
	check(game.crafting.describe("klingenring").contains("Wirkung: Klingen +1"), "the recipe book says what the piece does")
	check(_said("G").contains(Wishes.ALL.axtreif.hint), "Ragna points at the next wish that fits best")
	check(not game.wishes.open_wishes("G").has("klingenring"), "a done wish is not offered again")

	# Kept in the saved game.
	check(game.save_game(), "the game is saved")
	var saved: Dictionary = game.wishes.for_save()
	game.wishes.clear()
	game._apply_save(game._read_save(game.save_path()))
	check(game.wishes.for_save() == saved and game.wishes.style == "aexte", "the saved game brings the style and seen masters back")
	var data: Dictionary = game._read_save(game.save_path())
	data.erase("wishes")
	game._apply_save(data)
	check(game.wishes.style == "" and game.wishes.seen.is_empty(), "an older saved game starts without a style")
	game.wishes.load_from({"style": "bogen", "seen": ["G", "G", "X"]})
	check(game.wishes.style == "" and game.wishes.seen == ["G"], "unknown styles and masters are left out")

	# The style can be changed from the wish window, which then opens again.
	game.wishes.style = "aexte"
	game.menus.wish_master = "G"
	game.menus.open("wunsch")
	game.menus._style_from_wishes = true
	game.menus.open("kampfstil")
	game.menus._choose_style("schleichen")
	check(game.wishes.style == "schleichen" and game.menus.current == "wunsch", "changing the style goes back to the wishes")
	game.menus.close()
	finished = true
