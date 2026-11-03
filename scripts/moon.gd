class_name Moon
extends RefCounted
## The moon over the world above ground. It runs through its phases in
## CYCLE nights, one phase a night, counted like the days (see Game.day: the
## night after day d's evening, past midnight too, is night d).
##
## Two nights of the cycle change the world (see Outdoor):
## - Full moon: the wolves hunt in a pack through the wolf hollow, and a
##   pale moon flower opens beside the hollow's pond (an ingredient, see
##   Crafting).
## - New moon: the dark holes breathe, and a nameless horror (see Horrors)
##   crawls out of the hole nearest the village and lurks closer to it.
## The nights in between are bright or dark as the moon waxes and wanes, the
## HUD clock names the moon at night, and the journal says what tonight's
## moon brings, so the player can plan a flower run or stay home.
##
## Everything here is pure: which phase a night has, what it is called and
## what it brings.

## Nights in one round of the moon.
const CYCLE := 8
## The phases, from new moon round to the waning crescent (German, translated
## by Lang).
const PHASES := [
	"Neumond", "zunehmende Sichel", "zunehmender Halbmond", "zunehmender Mond",
	"Vollmond", "abnehmender Mond", "abnehmender Halbmond", "abnehmende Sichel",
]
const NEW := 0
const FULL := 4
## Written into the compendium's knowledge the first time a full or a new
## moon rises over the hero.
const LORE := "Der Mond: Alle acht Nächte wird er einmal voll und einmal dunkel. Bei Vollmond jagen die Wölfe im Rudel durch die Wolfssenke, und am Tümpel öffnet sich die seltene Mondblume. Bei Neumond atmen die dunklen Löcher, und ein Grauen kriecht näher ans Dorf. Was der Mond heute Nacht bringt, steht oben im Tagebuch (Karte und Tagebuch, Taste N)."
## Night 0, the first night of a new game, has this phase: a thin crescent,
## so the first full moon comes on night 3 and the first new moon on night 7.
const FIRST_PHASE := 1
## How bright the moonlight is at night, new moon to full moon (a factor on
## the night sky's own light, see DayNight: its night is the full moon's).
## The moon is the only light of the night, so a new moon leaves the open
## air nearly pitch black, only the shapes of things to be made out: only
## lanterns, windows, fires and torches light it.
const DARKEST := 0.04
const BRIGHTEST := 1.0
## How steeply the light falls off from the full moon: a thin crescent is
## almost as dark as no moon at all, the half moon only dimly lit.
const FALLOFF := 1.6


## The phase of a night, 0 (new moon) to CYCLE - 1.
static func phase(night: int) -> int:
	return posmod(night + FIRST_PHASE, CYCLE)


static func is_full(night: int) -> bool:
	return phase(night) == FULL


static func is_new(night: int) -> bool:
	return phase(night) == NEW


## The moon's name on a night (German, translated by Lang).
static func word(night: int) -> String:
	return PHASES[phase(night)]


## How bright the moon shines on a night: DARKEST at new moon, BRIGHTEST at
## full moon, falling off steeply in between (see FALLOFF).
static func light(night: int) -> float:
	var t := pow((1.0 - cos(TAU * phase(night) / CYCLE)) * 0.5, FALLOFF)
	return lerpf(DARKEST, BRIGHTEST, t)


## How many nights from `night` until the next night of a phase (0: tonight).
static func nights_until(night: int, which: int) -> int:
	return posmod(which - phase(night), CYCLE)


## What tonight's moon brings, for the journal, in the player's language.
static func forecast(night: int) -> String:
	if is_full(night):
		return Lang.t("Die Wölfe jagen im Rudel durch die Wolfssenke, und am Tümpel öffnet sich die Mondblume.")
	if is_new(night):
		return Lang.t("Die dunklen Löcher atmen, und ein Grauen kriecht näher ans Dorf. Bleib besser zu Hause.")
	var full := nights_until(night, FULL)
	var dark := nights_until(night, NEW)
	if full < dark:
		return Lang.t("Noch %d Nächte bis Vollmond.") % full if full > 1 else Lang.t("Morgen Nacht ist Vollmond.")
	return Lang.t("Noch %d Nächte bis Neumond.") % dark if dark > 1 else Lang.t("Morgen Nacht ist Neumond.")
