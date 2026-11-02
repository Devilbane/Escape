class_name Bounties
extends RefCounted
## The bounty board on the village square, next to the adventurers' guild.
## Every morning at dawn the crown's clerk pins up POSTED fresh hunts, picked
## from POOL by the day's number: the same day always shows the same notices,
## the next day shows others. Run into the board to read them, take on the
## ones you like, hunt, and come back to the board for the bounty.
##
## A hunt you took on lasts until the next dawn. Whatever is not done by then
## is torn down with the old notices; a hunt finished in time can still be
## handed in later, even after the notices changed. Each notice pays once.
##
## Every text is German and has an English entry in Lang.
## The board's state is kept in the hero's saved game (see Game).

## How many hunts hang on the board each day.
const POSTED := 3
## The board gets fresh notices when the clock passes this hour.
const DAWN := DayNight.NIGHT_UNTIL

## Every hunt the clerk can pin up: which kinds count, how many, the bounty
## in gold, and the notice's title and text.
const POOL := {
	"woelfe": {"targets": ["wolf"], "count": 4, "gold": 12,
		"title": "Wolfsplage",
		"goal": "Erlege 4 Wölfe in der Wolfssenke nördlich des Räuberpasses."},
	"spinnen": {"targets": ["spinne"], "count": 3, "gold": 12,
		"title": "Spinnen in der Senke",
		"goal": "Erlege 3 Riesenspinnen in der Wolfssenke."},
	"orks": {"targets": ["ork"], "count": 2, "gold": 16,
		"title": "Orks auf Raubzug",
		"goal": "Besiege 2 Orks in der Wolfssenke."},
	"yeti": {"targets": ["yeti"], "count": 1, "gold": 25,
		"title": "Der Yeti",
		"goal": "Besiege den Yeti, der durch die Wolfssenke streift."},
	"bestien": {"targets": ["wolf", "spinne", "ork", "yeti"], "count": 6, "gold": 22,
		"title": "Große Treibjagd",
		"goal": "Erlege 6 Bestien der Wildnis: Wölfe, Spinnen, Orks oder den Yeti."},
	"halsabschneider": {"targets": ["halsabschneider"], "count": 4, "gold": 14,
		"title": "Gesucht: Halsabschneider",
		"goal": "Besiege 4 Halsabschneider am Räuberpass."},
	"wilderer": {"targets": ["wilderer"], "count": 3, "gold": 15,
		"title": "Gesucht: Wilderer",
		"goal": "Besiege 3 Wilderer mit Armbrüsten am Räuberpass."},
	"schlaeger": {"targets": ["schlaeger"], "count": 2, "gold": 18,
		"title": "Gesucht: Schläger",
		"goal": "Besiege 2 Schläger mit Äxten am Räuberpass."},
	"untote": {"targets": ["krieger", "wicht", "schuetze", "magier"], "count": 5, "gold": 16,
		"title": "Unruhe auf dem Friedhof",
		"goal": "Schicke 5 Skelette zurück in ihre Gräber. Nachts steigen sie auf dem Friedhof aus der Erde."},
}

## Explained once in the compendium, the first time the hero reads the board.
const HOW_TO := "Am Aushang auf dem Dorfplatz hängen jeden Morgen neue Kopfgelder. Lauf gegen das Brett, nimm eine Jagd an, und hol dir das Kopfgeld dort ab, wenn sie erledigt ist. Was bis zum nächsten Morgen nicht erledigt ist, verfällt."

var game: Node
## The day the notices on the board belong to (see Game.day).
var day := -1
## Today's notices, by id from POOL.
var posted: Array = []
## Hunts the hero took on: id -> how many of the targets fell since.
var taken := {}
## Today's notices already paid out: id -> true.
var paid := {}


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	day = -1
	posted.clear()
	taken.clear()
	paid.clear()


## The hunts pinned up on a given day: always the same ones for the same day.
static func pick(for_day: int) -> Array:
	var ids: Array = POOL.keys()
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bounty board:%d" % for_day)
	var chosen := []
	while chosen.size() < mini(POSTED, ids.size()):
		chosen.append(ids.pop_at(rng.randi() % ids.size()))
	return chosen


## Brings the board up to the given day. On a new day the old notices come
## down: hunts that were not done expire. Returns how many expired.
func refresh(today: int) -> int:
	if today == day:
		return 0
	day = today
	posted = pick(today)
	paid.clear()
	var expired := 0
	for id in taken.keys():
		if not is_ready(id):
			taken.erase(id)
			expired += 1
	return expired


func is_taken(id: String) -> bool:
	return taken.has(id)


func is_ready(id: String) -> bool:
	return taken.has(id) and int(taken[id]) >= int(POOL[id].count)


func is_paid(id: String) -> bool:
	return paid.has(id)


## Whether a notice can still be taken on today.
func is_open(id: String) -> bool:
	return id in posted and not taken.has(id) and not paid.has(id)


## Takes on one of today's hunts. False if it cannot be taken.
func take(id: String) -> bool:
	if not is_open(id):
		return false
	taken[id] = 0
	return true


## Pays out a finished hunt: returns the gold (0 if it is not finished).
func claim(id: String) -> int:
	if not is_ready(id):
		return 0
	taken.erase(id)
	paid[id] = true
	Events.bus().bounty_paid.emit(id)
	return int(POOL[id].gold)


## The notices the board shows: today's, then finished hunts from earlier
## days that are still waiting to be paid.
func board_entries() -> Array:
	var out: Array = posted.duplicate()
	for id in taken:
		if not id in out:
			out.append(id)
	return out


## The mark over the board: "?" when a bounty waits to be collected, "!"
## when a notice is still open, "" otherwise.
func mark() -> String:
	for id in taken:
		if is_ready(id):
			return "?"
	for id in posted:
		if is_open(id):
			return "!"
	return ""


## How far along a hunt is, e.g. "2 / 4".
func progress(id: String) -> String:
	var count: int = POOL[id].count
	return "%d / %d" % [mini(int(taken.get(id, 0)), count), count]


## How many hunts the hero is on right now (not yet finished).
func running() -> int:
	var n := 0
	for id in taken:
		if not is_ready(id):
			n += 1
	return n


## An enemy fell: count it for every hunt that wants its kind.
func on_kill(kind: String) -> void:
	for id in taken.keys():
		var b: Dictionary = POOL[id]
		if not kind in b.targets or is_ready(id):
			continue
		taken[id] = int(taken[id]) + 1
		if game == null:
			continue
		if is_ready(id):
			Events.tell(Lang.t("Kopfgeld verdient: %s\nHol es dir am Aushang auf dem Dorfplatz.") % Lang.t(b.title), Color(0.6, 1.0, 0.6))
		else:
			Events.tell(Lang.t("%s: %d / %d") % [Lang.t(b.title), int(taken[id]), int(b.count)], Color(0.85, 0.87, 0.92), 2.0)


## What is kept in the saved game: only plain values.
func for_save() -> Dictionary:
	return {"day": day, "posted": posted.duplicate(), "taken": taken.duplicate(), "paid": paid.keys()}


## Back from the saved game; unknown hunts and broken entries are left out.
## Older saved games without a board start with fresh notices.
func load_from(saved) -> void:
	clear()
	if not (saved is Dictionary):
		return
	day = int(saved.get("day", -1))
	var p = saved.get("posted", [])
	if p is Array:
		for id in p:
			if POOL.has(str(id)) and not str(id) in posted:
				posted.append(str(id))
	var t = saved.get("taken", {})
	if t is Dictionary:
		for id in t:
			if POOL.has(str(id)):
				taken[str(id)] = maxi(0, int(t[id]))
	var done = saved.get("paid", [])
	if done is Array:
		for id in done:
			if POOL.has(str(id)):
				paid[str(id)] = true
