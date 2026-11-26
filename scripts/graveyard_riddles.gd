class_name GraveyardRiddles
extends RefCounted
## The riddles of the graveyards: the owl clock's crypt, the grave with the bell and the spirit of the unknown
## grave. They are not the official riddles of the counter stone (see RiddleCount); they have a prize of their own:
## whoever has solved NEEDED of them is taught Necromancy (Training.CRAFTS "nekromantie"), at level 0 first.
## Report a solved one with Events.bus().graveyard_riddle.emit(id) (see Game._bus_links).

const OWL_CLOCK := "eulengruft"
const BELL := "glockengrab"
const SPIRIT := "geist"
## The skulls of the ossuary (a tale of the crypt, but no riddle of the kind that teaches Necromancy).
const SKULLS := "schaedel"
const IDS := [OWL_CLOCK, BELL, SPIRIT, SKULLS]
## The tales of the crypt, all told: the quest log counts them (see Quests.TALES).
const TALES := 4
## How many riddles (not the skulls) teach Necromancy.
const NEEDED := 2
## The skill (Training.CRAFTS) the prize teaches.
const SKILL := "nekromantie"
const OPENED := "Die Geheimnisse der Gräber sind dir kein Rätsel mehr: Die Nekromantie steht dir nun offen."

var solved: Array[String] = []


func clear() -> void:
	solved.clear()


## Counts a riddle as solved (once). Returns whether it was new.
func solve(id: String) -> bool:
	if not id in IDS or id in solved:
		return false
	solved.append(id)
	return true


## The tales told, for the quest "Tales of the Crypt".
func count() -> int:
	return solved.size()


## The riddles among them (the skulls are no riddle of that kind): what teaches Necromancy.
func riddles_solved() -> int:
	return solved.size() - (1 if SKULLS in solved else 0)


## Whether the hero is taught Necromancy (even at level 0 the skill is in the hero's list then).
static func knows(player: Player) -> bool:
	return player.xp.has(SKILL)


## Teaches Necromancy at level 0 (it keeps what the hero already trained). Returns whether it was new.
static func teach(player: Player) -> bool:
	if knows(player):
		return false
	player.xp[SKILL] = 0.0
	return true


func for_save() -> Array:
	return solved.duplicate()


func load_from(data) -> void:
	solved.clear()
	if data is Array:
		for id in data:
			if str(id) in IDS and not str(id) in solved:
				solved.append(str(id))
