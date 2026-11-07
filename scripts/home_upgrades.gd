class_name HomeUpgrades
extends RefCounted
## Building onto the hero's own town house on Weavers' Lane (see Homes). The hero pays stone
## blocks (from the bag first, then from the storage chest) and some gold, and
## Hagen the stonemason builds the upgrade. Each one is built once and stays
## in the saved game (Game.home_upgrades):
##   werkstatt   a workbench: turns iron bars into throwing knives and mends
##               worn gear, and the hero's craft hours away go faster there.
##   truhe       a second storage chest beside the first: the chests hold
##               twice as much.
##   trophaeen   a trophy wall: one trophy for every kind of mighty foe the
##               hero has felled (Game.trophies, counted from the start, even
##               before the wall is built). Each trophy on the wall gives
##               +1 life, as long as the wall stands.
##   feinbank    the fine metalwork bench of the crafting square, at home
##   schleifrad  the gem cutter's wheel, at home
##   alchemie    the alchemist's table, at home
##   hort        a growing hoard of coins that shows the hero's wealth (HomeHoard)
## The three crafting benches are the very same ones as in the village (CraftingSquare.build):
## the same recipes, the same craft levels, the same window.
## The furniture is placed by Level.show_home_upgrades on the chalked
## furniture spots of the house (Level.furniture_slots): the second chest
## beside the first, the workbench and the trophy wall up in the attic. The
## upgrade window opens from the bed in the house and from the stonemason
## (see Menus._build_upgrades).
##
## Everything here is pure: the game's state goes in, a result comes out.

## What the compendium says about home upgrades, once the hero has seen them.
const LEARN := "Dein Haus in der Weberzeile lässt sich ausbauen: Mit Steinblöcken und etwas Kupfer baut dir Steinmetz Hagen eine Werkstatt (Wurfmesser aus Eisen, Ausrüstung flicken, schnelleres Handwerk während du weg bist), eine zweite Truhe (doppelt so viel Platz), eine Trophäenwand (jede Trophäe eines besiegten mächtigen Gegners gibt +1 Leben), dieselben Werkbänke wie auf dem Handwerkerplatz (Feinschmieden, Edelsteinschleifen, Alchemie) und einen Hort, der dein Vermögen in Münzen zeigt. Das Ausbau-Fenster öffnest du am Bett in deinem Haus oder beim Steinmetz."

## The upgrades, in the order they are shown: name, what it does, and its
## price in stone blocks and gold.
const ALL := {
	"werkstatt": {"name": "Werkstatt", "stones": 6, "gold": 30,
		"text": "Eine Werkbank: Eisenbarren werden zu Wurfmessern, abgenutzte Ausrüstung wird geflickt, und Handwerk während du weg bist geht schneller."},
	"truhe": {"name": "Zweite Truhe", "stones": 4, "gold": 10,
		"text": "Eine zweite Truhe neben der ersten: Deine Truhen fassen doppelt so viel."},
	"trophaeen": {"name": "Trophäenwand", "stones": 5, "gold": 20,
		"text": "Eine Wand für die Trophäen mächtiger Gegner, die du besiegt hast. Jede Trophäe gibt +1 Leben."},
	"feinbank": {"name": "Werkbank des Feinschmieds", "stones": 6, "gold": 40, "bench": "+",
		"text": "Dieselbe Werkbank wie auf dem Handwerkerplatz: Ringe, Ketten und feiner Draht, jetzt zu Hause."},
	"schleifrad": {"name": "Schleifrad", "stones": 6, "gold": 40, "bench": "%",
		"text": "Dasselbe Schleifrad wie auf dem Handwerkerplatz: rohe Edelsteine schleifen, jetzt zu Hause."},
	"alchemie": {"name": "Alchemistentisch", "stones": 6, "gold": 40, "bench": "*",
		"text": "Derselbe Tisch wie auf dem Handwerkerplatz: Tränke und Tinkturen brauen, jetzt zu Hause."},
	"hort": {"name": "Hort", "stones": 8, "gold": 50,
		"text": "Ein wachsender Hort, der dein Vermögen zeigt: In 20 Stufen von ein paar Münzen bis zum Berg aus Münzen, und die Haufen zeigen, welche Münzen du bei dir trägst: Hast du 200 Kupfer und 50 Silber, liegt dort vier Mal so viel Kupfer wie Silber."},
}

## Trophies: enemy kind -> name of the trophy. Only the first foe of each kind
## counts, so there are at most this many.
const TROPHIES := {
	"hauptmann": "Helm des Räuberhauptmanns",
	"drache": "Drachenschädel",
	"yeti": "Yetifell",
	"ork": "Orkhauer",
	"wolf": "Wolfspelz",
	"spinne": "Spinnenbein",
	"koloss": "Axt des Kolosses",
}
## Where each trophy is to be won, for the trophy wall's list.
const TROPHY_HINTS := {
	"hauptmann": "der Räuberhauptmann am Räuberpass",
	"drache": "der Drache in seiner Höhle",
	"yeti": "der Yeti in der Wolfssenke",
	"ork": "ein Ork in der Wolfssenke",
	"wolf": "ein Wolf in der Wolfssenke",
	"spinne": "eine Riesenspinne in der Wolfssenke",
	"koloss": "ein Koloss im Verlies",
}
## Colours of the trophies' plaques on the wall, by kind.
const TROPHY_COLORS := {
	"hauptmann": Color(0.62, 0.64, 0.7), "drache": Color(0.75, 0.28, 0.2), "yeti": Color(0.88, 0.9, 0.95),
	"ork": Color(0.45, 0.62, 0.32), "wolf": Color(0.5, 0.46, 0.42), "spinne": Color(0.3, 0.26, 0.34),
	"koloss": Color(0.72, 0.42, 0.34),
}
## Life each trophy on the wall gives.
const TROPHY_HP := 1

## The storage chest's size, and how much the second chest adds.
const STORAGE_SIZE := 16
const SECOND_CHEST := 16

## At the workbench: throwing knives made from one iron bar, and iron bars
## to mend one worn piece completely.
const KNIVES_PER_IRON := 2
const MEND_IRON := 1
## With a workshop, a piece crafted while away takes this share of the hours.
const WORKSHOP_CRAFT := 2.0 / 3.0

const STONE := "steinblock"


static func has(built: Dictionary, id: String) -> bool:
	return bool(built.get(id, false))


## How many slots the storage chest has with these upgrades.
static func storage_size(built: Dictionary) -> int:
	return STORAGE_SIZE + (SECOND_CHEST if has(built, "truhe") else 0)


## How many of the storage chest's slots these items take: torches bundle
## there just as in the bag (see Items.stacks), so the chest stays a plain
## list of ids and older saves with loose torches bundle on their own.
static func storage_used(storage: Array) -> int:
	return Items.slots_used(storage)


## Whether one more of `id` fits in the storage chest: on a bundle of it
## with room, or in a free slot.
static func storage_fits(built: Dictionary, storage: Array, id: String) -> bool:
	return Items.fits(storage, storage_size(built), id)


## Stone blocks the hero can pay with: in the bag and in the storage chest.
static func stones_owned(bag: Array, storage: Array) -> int:
	return bag.count(STONE) + storage.count(STONE)


## Why an upgrade cannot be built right now, or "" when it can.
static func why_not(id: String, built: Dictionary, bag: Array, storage: Array, gold: int) -> String:
	if not ALL.has(id):
		return Lang.t("Das kann Hagen nicht bauen.")
	if has(built, id):
		return Lang.t("Das ist schon gebaut.")
	if stones_owned(bag, storage) < ALL[id].stones:
		return Lang.t("Dafür brauchst du %d Steinblöcke (in Tasche oder Truhe).") % ALL[id].stones
	if gold < ALL[id].gold:
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	return ""


## Takes an upgrade's stone blocks out of the bag first, then the chest.
static func pay_stones(id: String, bag: Array, storage: Array) -> void:
	var left: int = ALL[id].stones
	while left > 0 and bag.has(STONE):
		bag.erase(STONE)
		left -= 1
	while left > 0 and storage.has(STONE):
		storage.erase(STONE)
		left -= 1


## The trophies on the wall: the ones won, in the order of TROPHIES.
static func trophies_shown(won: Dictionary) -> Array:
	return TROPHIES.keys().filter(func(kind): return bool(won.get(kind, false)))


## Life the trophy wall gives the hero.
static func trophy_hp(built: Dictionary, won: Dictionary) -> int:
	return trophies_shown(won).size() * TROPHY_HP if has(built, "trophaeen") else 0
