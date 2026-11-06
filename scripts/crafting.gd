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

## Everything that goes into a recipe, as the ingredient book shows it:
## "region" where it is found, "when" the condition under which it can be
## had ("" for any time), "source" what yields it (a vein, a plant, a
## creature's loot, a quest), and "where" a sentence on how to find it.
## The book lists an ingredient once a known recipe names it; its place is
## marked as found once the hero gathered it there.
const INGREDIENTS := {
	"mondsilbererz": {"name": "Mondsilbererz", "region": "Wildnis", "when": "nur nachts", "source": "Erzader",
		"where": "Eine Ader in der Wildnis, die nur bei Nacht schimmert."},
	"mondstein": {"name": "Mondstein", "region": "Verlies", "when": "", "source": "Beute der Knochenmagier",
		"where": "Knochenmagier im Verlies hüten ihn."},
	# Hidden in the ground: only the hero's fox sniffs them out (see Pet).
	# "fox" weighs how often the fox finds one: rarer ones less often.
	"baerlauch": {"name": "Bärlauch", "region": "Wildnis", "when": "", "source": "Dein Fuchs", "fox": 6,
		"where": "Wächst versteckt auf den Wiesen. Nur ein Fuchs erschnüffelt ihn."},
	"steinpilz": {"name": "Steinpilz", "region": "Wildnis", "when": "", "source": "Dein Fuchs", "fox": 4,
		"where": "Steckt im Gras der Wiesen. Nur ein Fuchs erschnüffelt ihn."},
	"trueffel": {"name": "Trüffel", "region": "Wildnis", "when": "", "source": "Dein Fuchs", "fox": 1,
		"where": "Selten und tief in der Erde der Wiesen. Nur ein Fuchs erschnüffelt sie."},
	"hoehlenpilz": {"name": "Höhlenpilz", "region": "Verlies", "when": "", "source": "Dein Fuchs", "fox": 4,
		"where": "Wächst unter dem Staub der Verliesböden. Nur ein Fuchs erschnüffelt ihn."},
	"glimmermoos": {"name": "Glimmermoos", "region": "Verlies", "when": "", "source": "Dein Fuchs", "fox": 2,
		"where": "Leuchtet schwach unter den Steinen des Verlieses. Nur ein Fuchs erschnüffelt es."},
	# Fish, caught with the line (see Fishing). The perch bites everywhere;
	# the other three are rare and bite in one water only.
	"barsch": {"name": "Barsch", "region": "Dorf und Wolfssenke", "when": "", "source": "Angeln in den Teichen",
		"where": "Beißt im Dorfteich und im Tümpel der Wolfssenke."},
	"goldkarpfen": {"name": "Goldkarpfen", "rare": true, "region": "Dorf", "when": "", "source": "Angeln im Brunnen",
		"where": "Ein seltener Fang im Brunnen auf dem Dorfplatz."},
	"silberhecht": {"name": "Silberhecht", "rare": true, "region": "Dorf", "when": "in der Dämmerung", "source": "Angeln im Dorfteich",
		"where": "Beißt im Dorfteich, aber nur in der Dämmerung."},
	"mondforelle": {"name": "Mondforelle", "rare": true, "region": "Wolfssenke", "when": "nur nachts", "source": "Angeln im Tümpel",
		"where": "Beißt im Tümpel der Wolfssenke, aber nur bei Nacht."},
	# Opens only on full-moon nights beside the hollow's pond (see Moon).
	"mondblume": {"name": "Mondblume", "rare": true, "region": "Wolfssenke", "when": "nur bei Vollmond", "source": "Blüte am Tümpel",
		"where": "Öffnet sich nur in Vollmondnächten am Tümpel der Wolfssenke, wo dann das Wolfsrudel jagt."},
}
## The smith's iron bars in the ingredient book.
const IRON := {"name": "Eisenbarren", "region": "Dorf", "when": "", "source": "Schmied Gorm",
	"where": "Gorm verkauft Eisenbarren und schmilzt Metall aus deiner Tasche zu neuen ein."}

## The recipes. "giver" is the villager who hands out the scroll, "craft" and
## "craft_level" the craft it needs, "ingredients" what goes in (ingredient
## id or "eisen" for the smith's iron bars -> count). "lines" is the scroll:
## each has its text; a "hidden" line shows "faded" until it is read. A
## faded line with a "fish" is read the first time that fish is caught.
## A recipe with an empty "giver" is not handed out by running into someone:
## it is the reward of a wish (see Wishes), and "effect" says what the made
## piece will do. A recipe with a "result" (an item in Items.ALL) can be made
## at the bench of its craft on the crafting square (see make); one without
## is not complete yet.
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
	"tiefenamulett": {"name": "Amulett der Tiefe", "giver": "9",
		"craft": "feinschmieden", "craft_level": 2,
		"ingredients": {"mondforelle": 1, "goldkarpfen": 1, "silberhecht": 1, "barsch": 3},
		"offer": "Mein Großvater angelte, wo immer es Wasser gab. Er hinterließ dieses Rezept für ein Amulett aus Fischschuppen; eine Zeile ist verwischt. Wirf die Angel aus (Taste G): im Brunnen, im Dorfteich und im Tümpel der Wolfssenke.",
		"lines": [
			{"id": "forelle", "text": "Die Schuppen einer Mondforelle, die nur nachts in der Wolfssenke beißt."},
			{"id": "karpfen", "text": "Die goldenen Schuppen eines Karpfens aus dem Dorfbrunnen."},
			{"id": "hecht", "hidden": true, "fish": "silberhecht", "faded": "Ein … Hecht, wenn …",
				"text": "Ein Silberhecht aus dem Dorfteich, wenn der Tag kommt oder geht."},
			{"id": "barsch", "text": "Drei Barsche: aus ihrer Haut kocht man den Leim, der die Schuppen hält."},
			{"id": "hand", "text": "Eine geübte Hand: Feinschmieden, Stufe 2."},
		]},
	# The rewards of the wishes Guild Master Ragna helps with (see Wishes).
	"klingenring": {"name": "Klingenring", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "klingenring",
		"effect": "Klingen +1",
		"ingredients": {"mondsilbererz": 1, "glimmermoos": 1, "eisen": 2},
		"lines": [
			{"id": "erz", "text": "Ein Brocken Mondsilber für den Reif."},
			{"id": "moos", "text": "Glimmermoos aus dem Verlies, um ihn blank zu reiben."},
			{"id": "eisen", "text": "Zwei Barren Eisen, damit er die Hand fest hält."},
		]},
	"axtreif": {"name": "Armreif der Axt", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "axtreif",
		"effect": "Äxte +1",
		"ingredients": {"hoehlenpilz": 2, "eisen": 3},
		"lines": [
			{"id": "eisen", "text": "Drei Barren Eisen, schwer wie ein Axtkopf."},
			{"id": "pilz", "text": "Die Asche zweier Höhlenpilze, um das Eisen zu härten."},
		]},
	"schildamulett": {"name": "Amulett des Walls", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "schildamulett",
		"effect": "Blocken +1",
		"ingredients": {"mondstein": 1, "barsch": 2, "eisen": 2},
		"lines": [
			{"id": "stein", "text": "Ein Mondstein als Mitte, rund wie ein Schild."},
			{"id": "leim", "text": "Leim aus der Haut zweier Barsche, der ihn hält."},
			{"id": "eisen", "text": "Zwei Barren Eisen für die Fassung."},
		]},
	"wurfring": {"name": "Wurfring", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "wurfring",
		"effect": "Messerwurf +1",
		"ingredients": {"silberhecht": 1, "mondsilbererz": 1, "eisen": 1},
		"lines": [
			{"id": "hecht", "text": "Die Schuppen eines Silberhechts, glatt wie eine Klinge im Flug."},
			{"id": "erz", "text": "Ein Brocken Mondsilber für den Reif."},
			{"id": "eisen", "text": "Ein Barren Eisen, damit er nicht verrutscht."},
		]},
	"schattenamulett": {"name": "Amulett der stillen Schritte", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "schattenamulett",
		"effect": "Schleichen +1",
		"ingredients": {"mondforelle": 1, "glimmermoos": 2, "mondsilbererz": 1},
		"lines": [
			{"id": "forelle", "text": "Die Schuppen einer Mondforelle, die nachts lautlos schwimmt."},
			{"id": "moos", "text": "Zwei Büschel Glimmermoos, das jeden Klang schluckt."},
			{"id": "erz", "text": "Ein Brocken Mondsilber für die Fassung."},
		]},
	"lastreif": {"name": "Armreif der leichten Last", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "lastreif",
		"effect": "Rüstung tragen +1",
		"ingredients": {"goldkarpfen": 1, "baerlauch": 2, "eisen": 2},
		"lines": [
			{"id": "karpfen", "text": "Die goldenen Schuppen eines Karpfens aus dem Dorfbrunnen."},
			{"id": "lauch", "text": "Zwei Bund Bärlauch, um das Eisen geschmeidig zu kochen."},
			{"id": "eisen", "text": "Zwei Barren Eisen für den Reif."},
		]},
}

## Explained once in the compendium, when the first recipe is found.
const HOW_TO := "Rezepte stehen im Kompendium (Taste H) im „Rezeptbuch“: was hineingehört, welches Handwerk es braucht, und verblasste Zeilen (…), die du noch herausfinden musst. Darunter stehen die Zutaten: wo und wann man sie findet und woher sie kommen. Zutaten kommen in deinen Zutatenbeutel, nicht in die Tasche."

var game: Node
## Known recipes: recipe id -> {"read": [ids of faded lines already read]}.
var known := {}
## The ingredient pouch: ingredient id -> count.
var pouch := {}
## Ingredients the hero gathered at least once: their place is marked as
## found in the ingredient book.
var found := []


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	known.clear()
	pouch.clear()
	found.clear()


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


## Puts ingredients into the pouch. found_here: the hero gathered them where
## they stand (not, say, as a reward), so the spot goes on their map (see
## Journal.note_find).
func add(ingredient: String, count := 1, found_here := true) -> void:
	if ingredient == "eisen":
		game.iron += count
	elif INGREDIENTS.has(ingredient):
		pouch[ingredient] = have(ingredient) + count
		if not found.has(ingredient):
			found.append(ingredient)
		if found_here and game != null and game.level != null and game.player != null:
			# Fish (caught with the line) get a mark of their own colour.
			var kind := "fish" if str(INGREDIENTS[ingredient].source).begins_with("Angeln") else "ingredient"
			game.note_find(kind, ingredient, INGREDIENTS[ingredient].name, game.player.global_position)


## Whether every ingredient of a recipe is in the pouch.
func has_ingredients(id: String) -> bool:
	var needs: Dictionary = RECIPES[id].ingredients
	for ingredient in needs:
		if have(ingredient) < int(needs[ingredient]):
			return false
	return true


## An ingredient hidden in the ground for the hero's fox to dig up (see
## Pet), in the open air ("Wildnis") or in the dungeon ("Verlies").
static func random_fox_find(rng: RandomNumberGenerator, outdoors: bool) -> String:
	var region := "Wildnis" if outdoors else "Verlies"
	var ids := INGREDIENTS.keys().filter(func(id): return INGREDIENTS[id].has("fox") and INGREDIENTS[id].region == region)
	var total := 0
	for id in ids:
		total += int(INGREDIENTS[id].fox)
	var roll := rng.randi_range(1, total)
	for id in ids:
		roll -= int(INGREDIENTS[id].fox)
		if roll <= 0:
			return id
	return ids[-1]
## A fish was caught: faded lines that name it can be read now. Returns the
## recipes whose scroll became clearer.
func caught_fish(fish: String) -> Array:
	var clearer := []
	for id in entries():
		for line in RECIPES[id].lines:
			if line.get("fish", "") == fish and read_line(id, line.id):
				clearer.append(id)
	return clearer


static func ingredient_name(ingredient: String) -> String:
	if ingredient == "eisen":
		return Lang.t("Eisenbarren")
	return Lang.t(INGREDIENTS[ingredient].name) if INGREDIENTS.has(ingredient) else ingredient


## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return {"known": known.duplicate(true), "pouch": pouch.duplicate(), "found": found.duplicate()}


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
	var saved_found = saved.get("found", [])
	if saved_found is Array:
		for ingredient in saved_found:
			if INGREDIENTS.has(str(ingredient)) and not found.has(str(ingredient)):
				found.append(str(ingredient))


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
	Events.teach(HOW_TO)
	Events.tell(Lang.t("Neues Rezept: %s") % Lang.t(RECIPES[id].name) + "\n" + Lang.t("Steht im Kompendium (H) im „Rezeptbuch“."), Color(0.75, 0.85, 1.0))
	return true


# --- Making ---------------------------------------------------------------------

## Training a craft gets each time the hero makes something with it.
const CRAFT_XP := 10.0


## The hero's level in a craft.
func craft_level(craft: String) -> int:
	if game == null or game.player == null:
		return 0
	return Training.skill_level(float(game.player.xp.get(craft, 0.0)), craft)


## The known recipes of a craft, in the order of RECIPES: what its bench lists.
func recipes_for(craft: String) -> Array:
	return entries().filter(func(id): return RECIPES[id].craft == craft)


## Why a recipe cannot be made right now, or "" when it can.
func why_not(id: String) -> String:
	var r: Dictionary = RECIPES[id]
	if not knows(id):
		return Lang.t("Dieses Rezept kennst du nicht.")
	if not r.has("result"):
		return Lang.t("Das Rezept ist noch nicht vollständig.")
	if craft_level(r.craft) < int(r.craft_level):
		return Lang.t("Dafür brauchst du %s Stufe %d.") % [Lang.t(Training.CRAFTS[r.craft].name), r.craft_level]
	var missing := []
	for ingredient in r.ingredients:
		var short := int(r.ingredients[ingredient]) - have(ingredient)
		if short > 0:
			missing.append("%d %s" % [short, ingredient_name(ingredient)])
	if not missing.is_empty():
		return Lang.t("Es fehlt: %s") % ", ".join(missing)
	return ""


## Makes a recipe: takes its ingredients, puts the piece into the bag (or
## the storage chest when the bag is full) and trains the craft. Returns ""
## on success, else why not.
func make(id: String) -> String:
	if not RECIPES.has(id):
		return Lang.t("Dieses Rezept kennst du nicht.")
	var why := why_not(id)
	if why != "":
		return why
	var r: Dictionary = RECIPES[id]
	for ingredient in r.ingredients:
		var count := int(r.ingredients[ingredient])
		if ingredient == "eisen":
			game.iron -= count
		else:
			pouch[ingredient] = have(ingredient) - count
			if pouch[ingredient] <= 0:
				pouch.erase(ingredient)
	var p: Player = game.player
	if p.bag.size() < p.bag_size():
		p.bag.append(r.result)
	else:
		game.storage.append(r.result)
	p.train(r.craft, CRAFT_XP, false)
	return ""


# --- Compendium -----------------------------------------------------------------

## The recipes for the compendium, in the order they are listed in RECIPES.
func entries() -> Array:
	return RECIPES.keys().filter(func(id): return knows(id))


## A recipe as the compendium shows it: its scroll lines (faded ones as their
## fragment), then what the hero has of each ingredient and the craft.
func describe(id: String) -> String:
	var r: Dictionary = RECIPES[id]
	var lines := []
	if r.has("effect"):
		lines.append(Lang.t("Wirkung: %s") % Lang.t(r.effect))
	for line in r.lines:
		lines.append(Lang.t("„%s“") % Lang.t(line.text if line_read(id, line) else line.faded))
	var parts := []
	for ingredient in r.ingredients:
		parts.append("%s %d / %d" % [ingredient_name(ingredient), mini(have(ingredient), r.ingredients[ingredient]), r.ingredients[ingredient]])
	lines.append(Lang.t("Zutaten: %s") % ", ".join(parts))
	var craft_level := Training.skill_level(game.player.xp.get(r.craft, 0.0), r.craft) if game else 0
	lines.append(Lang.t("Handwerk: %s %d / %d") % [Lang.t(Training.CRAFTS[r.craft].name), craft_level, r.craft_level])
	return "\n".join(lines)


## The ingredients for the ingredient book: every one a known recipe names,
## in the order the recipes name them, and anything else in the pouch.
func book_ingredients() -> Array:
	var ids := []
	for id in entries():
		for ingredient in RECIPES[id].ingredients:
			if not ids.has(ingredient):
				ids.append(ingredient)
	for ingredient in pouch:
		if not ids.has(ingredient):
			ids.append(ingredient)
	return ids


## An ingredient as the ingredient book shows it: how many are in the
## pouch, where and when it is found and what yields it, how to find it,
## and whether the hero found the place yet.
func describe_ingredient(ingredient: String) -> String:
	var info: Dictionary = IRON if ingredient == "eisen" else INGREDIENTS[ingredient]
	var place := Lang.t("Ort: %s") % Lang.t(info.region)
	if info.when != "":
		place += "  ·  " + Lang.t("Zeit: %s") % Lang.t(info.when)
	place += "  ·  " + Lang.t("Quelle: %s") % Lang.t(info.source)
	var lines := ["%s  (%s)" % [ingredient_name(ingredient), Lang.t("%d dabei") % have(ingredient)], place, Lang.t(info.where)]
	if ingredient != "eisen":
		lines.append(Lang.t("Fundort entdeckt.") if found.has(ingredient) else Lang.t("Fundort noch nicht selbst entdeckt."))
	return "\n".join(lines)
