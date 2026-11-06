class_name Homes
extends RefCounted
## The town houses on Weavers' Lane, north of the village square: narrow
## three-storey homes in a row (see Outdoor._build_terrace), one for every
## hero. A hero without a house moves into the first free one they walk
## into; from then on it is theirs, and the doors of the others stay shut.
## Like the bank's books (see Bank), the deeds are kept apart from the saved
## games, so every hero who ever played on this computer keeps their house
## and their neighbours see it taken. (Once there is a server, the deeds can
## live there instead.)

const FILE := "user://homes.json"

static var _owners := {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_owners = {}
	if FileAccess.file_exists(FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary and parsed.get("owners", {}) is Dictionary:
			for key in parsed.owners:
				if int(key) > 0:
					_owners[str(int(key))] = str(parsed.owners[key])


static func _save() -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"owners": _owners}))


## Forgets what was read, so the next call reads the file again.
static func reload() -> void:
	_loaded = false


## The name a hero is written into the deeds under: a hero without a name
## lives there as "Namenlos", as the game calls them.
static func deed_name(hero: String) -> String:
	return hero if hero != "" else "Namenlos"


## Who lives in house `number`, or "" while it stands empty.
static func owner_of(number: int) -> String:
	_load()
	return _owners.get(str(number), "")


## The number of the hero's house, or 0 if they have none yet.
static func house_of(hero: String) -> int:
	_load()
	hero = deed_name(hero)
	for key in _owners:
		if _owners[key] == hero:
			return int(key)
	return 0


## Gives the empty house `number` to a hero who has none. Returns whether
## the hero lives there now.
static func claim(hero: String, number: int) -> bool:
	_load()
	hero = deed_name(hero)
	if number <= 0:
		return false
	var mine := house_of(hero)
	if mine != 0:
		return mine == number
	if owner_of(number) != "":
		return false
	_owners[str(number)] = hero
	_save()
	return true


## The lowest-numbered empty house of the `count` there are, or 0 if
## every one is taken.
static func first_free(count: int) -> int:
	_load()
	for n in range(1, count + 1):
		if owner_of(n) == "":
			return n
	return 0


## The hero's house, moving them into the first empty one of `count` if
## they have none yet. 0 when every house is taken.
static func house_for(hero: String, count: int) -> int:
	var mine := house_of(hero)
	if mine == 0:
		mine = first_free(count)
		if mine == 0 or not claim(hero, mine):
			return 0
	return mine


## Hands a house back (for tests, and for a hero who moves out).
static func release(number: int) -> void:
	_load()
	if _owners.erase(str(number)):
		_save()
