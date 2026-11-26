class_name Monastery
extends RefCounted
## The monastery of Nohpaan (see Nohpaan): three monks, each teaching one rare skill of the mountains in three
## lessons. A lesson costs a purse of coins and asks for something the hero has already made their own (a level of
## Klettern, a value of Weisheit or Geschick). The monks never sell a lesson twice and never teach a lesson before
## the one that comes first. What a skill does is small and clear (see the *_bonus functions, read by Player):
##   Bergatem (Mountain Breath, Körper): +1 Klettern for each lesson learned.
##   Stille Mitte (Still Centre, Körper): the hero heals faster, +REGEN_PER_LESSON life a second for each lesson.
##   Windschritt (Wind Step, Gewandtheit): +DODGE_PER_LESSON to dodge a blow or a shot for each lesson.
## The lessons are kept as the skills' training (Training.CRAFTS), so they are saved with the hero, and they show on the
## character page and in the skill trees (see SkillTrees) as soon as the first one is learned.
##
## A monk is a person of the map workshop whose creation has the key "teaches" (see DungeonNpc, Game._use_station):
## running into them says a line and opens their window (Menus._build_monastery).

## The station kind of the window.
const KIND := "klosterlehre"
const MAX_LESSONS := 3
## Copper for each lesson of every skill: a gold coin is 250.
const PRICES := [250, 750, 2000]
const REGEN_PER_LESSON := 0.05
const DODGE_PER_LESSON := 0.04

## The skills: German name (see Lang), what the teaching says, and what each lesson asks for: the "skill" or the
## "attribute" and its value. Keyed by the skill's id (Training.CRAFTS).
const SKILLS := {
	"bergatem": {"name": "Bergatem", "monk": "Bruder Tashi", "tree": "koerper",
		"text": "Wer oben atmet wie unten, kommt nicht hoch. Bruder Tashi lehrt, wie man mit der dünnen Luft des Berges haushält. Jede Lehre macht dich im Fels geschickter: +1 Klettern.",
		"asks": [{"skill": "klettern", "level": 6}, {"skill": "klettern", "level": 8}, {"skill": "klettern", "level": 10}]},
	"stille_mitte": {"name": "Stille Mitte", "monk": "Schwester Dolma", "tree": "koerper",
		"text": "Schwester Dolma lehrt, in sich zu ruhen, auch im Kampf. Der Körper heilt schneller, wenn der Geist still ist: jede Lehre gibt dir 0,05 Leben pro Sekunde mehr.",
		"asks": [{"attribute": "weisheit", "level": 12}, {"attribute": "weisheit", "level": 14}, {"attribute": "weisheit", "level": 16}]},
	"windschritt": {"name": "Windschritt", "monk": "Bruder Pema", "tree": "gewandtheit",
		"text": "Bruder Pema lehrt, einem Schlag zu weichen wie Gras dem Wind. Jede Lehre gibt dir 4 % mehr Chance, einem Hieb oder Schuss auszuweichen.",
		"asks": [{"attribute": "geschick", "level": 13}, {"attribute": "geschick", "level": 15}, {"attribute": "geschick", "level": 17}]},
}

const LEARN := "Die Mönche von Nohpaan: Im Kloster am Ende des Tals lehren drei Mönche seltene Fertigkeiten: Bergatem, Stille Mitte und Windschritt. Jede gibt es in drei Lehren, und jede kostet Gold und etwas, das du schon beherrschst. Wer eine Lehre bezahlt hat, behält sie für immer."


## The lessons of `id` the hero has learned, 0 to MAX_LESSONS.
static func lessons(hero: Player, id: String) -> int:
	return mini(MAX_LESSONS, Training.skill_level(float(hero.xp.get(id, 0.0)), id))


## Whether the hero knows any of the monks' skills yet (they show on the character page from then on).
static func knows_any(hero: Player) -> bool:
	for id in SKILLS:
		if lessons(hero, id) > 0:
			return true
	return false


static func price(lesson: int) -> int:
	return PRICES[clampi(lesson - 1, 0, MAX_LESSONS - 1)]


## What lesson number `lesson` (1 to 3) of `id` still asks for the hero: a text, or "" when they have it all.
static func missing(hero: Player, id: String, lesson: int) -> String:
	var ask: Dictionary = SKILLS[id].asks[lesson - 1]
	if ask.has("skill"):
		if hero.trained_level(ask.skill) < int(ask.level):
			return Lang.t("%s %d") % [Lang.t(Training.SKILLS[ask.skill].name), int(ask.level)]
	elif hero.attribute(ask.attribute) < int(ask.level):
		return Lang.t("%s %d") % [Lang.t(Training.ATTRIBUTES[ask.attribute].name), int(ask.level)]
	return ""


## Why the hero cannot learn the next lesson of `id` now ("" when they can).
static func why_not(game: Node, id: String) -> String:
	var hero: Player = game.player
	var next := lessons(hero, id) + 1
	if next > MAX_LESSONS:
		return Lang.t("Du hast alles gelernt, was er lehren kann.")
	var need := missing(hero, id, next)
	if need != "":
		return Lang.t("Dafür brauchst du %s.") % need
	if not Payment.can_pay(game, price(next)):
		return Lang.t("Dafür fehlt dir das Gold.")
	return ""


## Pays for and learns the next lesson of `id`. Returns the reason it did not happen ("" when it did).
static func learn(game: Node, id: String) -> String:
	var why := why_not(game, id)
	if why != "":
		return why
	var hero: Player = game.player
	var next := lessons(hero, id) + 1
	Payment.pay(game, price(next))
	hero.xp[id] = Training.skill_xp_for(next)
	# A skill the night holds back (see SleepRoll) is not held back here: the monks teach it in one go.
	if hero.sleep_state.skills.has(id):
		hero.sleep_state.skills[id].earned = next
	hero.trained.emit(id, next)
	hero.refresh_stats()
	Training.save_hero(game.hero_name, hero.xp, hero.level_data())
	Sfx.play(game, "secret", -4.0)
	Events.teach(LEARN)
	Events.found(Lang.t("%s: Lehre %d gelernt.") % [Lang.t(SKILLS[id].name), next], Color(1.0, 0.85, 0.45))
	Events.bus().lesson_learned.emit(id, next)
	game._update_hud()
	return ""


# --- What the lessons do -------------------------------------------------------------------------------

static func climb_bonus(hero: Player) -> int:
	return lessons(hero, "bergatem")


static func regen_bonus(hero: Player) -> float:
	return REGEN_PER_LESSON * lessons(hero, "stille_mitte")


static func dodge_bonus(hero: Player) -> float:
	return DODGE_PER_LESSON * lessons(hero, "windschritt")
