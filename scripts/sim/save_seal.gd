class_name SaveSeal
extends RefCounted
## A seal on the files that hold a hero's progress (the saved games and the training in helden.json),
## so a hand-edited coin purse, loot, skill or character is noticed.
##
## A sealed file is the JSON text, a line break and `#seal <hex>`: an HMAC-SHA256 of the JSON text.
## The key is a secret that only the release build knows (`scripts/seal_secret.gd`, written by the
## Windows workflow from a repository secret and never committed; it travels inside the encrypted game
## data). Without it (tests, the editor, a build made without the secret) nothing is sealed and
## nothing is checked, so a save is never sealed with a key that a later build does not know.
##
## Old saves keep working: the first time a build with seals starts, `migrate` seals every file that
## has no seal yet and leaves a marker. From then on a file without a seal counts as edited, like one
## whose seal does not match. An edited file is not loaded; it stays on disk untouched.
## (This stops casual editing. Someone who takes the game apart can still forge a seal: only a server
## can prevent that.)

const MARKER := "user://seal_migrated"
const SECRET_FILE := "res://scripts/seal_secret.gd"
const TAG := "\n#seal "

## True once the old files were sealed: from then on files without a seal are refused. Tests leave it off.
static var strict := false
static var _key := PackedByteArray()


## The key, or nothing when this build has no secret.
static func key() -> PackedByteArray:
	if _key.is_empty() and ResourceLoader.exists(SECRET_FILE):
		var script = load(SECRET_FILE)
		if script != null and script.get("KEY") != null and str(script.KEY) != "":
			_key = ("escape|" + str(script.KEY)).to_utf8_buffer()
	return _key


## Sets the key by hand (tests).
static func use_key(secret: String) -> void:
	_key = ("escape|" + secret).to_utf8_buffer() if secret != "" else PackedByteArray()
	strict = false


## Whether this build seals and checks files.
static func active() -> bool:
	return not key().is_empty()


static func mac(text: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key(), text.to_utf8_buffer()).hex_encode()


## The text with its seal.
static func seal(text: String) -> String:
	return text + TAG + mac(text) if active() else text


## What a file's content says: {"text": the JSON text, "status": "sealed", "legacy" (no seal) or "tampered"}.
static func unseal(content: String) -> Dictionary:
	var at := content.rfind(TAG)
	if at < 0:
		return {"text": content, "status": "legacy"}
	var text := content.substr(0, at)
	if not active():
		return {"text": text, "status": "sealed"}
	var given := content.substr(at + TAG.length()).strip_edges()
	return {"text": text, "status": "sealed" if _same(given, mac(text)) else "tampered"}


static func _same(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in a.length():
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0


## The JSON text of a file that may be trusted, or "" when the file is missing, edited, or has no seal
## once seals are required.
static func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var result := unseal(FileAccess.get_file_as_string(path))
	match result.status:
		"sealed":
			return result.text
		"legacy":
			if not strict:
				return result.text
	push_warning("SaveSeal: %s was edited or has no seal; not loaded." % path)
	return ""


## Writes the text with its seal. False when the file could not be written.
static func write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(seal(text))
	file.close()
	return true


## Seals every file without a seal in these folders and files, then requires seals from now on.
## Runs at every start; after the first time it only turns the requirement on.
static func migrate(places: Array) -> void:
	if not active():
		return
	if FileAccess.file_exists(MARKER):
		strict = true
		return
	for place in places:
		var files := []
		if DirAccess.dir_exists_absolute(place):
			for f in DirAccess.get_files_at(place):
				if f.ends_with(".json"):
					files.append(str(place).path_join(f))
		elif FileAccess.file_exists(place):
			files.append(place)
		for path in files:
			var result := unseal(FileAccess.get_file_as_string(path))
			if result.status == "legacy" and JSON.parse_string(result.text) != null:
				write(path, result.text)
	var marker := FileAccess.open(MARKER, FileAccess.WRITE)
	if marker != null:
		marker.store_string("1")
		marker.close()
		strict = true
