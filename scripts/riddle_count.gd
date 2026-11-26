class_name RiddleCount
extends RefCounted
## The riddle counter: a gravestone of Count Riddles' family in each town's graveyard. Reading it says how
## many of the game's official riddles the hero has solved and how many there are, e.g.
## "Count Riddles of Apple Valley, 01/02. This is just the beginning." Every town with a graveyard gets
## one of the family: add the town to GRAVES (its map's name and the tile of the stone) and give the stone
## its English name in scripts/lang/riddle_count.gd. All of them show one count, kept in the saved game.
##
## Raise TOTAL when a new official riddle is made, add its id to IDS and report its solving with
## Events.bus().riddle_done.emit(id) (see Game._bus_links); nothing else is needed.

const KIND := "raetselstein"
## The official riddles: their ids. TOTAL follows from the list.
const OWL_CLOCK := "eulenuhr"
const SUNFLOWER := "sonnenblume"
const IDS := [SUNFLOWER, OWL_CLOCK]
const TOTAL := 2
## The town's graveyard stone: the map's name -> the tile of the grave in its map.
const GRAVES := {"Apfeltal": Vector2i(7, 4)}
## How the stone is named; %s is the town (German here, English in scripts/lang/riddle_count.gd).
const NAME := "Graf Rätselhaft von %s"
const BEGIN := "Fang einfach an."
const GOING := "Das ist erst der Anfang."

## The ids of the riddles solved, in the saved game.
var solved: Array[String] = []


func clear() -> void:
	solved.clear()


## Counts a riddle as solved (once). Returns whether it was new.
func solve(id: String) -> bool:
	if not id in IDS or id in solved:
		return false
	solved.append(id)
	return true


func count() -> int:
	return solved.size()


## What the stone says in a town: its name and the count with a line to go with it.
func card(town: String) -> String:
	var line := BEGIN if solved.is_empty() else GOING
	return Lang.t(NAME) % Lang.t(town) + "\n%02d/%02d  %s" % [count(), TOTAL, Lang.t(line)]


## The grave of a town's map, (-1, -1) for none.
static func grave_of(town: String) -> Vector2i:
	return GRAVES.get(town, Vector2i(-1, -1))


func for_save() -> Array:
	return solved.duplicate()


func load_from(data) -> void:
	solved.clear()
	if data is Array:
		for id in data:
			if str(id) in IDS and not str(id) in solved:
				solved.append(str(id))
