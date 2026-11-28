class_name Fame
extends RefCounted
## What the hero is known for: four ratings, each with a level, a title and a few words on how to climb on.
## They are shown on the "Fame" page of the quests window (see FamePage).
##
##   hero         Regional Hero Level: tasks finished and riddles solved in the region.
##   richness     Richness: what the hero owns in the region: coins and goods (see Wealth, the bank included),
##                land and the house (see Plots, PropertyRegister).
##   crafts       Mastery of Crafts: how the hero's best skills measure up against the masters of the region (MASTERS).
##   exploration  Exploration: the share of all the game's squares the hero has uncovered (see Journal).
##
## A rating is a number (its "value") and the steps of that number (THRESHOLDS): the level is how many steps the value
## has passed. Hero, crafts and exploration are shares from 0 to 1, richness is copper.
##
## Regions: Apple Valley is the only one for now. A region is a key of REGIONS; a task, a riddle or a master names its
## region with a "region" key (none: DEFAULT_REGION), so a new region needs its entry here, its own tasks and masters,
## and its titles in the lang file. The exploration rating counts the whole game, whatever the region.
## Skills are read through `skill_level`, the one place that knows how a skill level is asked of the player.

const DEFAULT_REGION := "apfeltal"
## The regions: key -> the name shown (German, translated when shown).
const REGIONS := {"apfeltal": "Apfeltal"}

const IDS := ["hero", "richness", "crafts", "exploration"]
const MAX_LEVEL := 5

## A riddle is worth this many finished tasks for the Regional Hero.
const RIDDLE_POINTS := 2
## What a square metre of a built house is worth, in copper (land is worth its deed fee, see Plots.fee).
const HOUSE_PER_SQM := 40

## What the value must reach for level 1, 2, 3, 4 and 5 (level 1 is where everybody starts).
const THRESHOLDS := {
	"hero": [0.0, 0.1, 0.3, 0.55, 0.8],
	"richness": [0.0, 400.0, 2000.0, 8000.0, 30000.0],
	"crafts": [0.0, 0.15, 0.4, 0.7, 1.0],
	"exploration": [0.0, 0.05, 0.15, 0.35, 0.6],
}
## How many of the hero's best skills count for the Mastery of Crafts, and how far one may count past its master.
const BEST_SKILLS := 3

## The masters of a region, whom the hero's skills are measured against: {"role" the villager (see Villager.ROLES),
## "skill" a skill or craft of Training, "level" how well they know it, "region"}.
const MASTERS := [
	{"role": "1", "skill": "schmiedekunst", "level": 8},
	{"role": "1", "skill": "stahlkochen", "level": 6},
	{"role": "κ", "skill": "klettern", "level": 9},
	{"role": "ρ", "skill": "erkunden", "level": 8},
	{"role": "8", "skill": "alchemie", "level": 7},
	{"role": "G", "skill": "aexte", "level": 9},
]

## The titles of the levels 1 to 5, the names and the hints of the ratings (German, translated when shown).
const NAMES := {"hero": "Regionale Heldenstufe", "richness": "Reichtum", "crafts": "Meisterschaft im Handwerk", "exploration": "Entdeckergeist"}
const TITLES := {
	"hero": ["Neuankömmling", "Helfende Hand", "Held des Dorfes", "Stolz des Tals", "Legende des Tals"],
	"richness": ["Habenichts", "Genügsam", "Wohlhabend", "Gutsherr", "Magnat des Tals"],
	"crafts": ["Lehrling", "Geselle", "Geachteter Handwerker", "Meisterhand", "Großmeister"],
	"exploration": ["Stubenhocker", "Wanderer", "Pfadfinder", "Wegbereiter", "Stolz der Kartenmacher"],
}
const HINTS := {
	"hero": "Hilf den Leuten bei ihren Aufträgen und löse die Rätsel des Tals.",
	"richness": "Verdiene Münzen, kaufe Land und baue ein Haus: Was du im Tal besitzt, zählt.",
	"crafts": "Übe deine besten Fertigkeiten, bis du es mit den Meistern des Tals aufnehmen kannst.",
	"exploration": "Geh jeden Pfad, jede Höhle und jede Halle ab: Jedes neue Feld auf deiner Karte zählt.",
}
const DONE := {
	"hero": "Alle im Tal kennen deinen Namen. Es gibt keine höhere Ehre.",
	"richness": "Niemand im Tal besitzt mehr als du.",
	"crafts": "Selbst die Meister holen sich Rat bei dir.",
	"exploration": "Du kennst jeden Winkel. Die Karte ist dein Werk.",
}

## The total of explorable squares of the game, worked out once (it only changes with the maps).
static var _explorable := -1


## The level (1 to MAX_LEVEL) a value of a rating has reached.
static func level_for(id: String, value: float) -> int:
	var level := 1
	var steps: Array = THRESHOLDS[id]
	for i in steps.size():
		if value >= float(steps[i]):
			level = i + 1
	return level


## How far a value is on the way from its level to the next, 0 to 1 (1 at the top level).
static func progress_for(id: String, value: float) -> float:
	var level := level_for(id, value)
	if level >= MAX_LEVEL:
		return 1.0
	var steps: Array = THRESHOLDS[id]
	var from := float(steps[level - 1])
	var to := float(steps[level])
	return clampf((value - from) / (to - from), 0.0, 1.0)


## A hero's skill level as the masters know it: what was trained (worn gear does not count, a skill of a sword
## does not vanish when the sword is put away).
static func skill_level(player: Player, id: String) -> int:
	return player.trained_level(id)


static func skill_name(id: String) -> String:
	if Training.SKILLS.has(id):
		return Lang.t(Training.SKILLS[id].name)
	if Training.CRAFTS.has(id):
		return Lang.t(Training.CRAFTS[id].name)
	return id


## The tasks of a region that count, as {"done", "total"}.
static func quests_in(region: String, quests: Quests) -> Dictionary:
	var done := 0
	var total := 0
	for id in Quests.ALL:
		if str(Quests.ALL[id].get("region", DEFAULT_REGION)) != region:
			continue
		total += 1
		if quests.is_done(id):
			done += 1
	return {"done": done, "total": total}


## Regional Hero Level: tasks finished and riddles solved, as a share of all there is to finish and solve in the region.
static func hero(region: String, quests: Quests, riddles: RiddleCount) -> Dictionary:
	var q := quests_in(region, quests)
	var solved := riddles.count()
	var points := int(q.done) + solved * RIDDLE_POINTS
	var total := int(q.total) + RiddleCount.TOTAL * RIDDLE_POINTS
	return {"value": float(points) / maxf(1.0, float(total)), "quests": int(q.done), "quests_total": int(q.total),
			"riddles": solved, "riddles_total": RiddleCount.TOTAL}


## What the land and the house of a hero are worth, in copper: {"land", "house"}.
static func property_worth(hero_name: String) -> Dictionary:
	var land := 0
	for deed in Plots.plots_of(hero_name):
		land += Plots.fee(deed.rect)
	var house := 0
	var plot := Plots.plot_of(hero_name)
	if plot.size != Vector2i.ZERO:
		var sketch := HouseSketch.of(hero_name, plot)
		if PropertyRegister.has_house(sketch):
			var areas := PropertyRegister.house_areas(sketch)
			house = (int(areas.ground) + int(areas.cellar) + int(areas.roof)) * HOUSE_PER_SQM
	return {"land": land, "house": house}


## Richness: coins and goods (everything the wealth tracker counts) plus land and house, in copper.
static func richness(game: Node) -> Dictionary:
	var goods: int = int(Wealth.compute(game).total)
	var property := property_worth(game.hero_name)
	return {"value": float(goods + int(property.land) + int(property.house)), "goods": goods,
			"land": int(property.land), "house": int(property.house)}


## The skills of the region's masters, and how far the hero is in each: {"role", "skill", "level", "own", "ratio"},
## the best ratio first. A hero as good as the master has a ratio of 1.
static func standings(region: String, player: Player) -> Array:
	var out: Array = []
	for m in MASTERS:
		if str(m.get("region", DEFAULT_REGION)) != region:
			continue
		var own := skill_level(player, m.skill)
		out.append({"role": m.role, "skill": m.skill, "level": int(m.level), "own": own,
				"ratio": clampf(float(own) / float(m.level), 0.0, 1.0)})
	out.sort_custom(func(a, b): return float(a.ratio) > float(b.ratio))
	return out


## Mastery of Crafts: the average of the hero's best BEST_SKILLS ratios against the masters.
static func crafts(region: String, player: Player) -> Dictionary:
	var list := standings(region, player)
	var sum := 0.0
	for i in mini(BEST_SKILLS, list.size()):
		sum += float(list[i].ratio)
	return {"value": sum / float(BEST_SKILLS), "best": list[0] if not list.is_empty() else {}}


## How many squares of the game's maps can be uncovered (the ground one can stand on, see Level.explore_cells).
static func explorable(journal: Journal, files: Array) -> int:
	if _explorable < 0:
		var n := 0
		for file in files:
			var info := journal.map_of(file)
			if not info.is_empty():
				n += (info.cells as Array).size()
		_explorable = n
	return _explorable


## Exploration: the share of every explorable square of every map the hero has uncovered.
static func exploration(game: Node) -> Dictionary:
	var files: Array = []
	for path in game.level_files:
		files.append(path.get_file())
	var total := explorable(game.journal, files)
	var seen := 0
	for file in files:
		var info: Dictionary = game.journal.map_of(file)
		if info.is_empty() or (info.cells as Array).is_empty():
			continue
		seen += roundi(game.journal.explored_share(file) * (info.cells as Array).size())
	return {"value": float(seen) / maxf(1.0, float(total)), "seen": seen, "total": total}


## The four ratings of a hero in a region, in the order of IDS. Each is
## {"id", "name", "level", "title", "next" (title of the next level, "" at the top), "progress" (0 to 1), "detail", "hint"},
## all of them text that is already translated.
static func ratings(game: Node, region := DEFAULT_REGION) -> Array:
	var out: Array = []
	for id in IDS:
		var data: Dictionary
		var detail := ""
		match id:
			"hero":
				data = hero(region, game.quests, game.riddles)
				detail = Lang.t("%d von %d Aufträgen, %d von %d Rätseln") % [data.quests, data.quests_total, data.riddles, data.riddles_total]
			"richness":
				data = richness(game)
				detail = Lang.t("Besitz: %s Kupfer (Land %s, Haus %s)") % [Wealth.grouped(int(data.value)), Wealth.grouped(int(data.land)), Wealth.grouped(int(data.house))]
			"crafts":
				data = crafts(region, game.player)
				var best: Dictionary = data.best
				if best.is_empty():
					detail = Lang.t("Noch keine Meister im Tal.")
				else:
					detail = Lang.t("Am besten: %s %d, Meister %s: %d") % [skill_name(best.skill), best.own, Quests.villager_name(best.role), best.level]
			"exploration":
				data = exploration(game)
				detail = Lang.t("%d von %d Feldern aufgedeckt (%d %%)") % [data.seen, data.total, roundi(float(data.value) * 100.0)]
		var level := level_for(id, float(data.value))
		var titles: Array = TITLES[id]
		out.append({"id": id, "name": Lang.t(NAMES[id]), "level": level, "title": Lang.t(titles[level - 1]),
				"next": Lang.t(titles[level]) if level < MAX_LEVEL else "",
				"progress": progress_for(id, float(data.value)), "detail": detail,
				"hint": Lang.t(HINTS[id]) if level < MAX_LEVEL else Lang.t(DONE[id])})
	return out
