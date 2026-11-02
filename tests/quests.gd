extends SceneTree
## Headless test for the villagers' quests: villagers hand out tasks when the
## hero runs into them, kills, fetched items and deliveries count, rewards are
## paid once, traders still trade, the quest log shows the tasks, and every
## hero keeps their own tasks in their own saved game.
## Run with: godot --headless -s tests/quests.gd

var failures := 0
var game: Node
var frames := 0
const HEROES := ["Quest test Alpha", "Quest test Beta"]


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
	_test()
	for i in HEROES.size():
		game.delete_save(game.save_path(i + 1))
	if failures == 0:
		print("PASS: quests")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


## Runs into a villager the way the game does it. Each bump is a fresh
## visit: the last line has had time to be read (see Villager.MIN_SAY_TIME).
func _bump(role: String) -> void:
	for s in game.level.stations:
		if s.get("npc") == _villager(role):
			s.npc._update_bubble(Villager.MIN_SAY_TIME)
			game._use_station(s)
			return
	check(false, "villager %s has a station" % role)


func _test() -> void:
	game.hero_name = HEROES[0]
	game.save_slot = 1
	game.met.clear()
	game.quests.clear()
	# Ragna also asks the fighting style (see Wishes); named already here,
	# so her mark shows only her own task.
	game.wishes.clear()
	game.wishes.style = "klingen"
	game.coins = 0
	game.player.bag.clear()
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	for role in ["0", "1", "2", "3", "4", "5", "6", "9", "G", "M", "O"]:
		check(_villager(role) != null, "villager %s lives in the village" % role)
	for id in Quests.ALL:
		var q: Dictionary = Quests.ALL[id]
		check(Villager.ROLES.has(q.giver), "%s has a giver who exists" % id)
		for key in ["title", "goal", "offer", "remind", "done"]:
			check(Lang.EN.has(q[key]), "%s: the %s has an English text" % [id, key])
		if q.has("item"):
			check(Items.ALL.has(q.item) and Lang.EN.has(Items.ALL[q.item].name), "%s: its item exists and has an English name" % id)
	check(game.quests.log_entries().is_empty(), "a new hero has no quests")
	game.refresh_quest_marks()
	check(_villager("4").quest_mark() == "!", "the guard shows a ! while he has a task")
	check(_villager("G").quest_mark() == "", "the guild master shows nothing while his task waits")
	check(_villager("5").quest_mark() == "", "a villager without a task shows nothing")

	# A kill task: the guard wants five bandits.
	_bump("4")
	game.refresh_quest_marks()
	check(_villager("4").quest_mark() == "", "the ! is gone once the task is taken")
	check(game.quests.is_active("raeuberplage"), "the guard hands out his task")
	check(game.met.has("4"), "the guard is met while giving the task")
	check(not game.quests.is_available("hauptmann"), "the chief's task waits for the guard's")
	for i in 4:
		game.quests.on_kill("halsabschneider")
	game.quests.on_kill("krieger")
	check(game.quests.progress("raeuberplage") == "4 / 5", "bandits count, skeletons do not")
	_bump("4")
	check(game.quests.is_active("raeuberplage") and game.coins == 0, "no reward before the task is done")
	game.quests.on_kill("hauptmann")
	game.refresh_quest_marks()
	check(_villager("4").quest_mark() == "?", "the guard shows a ? when the task can be handed in")
	_bump("4")
	check(game.quests.is_done("raeuberplage"), "five bandits finish the task")
	check(game.coins == 25, "the guard pays 25 gold")
	_bump("4")
	check(game.coins == 25, "the reward is paid only once")
	check(game.quests.is_available("hauptmann"), "now the guild master has the chief's task")
	game.refresh_quest_marks()
	check(_villager("4").quest_mark() == "", "the guard shows nothing once paid")
	check(_villager("G").quest_mark() == "!", "the guild master now shows a !")
	_bump("G")
	check(game.quests.is_active("hauptmann"), "the guild master hands out the chief's task")

	# A delivery: the postmaster's letter goes to the elder.
	_bump("M")
	check(game.quests.is_active("brief") and game.player.bag.has("brief"), "the postmaster hands over a letter")
	game.refresh_quest_marks()
	check(_villager("0").quest_mark() == "?", "the elder shows a ? while the hero carries his letter")
	check(_villager("M").quest_mark() == "", "the postmaster shows nothing once the letter is taken")
	_bump("0")
	check(game.quests.is_done("brief") and not game.player.bag.has("brief"), "the elder takes the letter")
	check(game.coins == 35, "the elder pays 10 gold")

	# A lost delivery comes again; the reward is gear.
	_bump("2")
	check(game.player.bag.has("kuerbis"), "the farmer hands over a pumpkin")
	game.player.bag.erase("kuerbis")
	_bump("2")
	check(game.player.bag.has("kuerbis"), "a lost pumpkin is handed over again")
	_bump("5")
	check(game.quests.is_done("kuerbis") and game.player.bag.has("lederstiefel") and game.coins == 40, "the drinker takes the pumpkin and gives boots and 5 gold")

	# A fetch task from a trader: the task first, the goods next time.
	_bump("6")
	check(game.quests.is_active("dolche"), "the shopkeeper hands out her task")
	check(not game.menus.is_open(), "handing out a task does not open the shop")
	_bump("6")
	check(game.menus.current == "haendler", "the next time the shop opens as before")
	game.menus.close()
	seed(1)
	var drops := 0
	for i in 40:
		if game.quests.on_kill("halsabschneider") == "banditendolch":
			drops += 1
	check(drops > 0, "cutthroats drop bandit daggers while Mira wants them")
	check(game.quests.on_kill("schlaeger") == "", "bruisers do not drop daggers")
	game.player.bag.append_array(["banditendolch", "banditendolch", "banditendolch", "banditendolch"])
	check(game.quests.progress("dolche") == "3 / 3", "the quest log counts the daggers in the bag")
	_bump("6")
	check(game.quests.is_done("dolche") and game.coins == 70, "three daggers finish the task for 30 gold")
	check(game.player.bag.count("banditendolch") == 1, "only three daggers are handed over")
	check(game.quests.on_kill("halsabschneider") == "", "no more daggers once the task is done")

	# A gear reward waits until there is room in the bag.
	_bump("1")
	check(game.quests.is_active("schlaeger"), "the smith hands out his task")
	for i in 3:
		game.quests.on_kill("schlaeger")
	while game.player.bag.size() < game.player.bag_size():
		game.player.bag.append("kupferring")
	_bump("1")
	check(game.quests.is_active("schlaeger"), "a full bag keeps the reward back")
	game.player.bag.erase("kupferring")
	_bump("1")
	check(game.quests.is_done("schlaeger") and game.player.bag.has("kettenhemd"), "with room the smith hands over the chain mail")

	# The quest log in the compendium.
	game.menus.compendium_page = "auftraege"
	game.menus.open("kompendium")
	check(game.menus.current == "kompendium", "the compendium opens on the quest log")
	var struck := []
	for l in game.menus._box.find_children("*", "RichTextLabel", true, false):
		if (l as RichTextLabel).text.contains("[s]"):
			struck.append((l as RichTextLabel).get_parsed_text())
	check(struck.any(func(t): return t.contains(Lang.t(Quests.ALL.brief.title)) and t.contains(Lang.t("erledigt"))),
			"a finished quest is struck through and marked done")
	check(not struck.any(func(t): return t.contains(Lang.t(Quests.ALL.hauptmann.title))), "an open quest is not struck through")
	game.menus.close()
	game.menus.compendium_page = "wissen"
	var entries: Array = game.quests.log_entries()
	check(entries[0] == "hauptmann", "open quests come first in the log")
	check(entries.has("brief") and entries.has("raeuberplage"), "finished quests stay in the log")

	# Every hero keeps their own quests.
	check(game.save_game(), "the game is saved")
	var saved: Dictionary = game.quests.for_save()
	game.hero_name = HEROES[1]
	game.save_slot = 2
	game.quests.clear()
	check(game.save_game(), "another hero's game is saved")
	game._apply_save(game._read_save(game.save_path(2)))
	check(game.quests.log_entries().is_empty(), "the other hero has no quests")
	game._apply_save(game._read_save(game.save_path(1)))
	check(game.quests.for_save() == saved, "the saved game brings the quests back")
	check(game.quests.is_active("hauptmann") and game.quests.is_done("brief"), "open and finished quests are kept apart")

	# Saved games from before quests load fine.
	var data: Dictionary = game._read_save(game.save_path(1))
	data.erase("quests")
	game._apply_save(data)
	check(game.quests.log_entries().is_empty(), "an older saved game starts without quests")
	game.quests.load_from({"unknown": {"state": "done"}, "brief": "broken", "wasser": {"state": "active", "count": 0}})
	check(game.quests.log_entries() == ["wasser"], "broken or unknown entries are left out")

	# The chief falls only once. Felled before his task was taken (he counts
	# for the guard's five bandits too), the task is done when it is given.
	game.quests.load_from({"raeuberplage": {"state": "done", "count": 5}})
	game.looted.clear()
	game.player.bag.clear()
	game.coins = 0
	check(not game.boss_fallen("hauptmann"), "the chief stands in a fresh game")
	game.looted["11_die_freiheit.txt"] = {Outdoor.CHIEF_DEFEATED: true}
	check(game.boss_fallen("hauptmann"), "a fallen chief is remembered")
	_bump("G")
	check(game.quests.is_done("hauptmann"), "the chief's task is done at once when he fell before it was given")
	check(game.coins == 40 and game.player.bag.has("schattenumhang"), "the guild master pays for a chief felled earlier")

	# A game saved with the task open and the chief already gone is mended
	# when it loads.
	game.quests.load_from({"raeuberplage": {"state": "done", "count": 5}, "hauptmann": {"state": "active", "count": 0}})
	check(game.save_game(), "a game with the chief's task open is saved")
	var stuck: Dictionary = game._read_save(game.save_path(1))
	stuck["looted"] = {"11_die_freiheit.txt": [Outdoor.CHIEF_DEFEATED]}
	stuck["quests"] = {"raeuberplage": {"state": "done", "count": 5}, "hauptmann": {"state": "active", "count": 0}}
	game._apply_save(stuck)
	check(game.quests.is_active("hauptmann") and game.quests.missing("hauptmann") == 0, "loading counts a chief who fell already")
	game.refresh_quest_marks()
	check(_villager("G").quest_mark() == "?", "the guild master waits with the reward")
	# While the chief still stands, the task stays open.
	stuck["looted"] = {}
	game._apply_save(stuck)
	check(game.quests.missing("hauptmann") == 1, "a standing chief still has to be beaten")

	# A wolf landing the last blow on the chief does not cost the hero the task.
	var chief := BanditChief.new()
	game.level.add_child(chief)
	chief.slain_by_rival = true
	game._on_enemy_killed(chief)
	check(game.quests.missing("hauptmann") == 0, "a chief felled by a rival still counts for the hero")
	var cutthroat := Enemy.new()
	cutthroat.kind = "halsabschneider"
	game.level.add_child(cutthroat)
	cutthroat.slain_by_rival = true
	game.quests.load_from({"raeuberplage": {"state": "active", "count": 0}})
	game._on_enemy_killed(cutthroat)
	check(game.quests.progress("raeuberplage") == "0 / 5", "other bandits felled by rivals still do not count")
	chief.free()
	cutthroat.free()
