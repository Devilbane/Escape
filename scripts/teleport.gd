class_name Teleport
extends RefCounted
## The teleport command of the chat line: "teleport" and Enter list every
## place with a five-letter code in the event log; the next line written is
## that code, and the hero stands at the place's entrance (see
## Game.teleport_to). "teleport <code>" works in one go. A place is any map in
## levels/: a dungeon level, a building, a mine floor or the open-air map.
##
## The code is made from the file's id (stable in every language): its first
## five letters without the article, padded with "x" and, when two places
## would share one, changed in the last letters until it is free.
##
## ENABLED is the one switch to gate the command (a debug flag, a cheat
## setting) later on: off, the line is an ordinary spoken line again.
##
## Every text is German and has an English entry in scripts/lang/teleport.gd.

const ENABLED := true
const COMMAND := "teleport"
const CODE_LENGTH := 5
## Leading articles of a file id, left out of its code.
const ARTICLES := ["die", "der", "das", "den", "dem"]
## Areas that are no place to appear in by name: the hero's own town house
## (it needs its number, see Game.go_inside) and the dragon's lair floors
## (the lair is set up on its way in, see DragonLair).
## The village square on the open-air map has a place of its own.
const VILLAGE_CODE := "dorfx"
const VILLAGE_NAME := "Das Dorf"
const SKIPPED_BUILDINGS := ["^", "E", "E2", "E3"]


## The words after "teleport", or null when the line is no teleport command.
## "teleport" alone gives "" (the game then lists the places).
static func parse(line: String) -> Variant:
	if not ENABLED:
		return null
	var text := line.strip_edges()
	var lower := text.to_lower()
	if lower == COMMAND:
		return ""
	if lower.begins_with(COMMAND + " "):
		return text.substr(COMMAND.length()).strip_edges()
	return null


## Every area as {"index": level index, "name": German name, "file": file name},
## by level index. `files` are the game's level files.
static func areas(files: Array[String]) -> Array:
	var out := []
	for i in files.size():
		var name := ""
		var building := ""
		for row in FileAccess.get_file_as_string(files[i]).split("\n"):
			if row.begins_with("name:"):
				name = row.substr(5).strip_edges()
			elif row.begins_with("building:"):
				building = row.substr(9).strip_edges()
		if name == "" or building in SKIPPED_BUILDINGS:
			continue
		out.append({"index": i, "name": name, "file": files[i].get_file()})
	out = with_codes(out)
	# The village is the open-air map's square, not its forest entrance.
	for area in out.duplicate():
		if Level.is_outdoor_file(files[int(area.index)]):
			out.append({"index": area.index, "name": VILLAGE_NAME, "file": area.file, "code": VILLAGE_CODE, "square": true})
			break
	return out


## Gives each area its "code" (see above), in level order.
static func with_codes(list: Array) -> Array:
	var taken := {}
	for area in list:
		var id := String(area.file).get_basename()
		var parts := id.split("_")
		if parts.size() > 1 and String(parts[0]).is_valid_int():
			parts.remove_at(0)
		if parts.size() > 1 and parts[0] in ARTICLES:
			parts.remove_at(0)
		var letters := "".join(parts)
		var code := (letters + "xxxxx").substr(0, CODE_LENGTH)
		var pos := CODE_LENGTH - 1
		var n := 0
		while taken.has(code):
			n += 1
			# 26 tries on the last letter, then on the one before it.
			pos = CODE_LENGTH - 1 - floori((n - 1) / 26.0)
			code = code.substr(0, pos) + char(97 + (n - 1) % 26) + code.substr(pos + 1)
		taken[code] = true
		area["code"] = code
	return list


## The area with this code (any case), or {}.
static func by_code(list: Array, typed: String) -> Dictionary:
	var want := typed.strip_edges().to_lower()
	for area in list:
		if area.code == want:
			return area
	return {}


## Whether `typed` looks like a code (five letters), whether or not it exists.
static func looks_like_code(typed: String) -> bool:
	var t := typed.strip_edges()
	return t.length() == CODE_LENGTH and not t.contains(" ")
