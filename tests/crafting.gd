extends SceneTree
## Headless test for recipes, the ingredient pouch and the crafts: Odo the
## Scholar hands out the Moonsilver Ring recipe (with a ! over his head
## until then), the recipe shows in the compendium with its faded lines,
## ingredients go into the pouch, the craft shows on the character page, and
## everything is kept in the saved game.
## Run with: godot --headless -s tests/crafting.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Crafting test"


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
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: crafting")
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


func _test() -> void:
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.crafting.clear()
	game.iron = 0
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")

	# Every text has its English.
	for id in Crafting.INGREDIENTS:
		for key in ["name", "where"]:
			check(Lang.EN.has(Crafting.INGREDIENTS[id][key]), "%s: the %s has an English text" % [id, key])
	for id in Crafting.RECIPES:
		var r: Dictionary = Crafting.RECIPES[id]
		check(Lang.EN.has(r.name) and Lang.EN.has(r.offer), "%s has an English name and offer" % id)
		check(Villager.ROLES.has(r.giver), "%s has a giver who exists" % id)
		check(Training.CRAFTS.has(r.craft) and Lang.EN.has(Training.CRAFTS[r.craft].name), "%s needs a craft that exists" % id)
		for ingredient in r.ingredients:
			check(ingredient == "eisen" or Crafting.INGREDIENTS.has(ingredient), "%s: %s is an ingredient" % [id, ingredient])
		for line in r.lines:
			check(Lang.EN.has(line.text), "%s: line %s has an English text" % [id, line.id])
			if line.get("hidden", false):
				check(Lang.EN.has(line.faded), "%s: faded line %s has an English fragment" % [id, line.id])
	check(Lang.EN.has(Crafting.HOW_TO), "the how-to has an English text")

	# Odo hands out the recipe, once.
	check(game.crafting.entries().is_empty(), "a new hero knows no recipes")
	game.refresh_quest_marks()
	check(_villager("8") != null, "Odo the Scholar lives in the village")
	check(_villager("8").quest_mark() == "!", "Odo shows a ! while he has a recipe")
	_bump("8")
	check(game.crafting.knows("mondsilberring"), "Odo hands over the Moonsilver Ring recipe")
	check(game.met.has("8"), "Odo is met while handing it over")
	check(game.lore.has(Crafting.HOW_TO), "the compendium explains recipes")
	game.refresh_quest_marks()
	check(_villager("8").quest_mark() == "", "the ! is gone once the recipe is taken")
	check(not game.crafting.talk(_villager("8")), "the recipe is handed over only once")

	# The scroll: faded lines show their fragment until they are read.
	var text: String = game.crafting.describe("mondsilberring")
	check(text.contains("Ein stilles … ohne …") and not text.contains("Gemüt"), "a faded line shows only its fragment")
	check(text.contains("Mondsilbererz 0 / 2") and text.contains("Eisenbarren 0 / 1"), "the ingredients are counted")
	check(text.contains("Feinschmieden 0 / 3"), "the craft level is shown")
	check(game.crafting.read_line("mondsilberring", "gemuet"), "a faded line can be read")
	check(not game.crafting.read_line("mondsilberring", "gemuet"), "a line is read only once")
	check(game.crafting.describe("mondsilberring").contains("Ein stilles Gemüt"), "a read line shows in full")

	# The pouch, with the smith's iron bars counted in.
	check(game.crafting.pouch_text() == "Dein Zutatenbeutel ist leer.", "the pouch starts empty")
	game.crafting.add("mondsilbererz", 2)
	game.crafting.add("mondstein")
	game.crafting.add("unbekannt")
	check(game.crafting.have("mondsilbererz") == 2 and game.crafting.have("unbekannt") == 0, "known ingredients go into the pouch")
	check(not game.crafting.has_ingredients("mondsilberring"), "an iron bar is still missing")
	game.iron = 1
	check(game.crafting.has_ingredients("mondsilberring"), "with an iron bar everything is there")
	check(game.player.bag.is_empty() or not game.player.bag.has("mondstein"), "ingredients do not fill the bag")

	# The compendium page and the character page.
	game.menus.compendium_page = "rezepte"
	game.menus.open("kompendium")
	check(game.menus.current == "kompendium" and game.menus.compendium_page == "rezepte", "the compendium opens on the recipes")
	game.menus.close()
	game.menus.compendium_page = "wissen"
	game.menus.open("charakter")
	check(game.menus._crafts_text().contains("Feinschmieden 0"), "the character page shows the crafts")
	game.menus.close()

	# Kept in the saved game.
	check(game.save_game(), "the game is saved")
	var saved: Dictionary = game.crafting.for_save()
	game.crafting.clear()
	game._apply_save(game._read_save(game.save_path(HERO)))
	check(game.crafting.for_save() == saved, "the saved game brings recipes and pouch back")
	var data: Dictionary = game._read_save(game.save_path(HERO))
	data.erase("crafting")
	game._apply_save(data)
	check(game.crafting.entries().is_empty(), "an older saved game starts without recipes")
	game.crafting.load_from({"known": {"mondsilberring": {"read": ["gemuet", "nonsense"]}, "unknown": {}},
			"pouch": {"mondstein": 2, "sand": 4, "mondsilbererz": -1}})
	check(game.crafting.entries() == ["mondsilberring"], "unknown recipes are left out")
	check(game.crafting.known.mondsilberring.read == ["gemuet"], "unknown lines are left out")
	check(game.crafting.pouch == {"mondstein": 2}, "unknown or empty ingredients are left out")

	# A new recipe page falls back when there are no recipes.
	game.crafting.clear()
	game.menus.compendium_page = "rezepte"
	game.menus.open("kompendium")
	check(game.menus.compendium_page == "wissen", "without recipes the compendium shows what was learned")
	game.menus.close()
