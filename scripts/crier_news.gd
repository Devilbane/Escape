class_name CrierNews
extends RefCounted
## What the herald calls out from his podium (see TownCrier): the hero's deeds, and the village's usual news.
##
## Whenever the hero finishes a task or solves one of the official riddles, the herald announces it a few
## seconds later, and he repeats the news twice a day, at 10:00 and at 16:00 (HOURS): one deed at each call, the
## newest first, then the older ones in turn. A deed is news for KEEP_DAYS days. With no deed to report he
## reads the usual news (Villager.NEWS). The deeds are kept in the saved game.
##
## Game feeds it (see Game._bus_links) and Outdoor asks it when a call is due (see Outdoor._call_for_news).

## The hours of the day (world clock) of the daily news.
const HOURS := [10.0, 16.0]
## How long after the hour the news may still be called, if the herald was busy (hours).
const GRACE := 1.5
## How many days a deed stays news, and how many deeds are kept.
const KEEP_DAYS := 3
const KEEP := 6
## Seconds between a deed and its announcement.
const DELAY := 6.0

const QUEST := "quest"
const RIDDLE := "riddle"

## The sentences, German here and English in scripts/lang/town_crier.gd. %s is the hero's name.
const QUEST_LINE := "Hört, hört! %s hat den Auftrag „%s“ erfüllt!"
const RIDDLE_LINES := {
	RiddleCount.SUNFLOWER: "Hört, hört! %s hat das Rätsel der Sonnenblumen gelöst!",
	RiddleCount.OWL_CLOCK: "Hört, hört! %s hat das Rätsel der Eulenuhr gelöst!",
	RiddleCount.SPIRIT: "Hört, hört! %s hat das Rätsel des Grabgeistes gelöst!",
	RiddleCount.BELL: "Hört, hört! %s hat das Rätsel der Grabglocke gelöst!",
	RiddleCount.SKULLS: "Hört, hört! %s hat das Rätsel der zwei Schädel gelöst!",
}
## What the sign's mouse-over says.
const SIGN_TIP := "Apfeltal-Nachrichten jeden Tag um 10 und 16 Uhr"

## The one the game plays with (set by Game), so the village can ask without knowing the game.
static var current: CrierNews

## Deeds, oldest first: {"kind", "id", "who", "day"}.
var items: Array = []
## The deeds not announced yet, and when the newest was done (msec).
var fresh: Array = []
var _fresh_at := 0
## Which deed the next daily call reads, and the daily call last made (day * 10 + slot).
var _turn := 0
var _last_call := -1


func clear() -> void:
	items.clear()
	fresh.clear()
	_turn = 0
	_last_call = -1


## A deed of the hero: a finished task or a solved riddle.
func add(kind: String, id: String, who: String, day: int) -> void:
	if kind == QUEST and not Quests.ALL.has(id):
		return
	if kind == RIDDLE and not RIDDLE_LINES.has(id):
		return
	for it: Dictionary in items:
		if it.kind == kind and it.id == id:
			return
	var deed := {"kind": kind, "id": id, "who": who, "day": day}
	items.append(deed)
	while items.size() > KEEP:
		items.pop_front()
	fresh.append(deed)
	_fresh_at = Time.get_ticks_msec()


## What the herald says about a deed (in the player's language).
static func line_of(deed: Dictionary) -> String:
	if deed.kind == QUEST:
		return Lang.t(QUEST_LINE) % [deed.who, Lang.t(Quests.ALL[deed.id].title)]
	return Lang.t(RIDDLE_LINES[deed.id]) % deed.who


## The text of a deed announced now, or "" when none waits (a fresh deed has to be a few seconds old).
func take_fresh() -> String:
	if fresh.is_empty() or Time.get_ticks_msec() - _fresh_at < int(DELAY * 1000.0):
		return ""
	var deed: Dictionary = fresh.pop_back()
	# Older ones that piled up meanwhile are read at the daily news.
	fresh.clear()
	return line_of(deed)


## The slot of the daily news due at this day and hour (0 for 10:00, 1 for 16:00), or -1.
func due_slot(day: int, hour: float) -> int:
	for i in HOURS.size():
		if hour >= HOURS[i] and hour < HOURS[i] + GRACE and _last_call != day * 10 + i:
			return i
	return -1


## The text of the daily news of `slot` for the day, and the call is made: the newest deed still news, then the older
## ones in turn. "" when there is no deed, then the herald reads the usual news.
func take_daily(day: int, slot: int) -> String:
	_last_call = day * 10 + slot
	var news := items.filter(func(it: Dictionary) -> bool: return day - int(it.day) <= KEEP_DAYS)
	if news.is_empty():
		return ""
	var deed: Dictionary = news[news.size() - 1 - (_turn % news.size())]
	_turn += 1
	return line_of(deed)


func for_save() -> Dictionary:
	return {"items": items.duplicate(true), "turn": _turn, "last": _last_call}


func load_from(data) -> void:
	clear()
	if not data is Dictionary:
		return
	for it in data.get("items", []):
		if it is Dictionary and it.has("kind") and it.has("id"):
			var kind := str(it.kind)
			var id := str(it.id)
			if (kind == QUEST and Quests.ALL.has(id)) or (kind == RIDDLE and RIDDLE_LINES.has(id)):
				items.append({"kind": kind, "id": id, "who": str(it.get("who", "")), "day": int(it.get("day", 0))})
	_turn = int(data.get("turn", 0))
	_last_call = int(data.get("last", -1))
