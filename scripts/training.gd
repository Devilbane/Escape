class_name Training
extends RefCounted
## How the hero grows by doing things. Two kinds of values are trained:
##
## Attributes (Eigenschaften) belong to the hero's body. Fighting makes them
## stronger, taking blows makes them tougher, running makes them faster. They
## grow very slowly: a whole run through the dungeon earns about one point,
## and every point costs ATTRIBUTE_GROWTH times as much as the one before.
##   Stärke (strength) 10..30: +1 damage in close combat per point, and
##     loads weigh less.
##   Konstitution (constitution) 10..30: +1 Leben per point.
##   Tempo (speed) 100 %..150 %, in steps of 5 %.
##   Intuition 10..30: a feeling for how things work. Searching and coming
##     close to secret levers train it; each point is +2 % to notice a lever.
##     Traps to find and liars to see through can ask it later too.
##   Geschick (dexterity) 10..30: jumping, throwing and spike traps train it;
##     each point is +1 damage with thrown knives (in place of Stärke), 4 %
##     chance to dodge a blow or a shot (up to Player.DODGE_MAX) and to slip
##     past spikes, and makes running jumps 2 % longer. Locks and disarming
##     traps can ask it later too.
##   Weisheit (wisdom) 10..30: grows from going through things, whatever
##     the outcome: finishing a level, finding the key or a secret, choosing
##     at a shrine, and the end of every run, fallen or free. Each point makes
##     all other training 5 % quicker, and from WISE_SHRINE on the shrines
##     offer a fourth gift.
##   Intelligenz (intelligence) 10..30: grows from understanding things
##     (every new entry in the compendium) and from beating skeleton mages.
##     Each point makes skills and crafts train 10 % quicker and adds 3 % to
##     all experience (EP), riddles included.
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
##   Erkunden (exploring): needs no gear. It grows when the hero has seen a
##   whole map (see Journal.note_full_map), and a little from every secret
##   room and wall writing found. Each level is +EXPLORE_SECRET % to notice a
##   secret lever, +EXPLORE_TORCH % to find a torch in a searched chest,
##   barrel or crate, +EXPLORE_WRITING % to notice a writing on a wall and
##   +EXPLORE_TRAP % to spot a hidden trap (see Traps).
##
## Every skill is governed by one or two of the three main attributes
## ("attributes"); that places it in one of the six SECTORS of the character
## page. A roll on a skill (skill_chance) uses their average.
## A basic skill sits in the inner ring, right around the attributes. An
## advanced skill has "needs" (basic skill id -> level): it sits in the outer
## ring and can only be used and learned once those levels are reached.
const SKILLS := {
	"klingen": {"name": "Klingen", "attributes": ["staerke", "geschick"]},
	"aexte": {"name": "Äxte", "attributes": ["staerke"]},
	"werfen": {"name": "Messerwurf", "attributes": ["geschick"]},
	"blocken": {"name": "Blocken", "attributes": ["staerke", "geschick"]},
	"ruestung": {"name": "Rüstung tragen", "attributes": ["staerke"]},
	"schleichen": {"name": "Schleichen", "attributes": ["geschick", "intelligenz"]},
	"erkunden": {"name": "Erkunden", "attributes": ["intelligenz"]},
}
## What a level of Erkunden is worth, in percent (see SKILLS).
const EXPLORE_SECRET := 3
const EXPLORE_TORCH := 4
const EXPLORE_WRITING := 8
const EXPLORE_TRAP := 3
## Training for Erkunden: a whole map seen, a secret room, a wall writing.
## Use weights as in the use table (a whole map is 150 uses, a wall writing 30).
const EXPLORE_FULL_MAP := 150.0
const EXPLORE_SECRET_FOUND := 20.0
const EXPLORE_WRITING_FOUND := 30.0
## Training for Erkunden from a hidden trap spotted (see Traps).
const EXPLORE_TRAP_FOUND := 10.0
## The crafts (Handwerk): making things at a workbench, from recipes (see
## Crafting). A craft is taught by a master in the village first and then
## trains only by working at it; it is not worn gear that enables it. Crafts
## level like basic skills (up to SKILL_MAX) and are kept with the skills,
## but they are not part of the wheel of combat skills on the character page.
const CRAFTS := {
	"feinschmieden": {"name": "Feinschmieden", "attributes": ["geschick", "intelligenz"]},
	# At Gorm's forge (see Forge.FORGING, Forge.STEEL_MAKING): forging grows
	# with every piece forged, steel making with every melt and steel bar.
	"schmiedekunst": {"name": "Schmiedekunst", "attributes": ["staerke"]},
	"stahlkochen": {"name": "Stahlkochen", "attributes": ["intelligenz"]},
	# At the alchemist's table on the crafting square: brewing healing
	# potions (see HealingPotions), stronger with more of it.
	"alchemie": {"name": "Alchemie", "attributes": ["intelligenz"]},
	# From the grimoire in the Ashen Spire (see AshSpire): the arcane bolt.
	"magie": {"name": "Arkane Energie", "attributes": ["intelligenz"]},
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
## What a level of a skill costs in uses (one landed blow is one use, see the
## use weights in Player, Forge, Crafting and Training.EXPLORE_*): level 1 costs
## SKILL_FIRST, each further level SKILL_GROWTH times the one before up to
## level SKILL_EARLY, and SKILL_GROWTH_LATE times from there to level 20. Level
## 5 is 1,156 uses in all, level 10 is 11,497 and level 20 is 92,694 (the
## progression research, section 6). The game lets training reach SKILL_MAX
## (10) for now; the levels above it are the Geselle rank, to come with the
## trees.
const SKILL_FIRST := 80.0
const SKILL_GROWTH := 1.55
const SKILL_GROWTH_LATE := 1.12
const SKILL_EARLY := 10
## The most levels the table has for a basic skill.
const SKILL_TABLE_MAX := 20


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


## Training that falls short of a level by less than this (rounding, a save
## file's shortened decimals) still counts as having reached it.
const SKILL_EPSILON := 0.001


static func skill_level(xp: float, id := "") -> int:
	var cap := skill_max(id)
	xp += SKILL_EPSILON
	var n := 0
	while n < cap and xp >= skill_step_cost(n):
		xp -= skill_step_cost(n)
		n += 1
	return n


static func skill_progress(xp: float, id := "") -> float:
	var cap := skill_max(id)
	xp += SKILL_EPSILON
	var n := 0
	while n < cap and xp >= skill_step_cost(n):
		xp -= skill_step_cost(n)
		n += 1
	return 1.0 if n >= cap else maxf(0.0, xp - SKILL_EPSILON) / skill_step_cost(n)


## The training a skill needs in all to stand at `level`.
static func skill_xp_for(level: int) -> float:
	var total := 0.0
	for i in level:
		total += skill_step_cost(i)
	return total


## What the step from `level` to the next one costs in training.
static func skill_step_cost(level: int) -> float:
	var n := level + 1
	return SKILL_FIRST * pow(SKILL_GROWTH, mini(n, SKILL_EARLY) - 1) * pow(SKILL_GROWTH_LATE, maxi(0, n - SKILL_EARLY))


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


## The cost table a hero's training was counted in, kept beside it under
## CURVE_KEY. A hero saved before the key was written (curve 1) was counted
## in the old table, 8 uses for the first level, each level 1.45 times the
## last; load_hero turns such training into the new table, level for level.
const CURVE_KEY := "_kurve"
const CURVE := 2
const OLD_SKILL_FIRST := 8.0
const OLD_SKILL_GROWTH := 1.45


## The same level, and the same share of the way to the next, in the new
## table, for training counted in the old one.
static func skill_from_old_table(xp: float, id: String) -> float:
	var cap := skill_max(id)
	var level := points(xp, OLD_SKILL_FIRST, OLD_SKILL_GROWTH, cap)
	var share := progress(xp, OLD_SKILL_FIRST, OLD_SKILL_GROWTH, cap)
	if level >= cap:
		return skill_xp_for(cap)
	return skill_xp_for(level) + share * skill_step_cost(level)


## What the hero with this name has trained so far (empty for a new hero).
static func load_hero(hero: String) -> Dictionary:
	var all := _load_all()
	var xp := {}
	var stored = all.get(hero, {})
	if stored is Dictionary:
		var old_table: bool = int(stored.get(CURVE_KEY, 1)) < CURVE
		for id in stored:
			if ATTRIBUTES.has(id) or SKILLS.has(id) or CRAFTS.has(id):
				xp[id] = float(stored[id])
				if old_table and not ATTRIBUTES.has(id):
					xp[id] = skill_from_old_table(xp[id], id)
	return xp


## The hero's level and experience (see Player.level_data), kept beside the
## training under LEVEL_KEY.
const LEVEL_KEY := "_heldenstufe"


static func load_level(hero: String) -> Dictionary:
	var stored = _load_all().get(hero, {})
	if stored is Dictionary and stored.get(LEVEL_KEY) is Dictionary:
		return stored[LEVEL_KEY]
	return {}


## Saves the training, and the level with it. Without `level` the level kept
## so far stays as it is.
## Off while a map is tested in the workshop (see Game.playtest_file): what
## the test hero learns is not kept.
static var keep := true


static func save_hero(hero: String, xp: Dictionary, level = null) -> void:
	if not keep:
		return
	var all := _load_all()
	var old = all.get(hero, {})
	var entry := xp.duplicate()
	entry[CURVE_KEY] = CURVE
	if level is Dictionary:
		entry[LEVEL_KEY] = level
	elif old is Dictionary and old.has(LEVEL_KEY):
		entry[LEVEL_KEY] = old[LEVEL_KEY]
	all[hero] = entry
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(all))
