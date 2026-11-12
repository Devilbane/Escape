class_name HeroStore
extends RefCounted
## The hero records a server keeps, one per hero, through Storage.
##
## A record is what Game.hero_record() builds. It is always read back at the
## current SaveFormat version, so a server that runs for months can load a hero
## saved by an older build. Names are folded into a safe record name, so no
## name can reach outside the server's folder.

const PREFIX := "hero_"


## The Storage record name for a hero: lower case letters, digits and "_",
## with any other letter written as its code.
static func key(hero: String) -> String:
	var out := ""
	for c in hero.strip_edges().to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif c == " " or c == "_" or c == "-":
			out += "_"
		else:
			out += "x%x" % c.unicode_at(0)
	return PREFIX + out


static func has(hero: String) -> bool:
	return Storage.read(key(hero)) is Dictionary


## The hero's record at the current version, or an empty Dictionary for a
## hero the server has never seen.
static func load_hero(hero: String) -> Dictionary:
	var saved = Storage.read(key(hero))
	return SaveFormat.upgrade(saved) if saved is Dictionary else {}


## Keeps a record; it must name its hero. A record from a newer build than the
## server is refused so nothing in it is lost.
static func save_hero(record: Dictionary) -> bool:
	var hero := str(record.get("name", "")).strip_edges()
	if hero.is_empty() or int(record.get("version", 1)) > SaveFormat.VERSION:
		return false
	var data := record.duplicate(true)
	data.erase("too_new")
	data.version = SaveFormat.VERSION
	return Storage.write(key(hero), data)
