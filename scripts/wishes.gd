class_name Wishes
extends RefCounted
## Wishes: the hero brings a master an item they want, and the master answers
## with a quest that fits it; the reward is the recipe (see Crafting). Which
## wishes a master puts first follows how the hero likes to fight:
##   - the fighting style the hero names when Guild Master Ragna asks (once,
##     the first time they meet; it can be changed in her wish window), and
##   - the combat skills the hero actually trains (Training.SKILLS): a skill
##     only trains while it is used, so its level shows the hero's real style.
## A wish's weight is the best of the skills it fits (see fit_score): one
## plus the trained level, plus STATED_BONUS for the named style. So the
## named style leads at first, and what the hero really does takes over as
## the skills grow. Each wish has a hint the master gives when the hero
## finishes another wish: it points at the next one that fits best.
##
## A wish's quest lives in Quests.ALL with "wish": true. Those quests are
## never offered by simply running into the master; they start here, when
## the hero picks the wish. The chosen style and which masters' wish windows
## were seen are kept in the hero's saved game.

## The fighting styles Ragna asks about, in the order she lists them: the
## combat skill each stands for, the answer's words, and what she says back.
## Every text is German and has an English entry in Lang.
const STYLES := {
	"klingen": {"name": "Mit dem Schwert", "say": "Eine gute Klinge, eine ruhige Hand. Daraus lässt sich etwas machen."},
	"aexte": {"name": "Mit der Axt", "say": "Wuchtig und direkt. Eine Axt fragt nicht lange."},
	"blocken": {"name": "Hinter dem Schild", "say": "Wer steht, gewinnt. Ein guter Schild ist mehr wert als zehn Schwerter."},
	"werfen": {"name": "Mit Wurfmessern", "say": "Aus der Ferne, bevor sie dich erreichen. Klug."},
	"schleichen": {"name": "Aus den Schatten", "say": "Ungesehen und leise. Die Skelette werden dich nicht kommen hören."},
	"ruestung": {"name": "In schwerer Rüstung", "say": "Stahl auf dem Leib, und die Schläge prallen ab. Gut so."},
}
## How much the named style adds to the weight of the skill it stands for.
const STATED_BONUS := 4
## The masters who take wishes: role letter -> what they say when they open
## their wish window. Guild Master Ragna also asks the fighting style.
const MASTERS := {
	"G": {"ask": "Du kämpfst gut. Sag mir, was du dir wünschst, und ich sage dir, was du dafür tun musst."},
}
## The villager who asks how the hero likes to fight.
const STYLE_ASKER := "G"
## The standing (Reputation level) a master needs before they help with a wish.
const STANDING := 1
## What a master says while they do not know the hero well enough yet.
const NOT_YET := "Ich kenne dich noch kaum. Hilf erst den Leuten im Dorf, dann reden wir über Wünsche."

## The wishes: the master who helps with it, the item and its effect in
## words, the combat skills it fits, the quest (Quests.ALL, "wish": true)
## that earns it, and the hint the master gives to point the hero at it.
const ALL := {
	"klingenring": {"master": "G", "fits": ["klingen"], "quest": "wunsch_klingen",
		"wish": "Ein Ring, der deine Klinge führt",
		"hint": "Für eine Klinge wie deine kenne ich einen Ring aus Mondsilber, der die Hand führt. Frag mich danach."},
	"axtreif": {"master": "G", "fits": ["aexte"], "quest": "wunsch_aexte",
		"wish": "Ein Armreif, der die Axt schwerer fallen lässt",
		"hint": "Wer die Axt liebt, braucht einen Armreif aus Eisen und Höhlenpilzasche. Ich weiß, wie man ihn macht."},
	"schildamulett": {"master": "G", "fits": ["blocken"], "quest": "wunsch_blocken",
		"wish": "Ein Amulett, das deinen Schild fester macht",
		"hint": "Hinter einem Schild kämpft es sich besser mit dem Amulett des Walls. Ich zeige dir, wie es geht."},
	"wurfring": {"master": "G", "fits": ["werfen"], "quest": "wunsch_werfen",
		"wish": "Ein Ring für einen ruhigen Wurf",
		"hint": "Für deine Wurfmesser gibt es einen Ring aus Silberhechtschuppen, der die Hand ruhig hält. Frag mich danach."},
	"schattenamulett": {"master": "G", "fits": ["schleichen"], "quest": "wunsch_schleichen",
		"wish": "Ein Amulett für leise Schritte",
		"hint": "Wer aus den Schatten kämpft, sollte das Amulett der stillen Schritte tragen. Ich weiß, wo die Zutaten liegen."},
	"lastreif": {"master": "G", "fits": ["ruestung"], "quest": "wunsch_ruestung",
		"wish": "Ein Armreif, der schwere Rüstung leichter macht",
		"hint": "Schwere Rüstung wiegt leichter mit dem Armreif der leichten Last. Ich kann dir sagen, wie man ihn schmiedet."},
}

var game: Node
## The fighting style the hero named (a key of STYLES), or "" before Ragna asked.
var style := ""
## Masters whose wish window the hero has seen: their "!" is gone afterwards.
var seen: Array[String] = []


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	style = ""
	seen.clear()


## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return {"style": style, "seen": Array(seen)}


## Back from the saved game; unknown styles and masters are left out, and
## older saved games start with no style named.
func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	if STYLES.has(str(saved.get("style", ""))):
		style = str(saved.style)
	var saved_seen = saved.get("seen", [])
	if saved_seen is Array:
		for role in saved_seen:
			if MASTERS.has(str(role)) and not seen.has(str(role)):
				seen.append(str(role))


## The hero names a fighting style. False for an unknown one.
func choose_style(id: String) -> bool:
	if not STYLES.has(id):
		return false
	style = id
	return true


# --- Weighing what fits ------------------------------------------------------

## How much a combat skill counts when a master picks what to offer first:
## one, plus the level the hero trained it to, plus STATED_BONUS when it is
## the style the hero named.
func skill_weight(skill: String) -> int:
	var xp: Dictionary = game.player.xp if game != null and game.player != null else {}
	var level := Training.skill_level(float(xp.get(skill, 0.0)), skill)
	return 1 + level + (STATED_BONUS if skill == style else 0)


## How well a wish fits the hero: the weight of the best skill it fits.
func fit_score(id: String) -> int:
	var best := 0
	for skill in ALL[id].fits:
		best = maxi(best, skill_weight(skill))
	return best


## The hero's strongest style right now: the skill with the highest weight
## among the styles, the named style first when they tie.
func leading_style() -> String:
	var best := ""
	var best_weight := -1
	var order: Array = STYLES.keys()
	if style != "":
		order.erase(style)
		order.push_front(style)
	for skill in order:
		var w := skill_weight(skill)
		if w > best_weight:
			best = skill
			best_weight = w
	return best


## The quest of a wish has been asked for (running or done).
func taken(id: String) -> bool:
	var quest: String = ALL[id].quest
	return game.quests.is_active(quest) or game.quests.is_done(quest)


## A master's wishes the hero has not asked for yet, best fit first (ties
## keep the order of ALL).
func open_wishes(role: String) -> Array:
	var ids := ALL.keys().filter(func(id): return ALL[id].master == role and not taken(id))
	var order := ALL.keys()
	ids.sort_custom(func(a, b):
		var fa := fit_score(a)
		var fb := fit_score(b)
		return fa > fb if fa != fb else order.find(a) < order.find(b))
	return ids


## The master's wish whose quest is running, or "".
func running(role: String) -> String:
	for id in ALL:
		if ALL[id].master == role and game.quests.is_active(ALL[id].quest):
			return id
	return ""


## Whether a master thinks well enough of the hero to help with a wish.
func willing(role: String) -> bool:
	return game.reputation.level(role) >= STANDING


## Whether a wish fits the hero's style better than the rest of the
## master's open wishes do: it is first and fits a style the hero leans to.
func is_best_fit(id: String) -> bool:
	var role: String = ALL[id].master
	var open := open_wishes(role)
	return not open.is_empty() and open[0] == id and fit_score(id) > 1


## The hint a master gives after a wish is done: the open wish that fits
## best now, or "" when there is none left.
func next_hint(role: String) -> String:
	var open := open_wishes(role)
	return "" if open.is_empty() else Lang.t(ALL[open[0]].hint)


# --- Villagers -----------------------------------------------------------------

## "!" over a master who has never shown the hero their wishes, or over the
## one who asks the style before it was named; "" otherwise.
func mark(role: String) -> String:
	if not MASTERS.has(role) or running(role) != "":
		return ""
	if role == STYLE_ASKER and style == "":
		return "!"
	if not seen.has(role) and willing(role) and not open_wishes(role).is_empty():
		return "!"
	return ""


## The hero ran into a villager. The one who asks the style asks it first;
## a master with open wishes, who is willing and has no wish running,
## opens their wish window. True when something happened.
func talk(v: Villager) -> bool:
	var role := v.role
	if not MASTERS.has(role) or running(role) != "":
		return false
	if role == STYLE_ASKER and style == "":
		v.meet()
		game.menus.open("kampfstil")
		return true
	if open_wishes(role).is_empty():
		return false
	if not willing(role):
		v.meet()
		v.say(Lang.t(NOT_YET), game.player.global_position)
		return true
	v.meet()
	if not seen.has(role):
		seen.append(role)
	game.menus.wish_master = role
	game.menus.open("wunsch")
	return true


## The hero picked a wish in the master's window: its quest starts. Returns
## "" on success, else why not.
func ask(id: String, v: Villager) -> String:
	if not ALL.has(id) or taken(id):
		return Lang.t("Darum hast du schon gebeten.")
	var role: String = ALL[id].master
	if running(role) != "":
		return Lang.t("Erst den laufenden Wunsch, dann einen neuen.")
	game.quests.start_wish(ALL[id].quest, v)
	return ""
