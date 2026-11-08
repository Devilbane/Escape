class_name VillageRun
extends RefCounted
## The run to the village: a hero who steps out of the crypt door is safe from
## every harm for TIME seconds, so the way through the forest to the village
## can be walked in peace. It is a boon (Player.ailments[KIND], shown with a
## countdown in the boon row, see Game.hero_boons), it does not stack (a new
## exit starts the time again), it is saved with the game, and it ends when
## the time is up or the hero reaches the village, whichever comes first.

## The boon's key in Player.ailments.
const KIND := "schutz"
## How long the hero is safe, in seconds (two minutes).
const TIME := 120.0
## The shout on the way out (German source, translated through Lang).
const START_TEXT := "RUN FORREST! RUN!\nYOU HAVE 2 MINUTES TO REACH THE VILLAGE!\nFOLLOW THE WAY!"
const END_TIME_TEXT := "The protection has ended. The road is dangerous again!"
const END_VILLAGE_TEXT := "You have reached the village. Your protection ends: you are safe here anyway."
const COLOR := Color(0.55, 1.0, 0.55)


## Seconds left as minutes and seconds ("1:05"), for the explanation.
static func long_countdown(seconds: float) -> String:
	var left := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [left / 60, left % 60]


## Seconds left as a number for the icon: whole seconds.
static func countdown(seconds: float) -> String:
	return str(ceili(maxf(0.0, seconds)))
