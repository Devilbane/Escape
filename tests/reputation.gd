extends SceneTree
## Headless test for the villagers' reputation: finished tasks and trading
## raise standing, standing gives discounts at the villagers who trade,
## friendly villagers share gossip, trusted ones teach their secret recipes
## for the time away, and every hero keeps their own standing in their own
## saved game.
## Run with: godot --headless -s tests/reputation.gd

var failures := 0
var game: Node
var frames := 0
const HEROES := ["Reputation test Alpha", "Reputation test Beta"]


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
	for hero in HEROES:
		game.delete_save(game.save_path(hero))
	if failures == 0:
		print("PASS: reputation")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


## Runs into a villager the way the game does it, as a fresh visit.
func _bump(role: String) -> void:
	for s in game.level.stations:
		if s.get("npc") == _villager(role):
			s.npc._update_bubble(Villager.MIN_SAY_TIME)
			game._use_station(s)
			return
	check(false, "villager %s has a station" % role)


func _test() -> void:
	var rep: Reputation = game.reputation
	# The tables: every text has its English, every secret its recipe.
	for role in Reputation.GOSSIP:
		check(Villager.ROLES.has(role), "gossip for villager %s, who exists" % role)
		for line in Reputation.GOSSIP[role]:
			check(Lang.EN.has(line), "gossip has an English text: %s" % line)
	for role in Reputation.SECRETS:
		var secret: Dictionary = Reputation.SECRETS[role]
		check(Offline.RECIPES.has(secret.recipe) and Offline.RECIPES[secret.recipe].get("secret", "") == role, "%s teaches a secret recipe that exists" % role)
		check(Lang.EN.has(secret.say) and Lang.EN.has(secret.learn) and Lang.EN.has(Offline.RECIPES[secret.recipe].name), "%s's secret has English texts" % role)
	for l in Reputation.LEVELS:
		check(Lang.EN.has(l.name), "the level %s has an English name" % l.name)
	check(Lang.EN.has(Reputation.HOW_TO), "the explanation has an English text")

	game.hero_name = HEROES[0]
	game.met.clear()
	game.quests.clear()
	rep.clear()
	game.coins = 0
	game.player.bag.clear()
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")

	# A stranger pays full price.
	check(rep.level("4") == 0 and rep.price("4", 100) == 100, "strangers give no discount")
	check(rep.price("", 100) == 100, "no villager, no discount")
	check(not rep.can_craft("messer_gorm") and rep.can_craft("messer"), "secret recipes wait until they are taught")
	check(not game.away_choices().craft.has("messer_gorm"), "the day plan does not offer a secret recipe yet")

	# A finished task: the giver trusts the hero, word gets around.
	_bump("5")
	check(game.met.has("5"), "the drinker is met")
	_bump("4")
	check(game.quests.is_active("raeuberplage"), "the guard hands out his task")
	for i in 5:
		game.quests.on_kill("halsabschneider")
	_bump("4")
	check(game.quests.is_done("raeuberplage"), "the task is done")
	check(rep.points("4") == Reputation.QUEST_GIVER and rep.level("4") == Reputation.TRUSTED, "the guard trusts the hero now")
	check(rep.points("5") == Reputation.WORD_OF_MOUTH, "the drinker heard about it")
	check(rep.points("8") == 0, "someone the hero never met heard nothing")
	check(rep.price("4", 100) == 90, "a trusted villager gives 10% off")
	check(rep.price("4", 1) == 1, "nothing costs less than 1 gold")

	# A delivery counts for both ends.
	_bump("M")
	_bump("0")
	check(game.quests.is_done("brief"), "the letter is delivered")
	check(rep.points("M") == Reputation.QUEST_GIVER and rep.points("0") == Reputation.QUEST_RECEIVER, "giver and receiver both think better of the hero")
	check(rep.points("4") == Reputation.QUEST_GIVER + Reputation.WORD_OF_MOUTH, "the guard hears about the letter too")

	# Gossip: a friendly villager shares some every other talk.
	rep.gain("5", 10)
	check(rep.level("5") == Reputation.FRIENDLY, "the drinker is friendly")
	_bump("5")
	_bump("5")
	var gossip: String = Lang.t(Reputation.GOSSIP["5"][0])
	check(_villager("5")._bubble.text.ends_with(gossip), "the friendly drinker shares gossip")
	_bump("5")
	check(not _villager("5")._bubble.text.ends_with(gossip), "and the usual talk in between")

	# Trading counts, but only so far.
	for i in 40:
		rep.on_trade("S")
	check(rep.points("S") == Reputation.TRADE_CAP, "trading alone stops at the trade cap")
	check(rep.level("S") == Reputation.TRUSTED, "a good customer is trusted")

	# A trusted villager teaches a secret recipe once, before the goods.
	_bump("S")
	check(rep.knows_recipe("steine_hagen"), "the stonemason teaches his secret")
	check(not game.menus.is_open(), "teaching the secret does not open the goods")
	check(game.lore.has(Reputation.SECRETS["S"].learn), "the compendium keeps the secret")
	check(game.away_choices().craft.has("steine_hagen"), "the day plan offers the secret recipe")
	game.coins = 100
	_bump("S")
	check(game.menus.current == "steinmetz" and game.trader_role == "S", "the next time the goods open")
	var stone_price: int = rep.price("S", Items.ALL[Menus.STONE].price)
	game.menus._buy_stones(1)
	check(game.coins == 100 - stone_price and game.player.bag.has(Menus.STONE), "the stonemason sells at his price for the hero")
	game.menus.close()
	check(game.trader_role == "", "closing the window ends the trade")
	rep.gain("S", 100)
	check(rep.price("S", 10) == 8, "an honoured villager gives 20% off")
	check(rep.to_next("S") == 0, "nothing beyond honoured")

	# The secret recipe in the time away: a block every 4 hours, into the chest.
	var plan := Offline.normalized({"craft": "steine_hagen", "craft_hours": 8}, {"craft": ["steine_hagen"]})
	var day := Offline.simulate(plan, 24.0)
	check(day.stones == 2, "8 hours of cutting make two stone blocks")
	game.storage.clear()
	var stones: int = game.storage.count(Menus.STONE)
	game._apply_away(plan, day)
	check(game.storage.count(Menus.STONE) == stones + 2, "the cut blocks wait in the chest")

	# The smith's prices follow his standing too.
	rep.gain("1", 45)
	game.trader_role = "1"
	check(Forge.ware_price(game, "langschwert") == rep.price("1", Items.ALL["langschwert"].price), "Gorm's own work is cheaper for an honoured hero")
	check(Forge.forge_cost("schwert", game).gold <= Forge.forge_cost("schwert").gold, "forging is no dearer")
	game.trader_role = ""
	check(Forge.ware_price(game, "langschwert") == Items.ALL["langschwert"].price, "away from Gorm's window the price is the usual")

	# The reputation page in the compendium.
	game.menus.compendium_page = "ruf"
	game.menus.open("kompendium")
	check(game.menus.current == "kompendium", "the compendium opens on the reputation page")
	game.menus.close()
	game.menus.compendium_page = "wissen"

	# Every hero keeps their own standing.
	check(game.save_game(), "the game is saved")
	var saved: Dictionary = rep.for_save()
	game.hero_name = HEROES[1]
	rep.clear()
	check(game.save_game(), "another hero's game is saved")
	game._apply_save(game._read_save(game.save_path(HEROES[1])))
	check(rep.points("4") == 0 and rep.recipes.is_empty(), "the other hero is a stranger")
	game._apply_save(game._read_save(game.save_path(HEROES[0])))
	check(rep.for_save() == saved, "the saved game brings the standing back")
	check(rep.knows_recipe("steine_hagen"), "and the secret recipes")

	# Saved games from before reputation load fine; broken entries are left out.
	var data: Dictionary = game._read_save(game.save_path(HEROES[0]))
	data.erase("reputation")
	game._apply_save(data)
	check(rep.standing.is_empty() and rep.recipes.is_empty(), "an older saved game starts as a stranger")
	rep.load_from({"standing": {"nobody": {"points": 5}, "4": "broken", "6": {"points": 12, "trade": 999}}, "recipes": ["messer", "unknown", "messer_gorm"]})
	check(rep.standing.keys() == ["6"] and rep.points("6") == 12 + Reputation.TRADE_CAP, "unknown villagers are left out, trade is capped")
	check(Array(rep.recipes) == ["messer_gorm"], "only real secret recipes are kept")
