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
	"baerlauch": {"name": "Bärlauch", "tier": "ungewoehnlich", "region": "Wildnis", "when": "", "source": "Dein Fuchs", "fox": 6,
		"where": "Wächst versteckt auf den Wiesen. Nur ein Fuchs erschnüffelt ihn."},
	"steinpilz": {"name": "Steinpilz", "tier": "ungewoehnlich", "region": "Wildnis", "when": "", "source": "Dein Fuchs", "fox": 4,
		"where": "Steckt im Gras der Wiesen. Nur ein Fuchs erschnüffelt ihn."},
	"trueffel": {"name": "Trüffel", "tier": "ungewoehnlich", "region": "Wildnis", "when": "", "source": "Dein Fuchs", "fox": 1,
		"where": "Selten und tief in der Erde der Wiesen. Nur ein Fuchs erschnüffelt sie."},
	"hoehlenpilz": {"name": "Höhlenpilz", "tier": "ungewoehnlich", "region": "Verlies", "when": "", "source": "Dein Fuchs", "fox": 4,
		"where": "Wächst unter dem Staub der Verliesböden. Nur ein Fuchs erschnüffelt ihn."},
	"glimmermoos": {"name": "Glimmermoos", "tier": "ungewoehnlich", "region": "Verlies", "when": "", "source": "Dein Fuchs", "fox": 2,
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
	# Mined from the crystal clusters of the mines (see Mines).
	"grottenkristall": {"name": "Grottenkristall", "tier": "ungewoehnlich", "region": "Kristallgrotte", "when": "", "source": "Kristallbüschel abbauen",
		"where": "Wächst in leuchtenden Büscheln in der Kristallgrotte, der zweiten Mine. Lauf dagegen, um zwei abzuschlagen; bis zum nächsten Morgen wächst das Büschel nach."},
	# Left by Embermaw when it falls, deep in its lair (see DragonLair).
	"drachenschuppe": {"name": "Drachenschuppe", "rare": true, "region": "Drachenhöhle", "when": "", "source": "Beute des Drachen",
		"where": "Glutschlund verliert eine, wenn er fällt, ganz unten in der Drachenhöhle."},
	"drachenblut": {"name": "Drachenblut", "rare": true, "region": "Drachenhöhle", "when": "", "source": "Beute des Drachen",
		"where": "Rinnt aus Glutschlund, wenn er fällt, ganz unten in der Drachenhöhle."},
	"glutherz": {"name": "Glutherz", "rare": true, "region": "Drachenhöhle", "when": "", "source": "Beute des Drachen, nicht immer",
		"where": "Das glühende Herz des Drachen. Nicht jedes Mal, wenn Glutschlund fällt, bleibt es heil."},
	# The loot of fallen monsters (see Loot), each with its "tier" (see
	# Rarity); "store": "metall" marks what a house keeps with the metal. Coins, from every intelligent foe: a hundred of one metal melt
	# into a bar of it at Gorm's forge.
	"eisenmuenze": {"name": "Eisenmünze", "store": "metall", "tier": "normal", "region": "Überall", "when": "", "source": "Beute kluger Gegner",
		"where": "Jeder kluge Gegner trägt ein paar bei sich: Skelette, Banditen, Orks, Trolle und Drachen. Gorm schmilzt hundert davon zu einem Eisenbarren ein."},
	"silbermuenze": {"name": "Silbermünze", "store": "metall", "tier": "ungewoehnlich", "region": "Überall", "when": "", "source": "Beute kluger Gegner",
		"where": "Nur zähe kluge Gegner tragen sie öfter. Gorm schmilzt hundert davon zu einem Silberbarren ein."},
	"goldmuenze": {"name": "Goldmünze", "store": "metall", "tier": "selten", "region": "Überall", "when": "", "source": "Beute seltener Gegner und Bosse",
		"where": "Nur seltene Gegner und Bosse ab Stufe 25 tragen ein bis drei davon, frisch geprägt, nicht wie die uralten. Gorm schmilzt hundert davon zu einem Goldbarren ein."},
	# Food (common), from the beasts.
	"wildfleisch": {"name": "Wildfleisch", "tier": "normal", "region": "Wildnis", "when": "", "source": "Beute wilder Tiere",
		"where": "Wölfe, Yetis und Fledermäuse lassen manchmal ein Stück zurück."},
	"spinnenei": {"name": "Spinnenei", "tier": "normal", "region": "Wildnis", "when": "", "source": "Beute der Spinnen",
		"where": "Spinnen tragen sie unter dem Leib. Manchmal bleibt eines heil, wenn eine fällt."},
	"schleimgelee": {"name": "Schleimgelee", "tier": "normal", "region": "Verlies", "when": "", "source": "Beute der Schleime",
		"where": "Ein zäher, essbarer Klumpen, den manchmal ein Schleim zurücklässt."},
	# Of the mountains (uncommon), like the other ingredients a beast leaves
	# from where it lives.
	"edelweiss": {"name": "Edelweiß", "tier": "ungewoehnlich", "region": "Gebirge", "when": "", "source": "Beute der Bergtiere",
		"where": "Hängt im Fell der Eiswölfe und Yetis, die hoch oben streifen."},
	# Parts of a creature (rare): a trophy, or something for a craft.
	"wolfsfell": {"name": "Wolfsfell", "tier": "selten", "region": "Wildnis", "when": "", "source": "Beute der Wölfe",
		"where": "Selten bleibt ein Fell heil, wenn ein Wolf oder Eiswolf fällt. Eine Trophäe, oder etwas für ein Handwerk."},
	"giftdruese": {"name": "Giftdrüse", "tier": "selten", "region": "Wildnis", "when": "", "source": "Beute der Spinnen",
		"where": "Selten bleibt sie heil, wenn eine Spinne fällt. Eine Trophäe, oder etwas für ein Handwerk."},
	"yetifell": {"name": "Yetifell", "tier": "selten", "region": "Wildnis", "when": "", "source": "Beute der Yetis",
		"where": "Selten bleibt ein Fell heil, wenn ein Yeti fällt. Eine Trophäe, oder etwas für ein Handwerk."},
	"fledermausfluegel": {"name": "Fledermausflügel", "tier": "selten", "region": "Drachenhöhle", "when": "", "source": "Beute der Fledermäuse",
		"where": "Selten bleibt ein Flügel heil, wenn eine Fledermaus fällt. Eine Trophäe, oder etwas für ein Handwerk."},
	"schleimkern": {"name": "Schleimkern", "tier": "selten", "region": "Verlies", "when": "", "source": "Beute der Schleime",
		"where": "Der harte Kern eines Schleims, selten heil. Eine Trophäe, oder etwas für ein Handwerk."},
	# Raw ore from trolls and the beasts of the mountains (see Ore): each
	# lump has its own weight and make-up, kept in `ores`.
	"erzbrocken_klein": {"name": "Kleiner Erzbrocken", "store": "metall", "tier": "normal", "region": "Gebirge", "when": "", "source": "Beute der Trolle und Bergwesen",
		"where": "Trolle und die Wesen der Berge tragen Erz bei sich. Gorm schmilzt es ein: Was an Metall darin steckt, bekommst du grammgenau."},
	"erzbrocken": {"name": "Erzbrocken", "store": "metall", "tier": "ungewoehnlich", "region": "Gebirge", "when": "", "source": "Beute der Trolle und Bergwesen",
		"where": "Ein bis zwei Kilo Gestein mit Eisen, Kupfer, Silber, etwas Gold und manchmal einem unbekannten, hellblau schimmernden Metall."},
	"erzbrocken_gross": {"name": "Großer Erzbrocken", "store": "metall", "tier": "selten", "region": "Gebirge", "when": "", "source": "Beute der Trolle und Bergwesen",
		"where": "Ein schwerer Brocken von zweieinhalb bis fünf Kilo. Je tausend Gramm eines Metalls schmiedet Gorm zu einem Barren."},
	"erzbrocken_episch": {"name": "Edelerz", "store": "metall", "tier": "episch", "region": "Gebirge", "when": "", "source": "Beute der Trolle und Bergwesen",
		"where": "Ein sehr seltener Brocken, reich an Silber und Gold, mit ein bis fünf ungeschliffenen Edelsteinen darin."},
	# Gems from noble ore (see Ore.GEMS): each with its own weight in carat,
	# which sets its rarity. Gorm cuts them; cutting takes off some weight.
	"rohedelstein": {"name": "Ungeschliffener Edelstein", "store": "metall", "tier": "ungewoehnlich", "region": "Gebirge", "when": "", "source": "Aus Edelerz geschmolzen",
		"where": "Steckt in Edelerz. Erst geschliffen taugt er zu etwas; Gorm schleift ihn, dabei verliert er 15 bis 50 Prozent seines Gewichts."},
	"edelstein": {"name": "Geschliffener Edelstein", "store": "metall", "tier": "selten", "region": "Dorf", "when": "", "source": "Schmied Gorm",
		"where": "Ein Edelstein, von Gorm geschliffen. Je mehr Karat, desto seltener und wertvoller; Gorm kauft ihn dir ab."},
}
## The smith's iron bars in the ingredient book.
const IRON := {"name": "Eisenbarren", "region": "Dorf", "when": "", "source": "Schmied Gorm",
	"where": "Gorm verkauft Eisenbarren und schmilzt Metall aus deiner Tasche zu neuen ein."}
## The fine bars from Gorm's forge (Forge.FINE, kept in game.bars) in the
## ingredient book: a recipe names them by their metal, e.g. "silber".
const FINE_BARS := {"region": "Dorf", "when": "", "source": "Schmied Gorm",
	"where": "Gorm schmilzt Schmuck und feine Waffen und Rüstungen an seiner Esse zu Barren ein."}

## The recipes. "giver" is the villager who hands out the scroll, "craft" and
## "craft_level" the craft it needs, "ingredients" what goes in (ingredient
## id or "eisen" for the smith's iron bars -> count). "lines" is the scroll:
## each has its text; a "hidden" line shows "faded" until it is read. A
## faded line with a "fish" is read the first time that fish is caught.
## A recipe with an empty "giver" is not handed out by running into someone:
## it is the reward of a wish (see Wishes), and "effect" says what the made
## piece will do. A recipe with "found" is learned the first time the hero
## gathers that ingredient (see learn_from_find). "bench" is the bench it is
## made at when that is not the one of its craft. A recipe with a "result" (an item in Items.ALL) can be made
## at the bench of its craft on the crafting square (see make); one without
## is not complete yet.
const RECIPES := {
	"mondsilberring": {"name": "Mondsilberring", "giver": "8",
		"craft": "feinschmieden", "craft_level": 3,
		"ingredients": {"mondsilbererz": 2, "mondstein": 1, "eisen": 2},
		"offer": "Diese Schriftrolle fand ich zwischen alten Büchern: ein Rezept für einen Ring aus Mondsilber. Die Hälfte ist verblasst. Nimm sie, vielleicht findest du heraus, was dort stand.",
		"lines": [
			{"id": "erz", "text": "Zwei Brocken Mondsilber, die nur bei Nacht schimmern."},
			{"id": "stein", "text": "Ein Mondstein, wie ihn die Knochenmagier hüten."},
			{"id": "eisen", "text": "Zwei Barren Eisen für den Reif."},
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
		"ingredients": {"mondsilbererz": 1, "glimmermoos": 1, "eisen": 4},
		"lines": [
			{"id": "erz", "text": "Ein Brocken Mondsilber für den Reif."},
			{"id": "moos", "text": "Glimmermoos aus dem Verlies, um ihn blank zu reiben."},
			{"id": "eisen", "text": "Vier Barren Eisen, damit er die Hand fest hält."},
		]},
	"axtreif": {"name": "Armreif der Axt", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "axtreif",
		"effect": "Äxte +1",
		"ingredients": {"hoehlenpilz": 2, "eisen": 6},
		"lines": [
			{"id": "eisen", "text": "Sechs Barren Eisen, schwer wie ein Axtkopf."},
			{"id": "pilz", "text": "Die Asche zweier Höhlenpilze, um das Eisen zu härten."},
		]},
	"schildamulett": {"name": "Amulett des Walls", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "schildamulett",
		"effect": "Blocken +1",
		"ingredients": {"mondstein": 1, "barsch": 2, "eisen": 4},
		"lines": [
			{"id": "stein", "text": "Ein Mondstein als Mitte, rund wie ein Schild."},
			{"id": "leim", "text": "Leim aus der Haut zweier Barsche, der ihn hält."},
			{"id": "eisen", "text": "Vier Barren Eisen für die Fassung."},
		]},
	"wurfring": {"name": "Wurfring", "giver": "", "craft": "feinschmieden", "craft_level": 0, "result": "wurfring",
		"effect": "Messerwurf +1",
		"ingredients": {"silberhecht": 1, "mondsilbererz": 1, "eisen": 2},
		"lines": [
			{"id": "hecht", "text": "Die Schuppen eines Silberhechts, glatt wie eine Klinge im Flug."},
			{"id": "erz", "text": "Ein Brocken Mondsilber für den Reif."},
			{"id": "eisen", "text": "Zwei Barren Eisen, damit er nicht verrutscht."},
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
		"ingredients": {"goldkarpfen": 1, "baerlauch": 2, "eisen": 4},
		"lines": [
			{"id": "karpfen", "text": "Die goldenen Schuppen eines Karpfens aus dem Dorfbrunnen."},
			{"id": "lauch", "text": "Zwei Bund Bärlauch, um das Eisen geschmeidig zu kochen."},
			{"id": "eisen", "text": "Vier Barren Eisen für den Reif."},
		]},
	# Learned with the first grotto crystals (see Mines), cut at the gem
	# cutter's wheel and set in a fine bar from melting at Gorm's forge. The
	# setting is fine metalwork, so that is the craft they train.
	"kristallring": {"name": "Kristallring", "giver": "", "found": "grottenkristall",
		"craft": "feinschmieden", "bench": "edelsteinschleifen", "craft_level": 0, "result": "kristallring",
		"effect": "+2 Leben, +1 Kampfkraft",
		"ingredients": {"grottenkristall": 3, "silber": 1},
		"lines": [
			{"id": "kristall", "text": "Drei Grottenkristalle, klar geschliffen."},
			{"id": "silber", "text": "Ein Silberbarren für die Fassung."},
		]},
	"kristallamulett": {"name": "Kristallamulett", "giver": "", "found": "grottenkristall",
		"craft": "feinschmieden", "bench": "edelsteinschleifen", "craft_level": 0, "result": "kristallamulett",
		"effect": "+3 Leben, +1 Kampfkraft",
		"ingredients": {"grottenkristall": 5, "gold": 1},
		"lines": [
			{"id": "kristall", "text": "Fünf Grottenkristalle, zu einem Stern geschliffen."},
			{"id": "gold", "text": "Ein Goldbarren für Kette und Fassung."},
		]},
	# Learned with the first part of the fallen dragon (see DragonLair) and
	# made at the fine metalwork bench on the crafting square.
	"schuppenreif": {"name": "Schuppenreif", "giver": "", "found": "drachenschuppe",
		"craft": "feinschmieden", "craft_level": 0, "result": "schuppenreif",
		"effect": "+3 Leben, Rüstung tragen +1",
		"ingredients": {"drachenschuppe": 2, "eisen": 2},
		"lines": [
			{"id": "schuppe", "text": "Zwei Drachenschuppen, hart wie Stahl."},
			{"id": "eisen", "text": "Zwei Barren Eisen für den Reif."},
		]},
	"drachenblutring": {"name": "Drachenblutring", "giver": "", "found": "drachenblut",
		"craft": "feinschmieden", "craft_level": 0, "result": "drachenblutring",
		"effect": "+2 Leben, +2 Kampfkraft",
		"ingredients": {"drachenblut": 2, "silber": 1},
		"lines": [
			{"id": "blut", "text": "Zwei Phiolen Drachenblut, in denen das Silber gehärtet wird."},
			{"id": "silber", "text": "Ein Silberbarren für den Ring."},
		]},
	"glutherzamulett": {"name": "Glutherz-Amulett", "giver": "", "found": "glutherz",
		"craft": "feinschmieden", "craft_level": 0, "result": "glutherzamulett",
		"effect": "+4 Leben, +2 Kampfkraft, schneller",
		"ingredients": {"glutherz": 1, "drachenblut": 1, "drachenschuppe": 1, "gold": 1},
		"lines": [
			{"id": "herz", "text": "Das glühende Herz des Drachen als Stein."},
			{"id": "blut", "text": "Drachenblut, damit die Glut nicht erlischt."},
			{"id": "schuppe", "text": "Eine Drachenschuppe als Fassung."},
			{"id": "gold", "text": "Ein Goldbarren für die Kette."},
		]},
}

## Explained once in the compendium, when the first recipe is found.
const HOW_TO := "Rezepte stehen im Kompendium (Taste H) im „Rezeptbuch“: was hineingehört, welches Handwerk es braucht, und verblasste Zeilen (…), die du noch herausfinden musst. Darunter stehen die Zutaten: wo und wann man sie findet und woher sie kommen. Zutaten kommen in deinen Zutatenbeutel, nicht in die Tasche."

var game: Node
## Known recipes: recipe id -> {"read": [ids of faded lines already read]}.
var known := {}
## The ingredient pouch: ingredient id -> count. Coins and gems are never
## in it: they go in the purse (see in_purse).
var pouch := {}
## The purse: the coins other than copper (iron, silver, gold, see
## Loot.COINS) and the cut and uncut gems (see Ore.GEMS), id -> count. It
## takes no place in the bag or the pouch. The copper coins, the hero's
## money, are counted in game.coins and belong in it too.
var purse := {}
## Ingredients the hero gathered at least once: their place is marked as
## found in the ingredient book.
var found := []
## The lumps of ore in the pouch, by size (see Ore.LUMPS): a list of
## {"grams", "share"} each, oldest first, as many as the pouch counts.
var ores := {}
## The gems in the purse (see Ore.GEMS), uncut and cut: their weights in
## carat, oldest first, as many as the purse counts.
var gems := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	known.clear()
	pouch.clear()
	purse.clear()
	found.clear()
	ores.clear()
	gems.clear()


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


## How many of an ingredient the hero has; "eisen" is the smith's iron bars,
## "bronze", "silber" and "gold" the fine bars (see Forge).
func have(ingredient: String) -> int:
	if ingredient == "eisen":
		return game.iron if game else 0
	if ingredient == Loot.MONEY:
		return game.coins if game else 0
	if ingredient in Forge.FINE:
		return int(game.bars.get(ingredient, 0)) if game else 0
	return int(_holder(ingredient).get(ingredient, 0))


## Whether something is carried in the purse rather than the pouch: every
## coin (see Loot.COINS) and the cut and uncut gems (see Ore.GEMS).
static func in_purse(id: String) -> bool:
	return Loot.COINS.has(id) or Ore.GEMS.has(id)


## The table that counts an ingredient: the purse for coins and gems, the
## pouch for the rest.
func _holder(ingredient: String) -> Dictionary:
	return purse if in_purse(ingredient) else pouch


## Sets how many of a pouch or purse ingredient the hero carries (none
## takes it out of the table). Not for copper coins, iron or the fine bars.
func set_count(ingredient: String, count: int) -> void:
	var table := _holder(ingredient)
	if count > 0:
		table[ingredient] = count
	else:
		table.erase(ingredient)


## Takes `count` of an ingredient out of the pouch or purse (as many as
## there are);
## ore goes oldest lump first.
func take(ingredient: String, count := 1) -> void:
	if ingredient == Loot.MONEY:
		game.coins = maxi(0, game.coins - count)
		return
	var store := _pieces(ingredient)
	if store.has(ingredient):
		var list: Array = store[ingredient]
		for i in mini(count, list.size()):
			list.pop_front()
		if list.is_empty():
			store.erase(ingredient)
	set_count(ingredient, have(ingredient) - count)


## Where the single pieces of an ingredient are kept, each with its own
## make-up: `ores` for lumps of ore, `gems` for gems; an empty table for
## the rest (see has_pieces).
func _pieces(ingredient: String) -> Dictionary:
	if Ore.is_ore(ingredient):
		return ores
	if Ore.GEMS.has(ingredient):
		return gems
	return {}


## Whether each piece of an ingredient is kept on its own (ore, gems).
static func has_pieces(ingredient: String) -> bool:
	return Ore.is_ore(ingredient) or Ore.GEMS.has(ingredient)


## Takes up to `count` pieces of an ore or gem out of the pouch, oldest
## first, and returns them (lumps or carats) so they can be put back as they
## were (see give_pieces and HomeStores).
func take_pieces(ingredient: String, count: int) -> Array:
	var n := mini(count, have(ingredient))
	var list: Array = _pieces(ingredient).get(ingredient, [])
	var out := list.slice(0, n)
	take(ingredient, n)
	return out


## Puts `count` pieces of an ore or gem back into the pouch: those given,
## and newly rolled ones for any that are missing.
func give_pieces(ingredient: String, count: int, pieces: Array) -> void:
	if count <= 0:
		return
	var store := _pieces(ingredient)
	if not store.has(ingredient):
		store[ingredient] = []
	for i in count:
		if i < pieces.size():
			store[ingredient].append(pieces[i])
		else:
			store[ingredient].append(Ore.roll(ingredient) if Ore.is_ore(ingredient) else Ore.roll_carat())
	set_count(ingredient, have(ingredient) + count)
	if not found.has(ingredient):
		found.append(ingredient)


## Puts one gem of `carat` into the purse (see Ore.GEMS).
func add_gem(id: String, carat: int) -> void:
	set_count(id, have(id) + 1)
	if not gems.has(id):
		gems[id] = []
	gems[id].append(carat)
	if not found.has(id):
		found.append(id)


## Puts ingredients into the pouch. found_here: the hero gathered them where
## they stand (not, say, as a reward), so the spot goes on their map (see
## Journal.note_find).
func add(ingredient: String, count := 1, found_here := true) -> void:
	if ingredient == "eisen":
		game.iron += count
	elif ingredient == Loot.MONEY:
		# Copper coins are the hero's money (see Loot.MONEY).
		game.coins += count
	elif INGREDIENTS.has(ingredient):
		set_count(ingredient, have(ingredient) + count)
		var store := _pieces(ingredient)
		if has_pieces(ingredient):
			# Each lump of ore gets its own weight and make-up (see Ore.roll),
			# each gem its own weight (see Ore.roll_carat).
			if not store.has(ingredient):
				store[ingredient] = []
			for i in count:
				store[ingredient].append(Ore.roll(ingredient) if Ore.is_ore(ingredient) else Ore.roll_carat())
		if not found.has(ingredient):
			found.append(ingredient)
		if found_here and game != null and game.level != null and game.player != null:
			# Fish (caught with the line) get a mark of their own colour.
			var kind := "fish" if str(INGREDIENTS[ingredient].source).begins_with("Angeln") else "ingredient"
			game.note_find(kind, ingredient, INGREDIENTS[ingredient].name, game.player.global_position)


## The recipes the hero learns on gathering `ingredient` (those with it as
## "found") and did not know yet. Returns their ids.
func learn_from_find(ingredient: String) -> Array:
	var learned := []
	for id in RECIPES:
		if RECIPES[id].get("found", "") == ingredient and learn_recipe(id):
			learned.append(id)
	if not learned.is_empty():
		Events.teach(HOW_TO)
	return learned


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
	if ingredient == Loot.MONEY:
		return Lang.t("Kupfermünze")
	if ingredient in Forge.FINE:
		return Lang.t(Forge.METALS[ingredient].name)
	return Lang.t(INGREDIENTS[ingredient].name) if INGREDIENTS.has(ingredient) else ingredient


## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return {"known": known.duplicate(true), "pouch": pouch.duplicate(), "purse": purse.duplicate(), "found": found.duplicate(), "ores": ores.duplicate(true), "gems": gems.duplicate(true)}


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
	# Older games kept coins and gems in the pouch: they move to the purse.
	for key in ["pouch", "purse"]:
		var saved_table = saved.get(key, {})
		if saved_table is Dictionary:
			for ingredient in saved_table:
				var count := int(saved_table[ingredient])
				if INGREDIENTS.has(str(ingredient)) and count > 0:
					set_count(str(ingredient), have(str(ingredient)) + count)
	# The lumps of ore keep their make-up; a lump the pouch counts but the
	# save lacks (an older game) is rolled anew.
	var saved_ores = saved.get("ores", {})
	if not (saved_ores is Dictionary):
		saved_ores = {}
	for id in Ore.LUMPS:
		var lumps := []
		var kept = saved_ores.get(id, [])
		if kept is Array:
			for lump in kept:
				if lump is Dictionary and lump.has("grams") and lump.get("share") is Dictionary and lumps.size() < have(id):
					var gems := []
					if lump.get("gems", []) is Array:
						for carat in lump.get("gems", []):
							gems.append(int(carat))
					lumps.append({"grams": int(lump.grams), "share": lump.share, "gems": gems})
		while lumps.size() < have(id):
			lumps.append(Ore.roll(id))
		if not lumps.is_empty():
			ores[id] = lumps
	# The gems keep their weight in carat (see Ore.GEMS).
	var saved_gems = saved.get("gems", {})
	if not (saved_gems is Dictionary):
		saved_gems = {}
	for id in Ore.GEMS:
		var list := []
		var kept = saved_gems.get(id, [])
		if kept is Array:
			for carat in kept:
				if int(carat) > 0 and list.size() < have(id):
					list.append(int(carat))
		while list.size() < have(id):
			list.append(Ore.roll_carat())
		if not list.is_empty():
			gems[id] = list
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


## The known recipes made at the bench of a craft, in the order of RECIPES:
## what that bench lists (see "bench").
func recipes_for(craft: String) -> Array:
	return entries().filter(func(id): return RECIPES[id].get("bench", RECIPES[id].craft) == craft)


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
		elif ingredient in Forge.FINE:
			game.bars[ingredient] = have(ingredient) - count
			if int(game.bars[ingredient]) <= 0:
				game.bars.erase(ingredient)
		else:
			take(ingredient, count)
	var p: Player = game.player
	if p.bag_fits(r.result):
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
## in the order the recipes name them, and anything else in the pouch or
## the purse.
func book_ingredients() -> Array:
	var ids := []
	for id in entries():
		for ingredient in RECIPES[id].ingredients:
			if not ids.has(ingredient):
				ids.append(ingredient)
	for ingredient in pouch.keys() + purse.keys():
		if not ids.has(ingredient):
			ids.append(ingredient)
	return ids


## An ingredient as the ingredient book shows it: how many are in the
## pouch, where and when it is found and what yields it, how to find it,
## and whether the hero found the place yet.
func describe_ingredient(ingredient: String) -> String:
	var info: Dictionary = IRON if ingredient == "eisen" else (FINE_BARS if ingredient in Forge.FINE else INGREDIENTS[ingredient])
	var place := Lang.t("Ort: %s") % Lang.t(info.region)
	if info.when != "":
		place += "  ·  " + Lang.t("Zeit: %s") % Lang.t(info.when)
	place += "  ·  " + Lang.t("Quelle: %s") % Lang.t(info.source)
	var lines := ["%s  (%s)" % [ingredient_name(ingredient), Lang.t("%d dabei") % have(ingredient)], place, Lang.t(info.where)]
	if INGREDIENTS.has(ingredient):
		lines.append(Lang.t("Fundort entdeckt.") if found.has(ingredient) else Lang.t("Fundort noch nicht selbst entdeckt."))
	return "\n".join(lines)
