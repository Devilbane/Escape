extends SceneTree
## Headless test for the event bus (see Events): what the features report
## there reaches the game and the other features, and the game lets go of the
## bus when it leaves the tree.
## Run with: godot --headless -s tests/events.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Event bus test"


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
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: events")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	var bus := Events.bus()
	check(bus == Events.bus(), "there is one bus")
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.reputation.clear()
	Factions.clear()
	game.bounties.clear()
	game.bounties.refresh(game.day)
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")

	# News and lore go to the game.
	Events.tell("Testnachricht", Color.WHITE)
	check(game._message.text == "Testnachricht", "news shows up as a message: %s" % game._message.text)
	Events.teach("Testeintrag")
	check(game.lore.has("Testeintrag"), "lore goes into the compendium")
	var names: Array[String] = ["Testort"]
	bus.map_grew.emit(names)
	check(game.lore.has(game.MAP_LEARN), "a growing map is explained")

	# A slain enemy counts for its faction and for the bounties.
	var before := Factions.favour_of("wolves")
	bus.enemy_slain.emit("wolf")
	check(Factions.favour_of("wolves") < before, "the wolves mind a slain wolf")
	var id: String = game.bounties.posted[0]
	var hunt: Dictionary = Bounties.POOL[id]
	check(game.bounties.take(id), "a posted hunt can be taken on")
	bus.enemy_slain.emit(hunt.targets[0])
	check(game.bounties.progress(id) == "1 / %d" % hunt.count, "a slain target counts for the hunt: %s" % game.bounties.progress(id))

	# A finished task: the reward is told, and the giver thinks better of the hero.
	var rep: Reputation = game.reputation
	var q: Dictionary = Quests.ALL["raeuberplage"]
	bus.quest_done.emit("raeuberplage")
	check(game._message.text.begins_with(Lang.t("Auftrag abgeschlossen: %s\nBelohnung: %s").get_slice(":", 0)), "the reward is told: %s" % game._message.text)
	check(rep.points(q.giver) == Reputation.QUEST_GIVER, "the giver heard of it: %d" % rep.points(q.giver))

	# Trading raises the trader's standing.
	rep.clear()
	bus.traded.emit("S")
	check(int(rep.standing.get("S", {}).get("trade", 0)) == Reputation.TRADE, "the trader is glad of the trade")

	# Leaving the tree lets go of the bus; coming back listens once again.
	var links := bus.news_told.get_connections().size()
	check(links == 1, "the game listens to the news once: %d" % links)
	root.remove_child(game)
	check(bus.news_told.get_connections().is_empty(), "the game stops listening when it leaves")
	check(bus.enemy_slain.get_connections().is_empty(), "nobody counts kills without the game")
	root.add_child(game)
	check(bus.news_told.get_connections().size() == 1, "back in the tree, the game listens once")
	check(bus.enemy_slain.get_connections().size() == 2, "factions and bounties count kills again")
