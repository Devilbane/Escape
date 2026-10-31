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
##   Klingen, Äxte, Messerwurf: a heavy hit (+1 damage) is a skill roll.
##   Blocken: +2 % block chance per level.  Rüstung tragen: hard armour
##   weighs 6 % less per level.  Schleichen: sneaking 3 % faster per level.
##
## Every skill is governed by one or two of the three main attributes
## ("attributes"); that places it in one of the six SECTORS of the character
## page. A roll on a skill (skill_chance) uses their average.
## A basic skill sits in the inner ring, right around the attributes. A
## advanced skill has "needs" (basic skill id -> level): it sits in the outer
## ring and can only be used and learned once those levels are reached.
const SKILLS := {
	"klingen": {"name": "Klingen", "attributes": ["staerke", "geschick"]},
	"aexte": {"name": "Äxte", "attributes": ["staerke"]},
	"werfen": {"name": "Messerwurf", "attributes": ["geschick"]},
	"blocken": {"name": "Blocken", "attributes": ["staerke", "geschick"]},
	"ruestung": {"name": "Rüstung tragen", "attributes": ["staerke"]},
	"schleichen": {"name": "Schleichen", "attributes": ["geschick", "intelligenz"]},
}
## The three main attributes, clockwise from the top of the character page.
const MAIN_ATTRIBUTES := ["staerke", "geschick", "intelligenz"]
## The ring of skills around them, clockwise from the top, 60 degrees each:
## a main attribute alone, then the pair it shares with the next one.
const SECTORS := [
	["staerke"],
	["staerke", "geschick"],
	["geschick"],
	["geschick", "intelligenz"],
	["intelligenz"],
	["intelligenz", "staerke"],
]
## A basic skill is learned up to SKILL_MAX. An advanced skill (one with
## "needs") has ADVANCED_MAX levels. The first nine come in three ranks of
## RANK_SIZE: Novice, Advanced, Master; that is what training reaches for now
## (ADVANCED_LEARNED). Levels 10 to 15 are still to be defined. Beyond them
## lies special knowledge, only from quests and rewards (items with "skills").
const SKILL_MAX := 10
const ADVANCED_MAX := 15
const ADVANCED_LEARNED := 9
const RANK_SIZE := 3
const RANKS := ["Novize", "Fortgeschritten", "Meister"]
const SPECIAL_RANK := "Sonderwissen"
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


## The most levels training can give a skill (all of them for an unknown id).
static func skill_max(id: String) -> int:
	return ADVANCED_LEARNED if SKILLS.has(id) and tier(id) == 2 else SKILL_MAX


static func skill_level(xp: float, id := "") -> int:
	return points(xp, SKILL_FIRST, SKILL_GROWTH, skill_max(id))


static func skill_progress(xp: float, id := "") -> float:
	return progress(xp, SKILL_FIRST, SKILL_GROWTH, skill_max(id))


## The rank of an advanced skill at a level: Novice, Advanced or Master up to
## 9, "?" for the levels still to be defined, special knowledge above
## ADVANCED_MAX. Empty for basic skills and level 0.
static func rank(id: String, level: int) -> String:
	if tier(id) != 2 or level <= 0:
		return ""
	if level > ADVANCED_MAX:
		return SPECIAL_RANK
	if level > ADVANCED_LEARNED:
		return "?"
	return RANKS[(level - 1) / RANK_SIZE]


## The chance in percent that a roll on a skill succeeds, d100 <= chance:
## the average of the governing attributes times (skill level + 1). An
## average of 10 at level 0 is 10 %, at level 4 it is 50 %; 100 or more
## always succeeds.
static func skill_chance(attribute_average: float, level: int) -> int:
	return floori(attribute_average * (level + 1))


## 1 for a basic skill (inner ring), 2 for an advanced skill (outer ring).
static func tier(id: String) -> int:
	return 2 if SKILLS[id].has("needs") else 1


## Which of the six SECTORS a skill sits in.
static func sector_of(id: String) -> int:
	var governing: Array = SKILLS[id].attributes
	for i in SECTORS.size():
		var sector: Array = SECTORS[i]
		if sector.size() == governing.size() and governing.all(func(a): return sector.has(a)):
			return i
	return 0


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
