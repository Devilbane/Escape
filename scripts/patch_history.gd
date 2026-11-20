class_name PatchHistory
extends RefCounted
## The patch notes of every build, for the compendium's patch notes page.
##
## A build ships only the notes that are new in it (tools/patch_notes.py build), so the
## older ones are kept in an archive of their own, docs/patch_history.json: one entry per
## build, newest first, each with its version ("0.5.2325"), build number, date and the
## changes as plain lines (in English, like the launcher's notes). The Windows build
## (.github/workflows/desktop.yml) adds its own notes on top of the archive it published
## last time and of the committed one (tools/patch_notes.py history), ships the result in
## the game and publishes it beside version.json, so the archive grows with every build.
## The committed file holds the backfill: the builds before the archive existed, read from
## the published version.json and from the git history of the notes.

const FILE := "res://docs/patch_history.json"

static var _cache: Array = []
static var _loaded := false


## Every build with notes, newest first: {version, build, date, notes: Array of String}.
## An empty Array when the archive is missing or broken.
static func builds() -> Array:
	if not _loaded:
		_loaded = true
		_cache = parse(FileAccess.get_file_as_string(FILE))
	return _cache


## The entries of an archive's text, checked and sorted newest first; broken entries
## are left out.
static func parse(text: String) -> Array:
	var json := JSON.new()
	if text == "" or json.parse(text) != OK:
		return []
	var data: Variant = json.data
	if not (data is Dictionary) or not (data.get("builds") is Array):
		return []
	var out := []
	for entry: Variant in data.builds:
		if not (entry is Dictionary) or not (entry.get("notes") is Array) or entry.notes.is_empty():
			continue
		var notes := PackedStringArray()
		for line: Variant in entry.notes:
			if str(line).strip_edges() != "":
				notes.append(str(line).strip_edges())
		if notes.is_empty():
			continue
		out.append({
			"version": str(entry.get("version", "")),
			"build": str(entry.get("build", "")),
			"date": str(entry.get("date", "")),
			"notes": Array(notes),
		})
	out.sort_custom(func(a, b): return a.build.to_int() > b.build.to_int())
	return out


## The entry of one build, or an empty Dictionary.
static func find(build: String) -> Dictionary:
	for entry in builds():
		if entry.build == build:
			return entry
	return {}
