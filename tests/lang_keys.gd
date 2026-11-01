extends SceneTree
## Headless test for the English text table (see Lang): every file in
## scripts/lang/ is listed in Lang.PARTS, each one loads and has an EN table,
## and no German text is translated in two files. Duplicates inside one file
## are already a parse error, so a broken file shows up here as one that
## does not load.
## Run with: godot --headless -s tests/lang_keys.gd

const DIR := "res://scripts/lang"

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_check_files_listed()
	_check_no_duplicates()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## A file nobody lists would silently be left out of the game.
func _check_files_listed() -> void:
	var listed := []
	for part in Lang.PARTS:
		check(part is Script, "an entry of Lang.PARTS is not a script")
		if part is Script:
			listed.append(part.resource_path)
	var dir := DirAccess.open(DIR)
	check(dir != null, "%s is missing" % DIR)
	if dir == null:
		return
	var files := Array(dir.get_files()).filter(func(f): return f.ends_with(".gd"))
	check(files.size() > 0, "no text files in %s" % DIR)
	for file in files:
		var path: String = DIR + "/" + file
		check(path in listed, "%s is not listed in Lang.PARTS" % path)
	for path in listed:
		check(path.get_file() in files, "Lang.PARTS lists %s, which is not in %s" % [path, DIR])
		check(listed.count(path) == 1, "Lang.PARTS lists %s twice" % path)


## Each German text is translated in exactly one file, and Lang.EN holds all of them.
func _check_no_duplicates() -> void:
	var owner := {}
	var total := 0
	for part in Lang.PARTS:
		if not part is Script:
			continue
		var file: String = part.resource_path.get_file()
		var table = part.get_script_constant_map().get("EN")
		check(table is Dictionary and not table.is_empty(), "%s has no EN table" % file)
		if not table is Dictionary:
			continue
		total += table.size()
		for key in table:
			check(key is String and table[key] is String and table[key] != "", "%s: \"%s\" needs an English text" % [file, key])
			if owner.has(key):
				check(false, "\"%s\" is in both %s and %s" % [key, owner[key], file])
			else:
				owner[key] = file
	check(Lang.EN.size() == owner.size(), "Lang.EN has %d texts, the files %d" % [Lang.EN.size(), owner.size()])
	check(total > 0, "no texts at all")
