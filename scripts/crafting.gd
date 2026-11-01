class_name Crafting
extends RefCounted
## Recipes, ingredients and the crafts, the loop of making something special:
## find a recipe, gather its ingredients from all over the world, learn and
## train the craft it needs, find out how the parts go together, and meet
## the higher influences (a calm mind, a deity's favour, the order of the
## stars) that finish the piece.
##
## A recipe is an old scroll. Its lines name the ingredients and the craft;
## some lines are faded ("hidden") and show only a fragment until the hero
## finds out what they say. Known recipes, which faded lines are read, and
## the ingredient pouch are kept in the saved game, like the quests.
## Ingredients go into the pouch, not the bag, and are counted like iron.
## How well the hero handles a craft is trained like a skill (Training.CRAFTS)
## and stays with the hero's name.

## Everything that goes into a recipe. "where" tells the compendium where
## to look for it.
const INGREDIENTS := {
	"mondsilbererz": {"name": "Mondsilbererz",
		"where": "Eine Ader in der Wildnis, die nur bei Nacht schimmert."},
	"mondstein": {"name": "Mondstein",
		"where": "Knochenmagier im Verlies hüten ihn."},
}

## The recipes. "giver" is the villager who hands out the scroll, "craft" and
## "craft_level" the craft it needs, "ingredients" what goes in (ingredient
## id or "eisen" for the smith's iron bars -> count). "lines" is the scroll:
## each has its text; a "hidden" line shows "faded" until it is read.
const RECIPES := {
	"mondsilberring": {"name": "Mondsilberring", "giver": "8",
		"craft": "feinschmieden", "craft_level": 3,
		"ingredients": {"mondsilbererz": 2, "mondstein": 1, "eisen": 1},
		"offer": "Diese Schriftrolle fand ich zwischen alten Büchern: ein Rezept für einen Ring aus Mondsilber. Die Hälfte ist verblasst. Nimm sie, vielleicht findest du heraus, was dort stand.",
		"lines": [
			{"id": "erz", "text": "Zwei Brocken Mondsilber, die nur bei Nacht schimmern."},
			{"id": "stein", "text": "Ein Mondstein, wie ihn die Knochenmagier hüten."},
			{"id": "eisen", "text": "Ein Barren Eisen für den Reif."},
			{"id": "hand", "text": "Eine geübte Hand: Feinschmieden, Stufe 3."},
			{"id": "gemuet", "hidden": true, "faded": "Ein stilles … ohne …",
				"text": "Ein stilles Gemüt: ausgeruht und ohne Kampf im Herzen."},
			{"id": "goettin", "hidden": true, "faded": "… die Gunst der …",
				"text": "Die Gunst der Mondgöttin, erbeten im Tempel."},
			{"id": "sterne", "hidden": true, "faded": "Wenn der … am Himmel …",
				"text": "Wenn der Silberne Hirsch am Himmel steht."},
		]},
}

## Explained once in the compendium, when the first recipe is found.
const HOW_TO := "Rezepte stehen im Kompendium (Taste H) unter „Rezepte“: was hineingehört, welches Handwerk es braucht, und verblasste Zeilen (…), die du noch herausfinden musst. Zutaten kommen in deinen Zutatenbeutel, nicht in die Tasche."

var game: Node
## Known recipes: recipe id -> {"read": [ids of faded lines already read]}.
var known := {}
## The ingredient pouch: ingredient id -> count.
var pouch := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	known.clear()
	pouch.clear()


func knows(id: String) -> bool:
	return known.has(id)


## Hands the hero a recipe. False if it was known already.
func learn_recipe(id: String) -> bool:
	if knows(id) or not RECIPES.has(id):
		return false
	known[id] = {"read": []}
	return true


## Whether a line of a recipe can be read: plain lines always, faded lines
## once the hero found out what they say.
func line_read(id: String, line: Dictionary) -> bool:
	return not line.get("hidden", false) or known.get(id, {}).get("read", []).has(line.id)


## The hero found out what a faded line says. False if it was read already.
func read_line(id: String, line_id: String) -> bool:
	if not knows(id):
		return false
	var read: Array = known[id].read
	if read.has(line_id):
		return false
	read.append(line_id)
	return true


## How many of an ingredient the hero has; "eisen" is the smith's iron bars.
func have(ingredient: String) -> int:
	if ingredient == "eisen":
		return game.iron if game else 0
	return int(pouch.get(ingredient, 0))


func add(ingredient: String, count := 1) -> void:
	if ingredient == "eisen":
		game.iron += count
	elif INGREDIENTS.has(ingredient):
		pouch[ingredient] = have(ingredient) + count


## Whether every ingredient of a recipe is in the pouch.
func has_ingredients(id: String) -> bool:
	var needs: Dictionary = RECIPES[id].ingredients
	for ingredient in needs:
		if have(ingredient) < int(needs[ingredient]):
			return false
	return true


static func ingredient_name(ingredient: String) -> String:
	if ingredient == "eisen":
		return Lang.t("Eisenbarren")
	return Lang.t(INGREDIENTS[ingredient].name) if INGREDIENTS.has(ingredient) else ingredient


## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return {"known": known.duplicate(true), "pouch": pouch.duplicate()}


## Back from the saved game; unknown recipes, ingredients and lines are left
## out, and older saved games start with none.
func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	var saved_known = saved.get("known", {})
	if saved_known is Dictionary:
		for id in saved_known:
			if not RECIPES.has(str(id)):
				continue
			var lines := []
			for line in RECIPES[str(id)].lines:
				lines.append(line.id)
			var read := []
			var entry = saved_known[id]
			if entry is Dictionary and entry.get("read", []) is Array:
				for line_id in entry.read:
					if lines.has(str(line_id)) and not read.has(str(line_id)):
						read.append(str(line_id))
			known[str(id)] = {"read": read}
	var saved_pouch = saved.get("pouch", {})
	if saved_pouch is Dictionary:
		for ingredient in saved_pouch:
			var count := int(saved_pouch[ingredient])
			if INGREDIENTS.has(str(ingredient)) and count > 0:
				pouch[str(ingredient)] = count


# --- Villagers ------------------------------------------------------------------

## The recipe a villager has for the hero right now, or "".
func offer_of(role: String) -> String:
	for id in RECIPES:
		if RECIPES[id].giver == role and not knows(id):
			return id
	return ""


## "!" over a villager who has a recipe for the hero, else "".
func mark(role: String) -> String:
	return "!" if offer_of(role) != "" else ""


## The hero ran into a villager: one with a recipe hands it over and this
## returns true; otherwise false.
func talk(v: Villager) -> bool:
	var id := offer_of(v.role)
	if id == "":
		return false
	learn_recipe(id)
	v.meet()
	v.say(Lang.t(RECIPES[id].offer), game.player.global_position, 6.5)
	game.learn(HOW_TO)
	game.quest_news(Lang.t("Neues Rezept: %s") % Lang.t(RECIPES[id].name) + "\n" + Lang.t("Steht im Kompendium (H) unter „Rezepte“."), Color(0.75, 0.85, 1.0))
	return true


# --- Compendium -----------------------------------------------------------------

## The recipes for the compendium, in the order they are listed in RECIPES.
func entries() -> Array:
	return RECIPES.keys().filter(func(id): return knows(id))


## A recipe as the compendium shows it: its scroll lines (faded ones as their
## fragment), then what the hero has of each ingredient and the craft.
func describe(id: String) -> String:
	var r: Dictionary = RECIPES[id]
	var lines := []
	for line in r.lines:
		lines.append(Lang.t("„%s“") % Lang.t(line.text if line_read(id, line) else line.faded))
	var parts := []
	for ingredient in r.ingredients:
		parts.append("%s %d / %d" % [ingredient_name(ingredient), mini(have(ingredient), r.ingredients[ingredient]), r.ingredients[ingredient]])
	lines.append(Lang.t("Zutaten: %s") % ", ".join(parts))
	var craft_level := Training.skill_level(game.player.xp.get(r.craft, 0.0), r.craft) if game else 0
	lines.append(Lang.t("Handwerk: %s %d / %d") % [Lang.t(Training.CRAFTS[r.craft].name), craft_level, r.craft_level])
	return "\n".join(lines)


## The ingredient pouch in words, for the compendium.
func pouch_text() -> String:
	var parts := []
	for ingredient in INGREDIENTS:
		if have(ingredient) > 0:
			parts.append("%s %d" % [ingredient_name(ingredient), have(ingredient)])
	if parts.is_empty():
		return Lang.t("Dein Zutatenbeutel ist leer.")
	return Lang.t("Im Zutatenbeutel: %s") % ", ".join(parts)
