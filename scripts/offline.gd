class_name Offline
extends RefCounted
## What the hero does while the player is away. Before logging out in the
## refuge's bed, the player plans one day for the hero; the hero lives that
## day again and again until the player comes back.
##
## Every REAL_SECONDS_PER_HOUR seconds of real time (10 minutes) is one hour
## for the hero, so one in-game day (24 hours) takes 4 real hours. At most MAX_DAYS
## (8 in-game days = 32 real hours) count; anything longer is wasted.
##
## A day is made of blocks, always lived in this order:
##   job    (Arbeit)    up to JOB_MAX_HOURS: earns gold, trains the body a little.
##   train  (Training)  practise an attribute of the body, or a skill whose
##                       gear is worn. Slow, and follows Training's growth curve.
##   study  (Lernen)    read a book the hero owns: it teaches its skill even
##                       without the gear, and a little Intelligenz.
##   craft  (Handwerk)  make something from RECIPES.
##   rest   (Ruhe)      at least REST_HOURS, every day. Heals the hero.
##   free   (Freizeit)  whatever is left of the 24 hours.
## A day cut short by the player's return is lived from the top, so a short
## absence pays for the job and the training first.
##
## Everything here is pure: plan + hours in, a result out. The game applies
## the result to the hero (see Game._return_from_away).

const REAL_SECONDS_PER_HOUR := 600.0
const DAY_HOURS := 24
const MAX_DAYS := 8
const MAX_REAL_SECONDS := MAX_DAYS * DAY_HOURS * REAL_SECONDS_PER_HOUR
const JOB_MAX_HOURS := 12
const REST_HOURS := 8

## Rates are "share of the first point per hour": for an attribute this is
## Training.ATTRIBUTES[id].first, for a skill Training.SKILL_FIRST. Because
## every further point costs Training.ATTRIBUTE_GROWTH times the one before,
## the same hours buy less and less as the hero grows. Eight days with eight
## hours of training a day earn one point and most of a second for a fresh
## attribute, about what two runs through the dungeon give.
const TRAIN_ATTRIBUTE_RATE := 0.03
const TRAIN_SKILL_RATE := 0.06
const STUDY_SKILL_RATE := 0.05
const STUDY_MIND_RATE := 0.004

## The attributes that can be trained on purpose. Weisheit only grows from
## real experience, Intuition from searching in the dungeon, Intelligenz from
## books (studying) and new discoveries.
const TRAINABLE := ["staerke", "konstitution", "tempo", "geschick"]

## Jobs pay "gold" per hour and train attributes a little ("train": id -> rate).
## "requires": attributes the hero needs for the job.
## TODO: once the village is in the game, jobs can ask for a place there
## (the guard house, the smithy) and only appear after the hero has been there.
const JOBS := {
	"wache": {"name": "Stadtwache", "gold": 3, "train": {"konstitution": 0.005, "staerke": 0.003}},
	"schmiede": {"name": "Gehilfe in der Schmiede", "gold": 2, "train": {"staerke": 0.006}, "requires": {"staerke": 11}},
	"schreiber": {"name": "Schreiber", "gold": 2, "train": {"intelligenz": 0.006}, "requires": {"intelligenz": 11}},
}

## Recipes for the craft block. "hours" makes one piece. "makes" is what one
## piece is: "knife" (a throwing knife) or "repair" (one point of durability
## back on worn-down gear). "train": like jobs.
## TODO: recipes that use materials (ore, leather, herbs) once those exist.
const RECIPES := {
	"messer": {"name": "Wurfmesser schmieden", "hours": 3.0, "makes": "knife", "train": {"geschick": 0.004}},
	"flicken": {"name": "Ausrüstung ausbessern", "hours": 2.0, "makes": "repair", "train": {"geschick": 0.003}},
}

const BLOCKS := ["job", "train", "study", "craft", "rest"]


## A day with nothing planned but sleep.
static func empty_plan() -> Dictionary:
	return {
		"job": "", "job_hours": 0, "train": "", "train_hours": 0,
		"study": "", "study_hours": 0, "craft": "", "craft_hours": 0,
		"rest_hours": REST_HOURS,
	}


## In-game hours for this much real time away (capped at MAX_DAYS days).
static func game_hours(real_seconds: float) -> float:
	return clampf(real_seconds, 0.0, MAX_REAL_SECONDS) / REAL_SECONDS_PER_HOUR


static func planned_hours(plan: Dictionary) -> int:
	var sum := 0
	for block in BLOCKS:
		sum += int(plan.get(block + "_hours", 0))
	return sum


static func free_hours(plan: Dictionary) -> int:
	return DAY_HOURS - planned_hours(plan)


## Training gained per hour of a rate, for an attribute or a skill.
static func xp_per_hour(id: String, rate: float) -> float:
	if Training.is_skill(id):
		return rate * Training.SKILL_FIRST
	return rate * float(Training.ATTRIBUTES[id].first)


## A plan that keeps the rules: a known choice for every block, the job no
## longer than JOB_MAX_HOURS, at least REST_HOURS of rest and no more than a
## day in all. `allowed` maps "job", "train", "study" and "craft" to the
## choices the hero has right now (see Game.away_choices); a block whose
## choice is gone gets no hours. When the day is too full, the blocks at the
## end lose hours first.
static func normalized(plan: Dictionary, allowed: Dictionary) -> Dictionary:
	var out := empty_plan()
	for block in ["job", "train", "study", "craft"]:
		var choice := String(plan.get(block, ""))
		if choice in allowed.get(block, []):
			out[block] = choice
			out[block + "_hours"] = maxi(0, int(plan.get(block + "_hours", 0)))
	out.job_hours = mini(out.job_hours, JOB_MAX_HOURS)
	out.rest_hours = clampi(int(plan.get("rest_hours", REST_HOURS)), REST_HOURS, DAY_HOURS)
	for block in ["rest", "craft", "study", "train", "job"]:
		var over := planned_hours(out) - DAY_HOURS
		if over <= 0:
			break
		var key: String = block + "_hours"
		var floor_hours := REST_HOURS if block == "rest" else 0
		out[key] = maxi(floor_hours, out[key] - over)
	return out


## Lives `hours` in-game hours of the plan (which should be normalized).
## Returns:
##   hours, days: how long the hero was busy
##   spent: block -> hours actually lived ("free" too)
##   gold: earned by the job
##   xp: training id -> amount, before the hero's Weisheit bonus
##   study_xp: training id -> amount that needs no gear (from books)
##   knives, repairs: pieces crafted
static func simulate(plan: Dictionary, hours: float) -> Dictionary:
	var spent := {"job": 0.0, "train": 0.0, "study": 0.0, "craft": 0.0, "rest": 0.0, "free": 0.0}
	var left := maxf(0.0, hours)
	var day: Array = []
	for block in BLOCKS:
		day.append([block, float(plan.get(block + "_hours", 0))])
	day.append(["free", float(free_hours(plan))])
	while left > 0.0001:
		for part in day:
			var h := minf(part[1], left)
			spent[part[0]] += h
			left -= h
			if left <= 0.0001:
				break
	var result := {
		"hours": hours, "days": floori(hours / DAY_HOURS), "spent": spent,
		"gold": 0, "xp": {}, "study_xp": {}, "knives": 0, "repairs": 0,
	}
	if plan.get("job", "") != "" and JOBS.has(plan.job):
		var job: Dictionary = JOBS[plan.job]
		result.gold = floori(spent.job * job.gold)
		_add_rates(result.xp, job.get("train", {}), spent.job)
	if plan.get("train", "") != "":
		var id: String = plan.train
		var rate := TRAIN_SKILL_RATE if Training.is_skill(id) else TRAIN_ATTRIBUTE_RATE
		_add(result.xp, id, xp_per_hour(id, rate) * spent.train)
	if plan.get("study", "") != "" and Items.ALL.has(plan.study):
		var teaches := String(Items.ALL[plan.study].get("teaches", ""))
		if teaches != "":
			_add(result.study_xp, teaches, xp_per_hour(teaches, STUDY_SKILL_RATE) * spent.study)
		_add(result.xp, "intelligenz", xp_per_hour("intelligenz", STUDY_MIND_RATE) * spent.study)
	if plan.get("craft", "") != "" and RECIPES.has(plan.craft):
		var recipe: Dictionary = RECIPES[plan.craft]
		var pieces := floori(spent.craft / recipe.hours)
		if recipe.makes == "knife":
			result.knives = pieces
		elif recipe.makes == "repair":
			result.repairs = pieces
		_add_rates(result.xp, recipe.get("train", {}), spent.craft)
	return result


static func _add_rates(xp: Dictionary, rates: Dictionary, hours: float) -> void:
	for id in rates:
		_add(xp, id, xp_per_hour(id, rates[id]) * hours)


static func _add(xp: Dictionary, id: String, amount: float) -> void:
	if amount > 0.0:
		xp[id] = xp.get(id, 0.0) + amount


## "2 Tage und 5 Stunden", "7 Stunden", "40 Minuten".
static func duration_text(hours: float) -> String:
	var days := floori(hours / DAY_HOURS)
	var rest := floori(hours - days * DAY_HOURS)
	var parts := []
	if days > 0:
		parts.append(Lang.t("1 Tag") if days == 1 else Lang.t("%d Tage") % days)
	if rest > 0:
		parts.append(Lang.t("1 Stunde") if rest == 1 else Lang.t("%d Stunden") % rest)
	if parts.is_empty():
		return Lang.t("%d Minuten") % floori(hours * 60.0)
	return Lang.t(" und ").join(parts)
