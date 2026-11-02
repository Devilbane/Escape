class_name Companions
extends RefCounted
## The hero's companions: wild animals of the woods won over with their
## favourite food (see Animal, "curious"). A fox loves sausages, a doe
## apples and a stag a salt lick; after TRUST_NEEDED of them from the
## hero's hand it is the hero's friend for good, and the hero gives it a
## name.
##
## The hero can have one companion of each kind. One goes with them (see
## Pet); the others wait at the hero's house, in the corner by the door
## (the "N" tile of the home), and the hero swaps them there: running into
## one opens the companions window.
##
## Each kind gives the hero one perk while it goes with them, one plain
## number in the stats the hero already knows, so it is easy to read:
##   fox: +1 Erkunden (the Exploration skill, see Training), and its nose
##        digs up the ingredients hidden in the ground;
##   doe: +10 % Tempo;
##   stag: +1 Kampfkraft.
## A companion at home gives nothing, so it matters who comes along.

const TRUST_NEEDED := 3
## The longest name a companion can be given.
const NAME_MAX := 14

## name: the kind, as shown; model and scale: see Animal.KINDS; food: the
## item that wins it over; default: the name it is offered when it comes
## along for the first time; perk: what it gives, as shown (its numbers are
## below it: speed, power, skills); fed and tamed: what the hero is told
## when it eats from their hand and when it trusts them; ask: the question
## in the naming window; nose: digs up hidden ingredients;
## reach: how close it comes to eat from the hero's hand (metres); colour:
## its paw in the companions window.
const SPECIES := {
	"fuchs": {"name": "Fuchs", "plural": "Füchse", "model": "Fox", "scale": 0.4, "food": "wurst", "default": "Rufus",
		"perk": "+1 Erkunden, gräbt versteckte Zutaten aus", "skills": {"erkunden": 1}, "nose": true,
		"fed": "Der Fuchs frisst dir die Wurst aus der Hand. Vertrauen: %d / %d",
		"tamed": "Der Fuchs vertraut dir und geht jetzt mit dir! Seine Nase findet versteckte Zutaten im Boden.",
		"ask": "Wie soll dein Fuchs heißen?",
		"reach": 1.8, "colour": Color(0.95, 0.55, 0.25)},
	"reh": {"name": "Reh", "plural": "Rehe", "model": "Deer", "scale": 0.45, "food": "apfel", "default": "Liese",
		"perk": "+10 % Tempo", "speed": 0.1,
		"fed": "Das Reh frisst dir den Apfel aus der Hand. Vertrauen: %d / %d",
		"tamed": "Das Reh vertraut dir und geht jetzt mit dir! Solange es bei dir ist, bist du flinker: +10 % Tempo.",
		"ask": "Wie soll dein Reh heißen?",
		"reach": 2.2, "colour": Color(0.85, 0.65, 0.42)},
	"hirsch": {"name": "Hirsch", "plural": "Hirsche", "model": "Stag", "scale": 0.45, "food": "salzleckstein", "default": "Hubertus",
		"perk": "+1 Kampfkraft", "power": 1,
		"fed": "Der Hirsch leckt an deinem Salzleckstein. Vertrauen: %d / %d",
		"tamed": "Der Hirsch vertraut dir und geht jetzt mit dir! Solange er bei dir ist, schlägst du kräftiger zu: +1 Kampfkraft.",
		"ask": "Wie soll dein Hirsch heißen?",
		"reach": 2.4, "colour": Color(0.7, 0.5, 0.32)},
}
## The order they are listed in.
const ORDER := ["fuchs", "reh", "hirsch"]

## Where the does and stags live, for the hint on buying their food and for
## the compendium (the fox's is Pet.WHERE).
const WHERE_DEER := "Rehe und Hirsche äsen auf den Lichtungen im Wald zwischen Friedhof und Dorf. Ein Reh frisst gern Äpfel, ein Hirsch leckt gern Salz: Trag das bei dir, dann kommen sie zu dir."
## For the compendium, the first time an animal eats from the hero's hand.
const LEARN := "Gefährten: Ein Fuchs (Wurst), ein Reh (Apfel) und ein Hirsch (Salzleckstein) lassen sich mit ihrem Lieblingsfutter zähmen. Nach drei Gaben aus deiner Hand ist das Tier dein Freund, und du gibst ihm einen Namen. Einer geht mit dir und schenkt dir seine Gabe: der Fuchs +1 Erkunden (und er gräbt Zutaten aus), das Reh +10 % Tempo, der Hirsch +1 Kampfkraft. Die anderen warten in deinem Haus; lauf dort gegen einen, um zu tauschen oder sie umzubenennen."


## The kind of animal that eats an item, or "".
static func eater_of(food: String) -> String:
	for kind in ORDER:
		if SPECIES[kind].food == food:
			return kind
	return ""


## Whether an animal kind can become a companion.
static func is_species(kind: String) -> bool:
	return SPECIES.has(kind)


## The kind, as shown ("Fuchs").
static func species_name(kind: String) -> String:
	return Lang.t(SPECIES[kind].name)


## What a kind gives the hero while it goes with them, as shown.
static func perk_text(kind: String) -> String:
	return Lang.t(SPECIES[kind].perk)


## A name as the hero typed it, tidied: no blanks round it, not too long,
## and the kind's own name when nothing is left.
static func clean_name(text: String, kind: String) -> String:
	var name := text.strip_edges().replace("\n", " ")
	if name.length() > NAME_MAX:
		name = name.substr(0, NAME_MAX).strip_edges()
	return name if name != "" else Lang.t(SPECIES[kind].name)


## A companion as kept in the saved game.
static func make(kind: String, given_name: String) -> Dictionary:
	return {"kind": kind, "name": clean_name(given_name, kind)}


## Reads the companions from a saved game: the list, which one goes with
## the hero (-1: none) and how far each kind trusts the hero. An old saved
## game only knows the fox ("fox": {"trust", "tame"}).
static func from_save(data: Dictionary) -> Dictionary:
	var list: Array = []
	var trust := {}
	var following := -1
	var saved = data.get("companions", null)
	if saved is Dictionary:
		for c in saved.get("list", []):
			if c is Dictionary and is_species(str(c.get("kind", ""))) and not list.any(func(o): return o.kind == c.kind):
				list.append(make(str(c.kind), str(c.get("name", ""))))
		var t = saved.get("trust", {})
		if t is Dictionary:
			for kind in t:
				if is_species(str(kind)):
					trust[str(kind)] = clampi(int(t[kind]), 0, TRUST_NEEDED)
		following = int(saved.get("following", -1))
	else:
		var fox = data.get("fox", {})
		if fox is Dictionary:
			trust["fuchs"] = clampi(int(fox.get("trust", 0)), 0, TRUST_NEEDED)
			if bool(fox.get("tame", false)):
				list.append(make("fuchs", SPECIES.fuchs.default))
				following = 0
	if following < -1 or following >= list.size():
		following = 0 if not list.is_empty() else -1
	return {"list": list, "following": following, "trust": trust}
