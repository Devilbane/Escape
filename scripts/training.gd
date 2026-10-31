class_name Training
extends RefCounted
## How the hero grows by doing things. Two kinds of values are trained:
##
## Attributes (Eigenschaften) belong to the hero's body. Fighting makes them
## stronger, taking blows makes them tougher, running makes them faster. They
## grow very slowly: a whole run through the dungeon earns about one point,
## and every point costs ATTRIBUTE_GROWTH times as much as the one before.
##   Stärke (strength) 10..30: +1 Kampfkraft per point, and loads weigh less.
##   Konstitution (constitution) 10..30: +1 Leben per point.
##   Tempo (speed) 100 %..150 %, in steps of 5 %.
##   Intuition 10..30: a feeling for how things work. Searching and walking
##     past secret levers train it; each point is +2 % to notice a lever.
##     Traps to find and liars to see through can ask it later too.
##   Geschick (dexterity) 10..30: jumping, throwing and spike traps train it;
##     each point makes running jumps 2 % longer and is 4 % chance to slip
##     past spikes. Locks and disarming traps can ask it later too.
##   Weisheit (wisdom) 10..30: grows from going through things, whatever
##     the outcome: finishing a level, finding the key or a secret, choosing
##     at a shrine, and the end of every run, fallen or free. Each point makes
##     all other training 5 % quicker, and from WISE_SHRINE on the shrines
##     offer a fourth gift.
##   Intelligenz (intelligence) 10..30: grows from understanding things
##     (every new entry in the compendium) and from beating skeleton mages.
##     Items of the mind (hats, later scrolls and wands) need some of it:
##     "requires" in Items.ALL, and a skill in SKILLS can ask for it too.
##
## Skills (Fertigkeiten) say how well the hero handles a kind of equipment.
## A skill only works, and only trains, while the gear that needs it is worn
## (a blade for Klingen, an axe for Äxte, a shield for Blocken, hard armour
## for Rüstung). Skills grow much faster than attributes, up to SKILL_MAX,
## and some items add levels of their own ("skills" in Items.ALL).
##
## Everything trained stays with the hero's name, from one run to the next,
## in FILE.

const FILE := "user://helden.json"

## "first" is what the first point costs in training; every further point
## costs ATTRIBUTE_GROWTH times the one before. Tuned so that one run through
## all ten levels earns roughly one point of each.
const ATTRIBUTES := {
	"staerke": {"name": "Stärke", "start": 10, "max": 30, "step": 1, "first": 250.0},
	"konstitution": {"name": "Konstitution", "start": 10, "max": 30, "step": 1, "first": 50.0},
	"tempo": {"name": "Tempo", "start": 100, "max": 150, "step": 5, "first": 4500.0},
	"intuition": {"name": "Intuition", "start": 10, "max": 30, "step": 1, "first": 180.0},
	"geschick": {"name": "Geschick", "start": 10, "max": 30, "step": 1, "first": 60.0},
	"weisheit": {"name": "Weisheit", "start": 10, "max": 30, "step": 1, "first": 200.0},
	"intelligenz": {"name": "Intelligenz", "start": 10, "max": 30, "step": 1, "first": 130.0},
}
const ATTRIBUTE_GROWTH := 1.25
## Each point of Weisheit above 10 makes all other training this much quicker.
const LEARNING_PER_WISDOM := 0.05
## From this much Weisheit on, a shrine offers a fourth gift.
const WISE_SHRINE := 12

## Each skill; what a level does is in Player. A skill may have "requires"
## (attribute id -> value), like an item, before it can be used or learned.
##   Klingen, Äxte, Messerwurf: +5 % chance per level of a heavy hit (+1 damage).
##   Blocken: +2 % block chance per level.  Rüstung tragen: hard armour
##   weighs 6 % less per level.  Schleichen: sneaking 3 % faster per level.
const SKILLS := {
	"klingen": {"name": "Klingen"},
	"aexte": {"name": "Äxte"},
	"werfen": {"name": "Messerwurf"},
	"blocken": {"name": "Blocken"},
	"ruestung": {"name": "Rüstung tragen"},
	"schleichen": {"name": "Schleichen"},
}
const SKILL_MAX := 10
const SKILL_FIRST := 8.0
const SKILL_GROWTH := 1.45


## How many points a stock of training has earned: point n costs
## first * growth^n, and no more than `cap` points can be earned.
static func points(xp: float, first: float, growth: float, cap: int) -> int:
	var n := 0
	var cost := first
	while n < cap and xp >= cost:
		xp -= cost
		n += 1
		cost *= growth
	return n


## How far the training has come towards the next point, 0..1 (1 at the cap).
static func progress(xp: float, first: float, growth: float, cap: int) -> float:
	var n := 0
	var cost := first
	while n < cap and xp >= cost:
		xp -= cost
		n += 1
		cost *= growth
	return 1.0 if n >= cap else xp / cost


static func attribute_cap(id: String) -> int:
	var a: Dictionary = ATTRIBUTES[id]
	return (a.max - a.start) / a.step


static func attribute_value(id: String, xp: float) -> int:
	var a: Dictionary = ATTRIBUTES[id]
	return a.start + a.step * points(xp, a.first, ATTRIBUTE_GROWTH, attribute_cap(id))


static func attribute_progress(id: String, xp: float) -> float:
	var a: Dictionary = ATTRIBUTES[id]
	return progress(xp, a.first, ATTRIBUTE_GROWTH, attribute_cap(id))


static func skill_level(xp: float) -> int:
	return points(xp, SKILL_FIRST, SKILL_GROWTH, SKILL_MAX)


static func skill_progress(xp: float) -> float:
	return progress(xp, SKILL_FIRST, SKILL_GROWTH, SKILL_MAX)


static func is_skill(id: String) -> bool:
	return SKILLS.has(id)


## The training of every hero on this computer, by name.
static func _load_all() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return data if data is Dictionary else {}


## What the hero with this name has trained so far (empty for a new hero).
static func load_hero(hero: String) -> Dictionary:
	var all := _load_all()
	var xp := {}
	var stored = all.get(hero, {})
	if stored is Dictionary:
		for id in stored:
			if ATTRIBUTES.has(id) or SKILLS.has(id):
				xp[id] = float(stored[id])
	return xp


static func save_hero(hero: String, xp: Dictionary) -> void:
	var all := _load_all()
	all[hero] = xp
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(all))
