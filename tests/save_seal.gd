extends SceneTree
## Headless test for SaveSeal (scripts/sim/save_seal.gd): a sealed file reads back, an edited one is
## refused, an old unsealed one is sealed once by the migration and refused afterwards.
## Run with: godot --headless -s tests/save_seal.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	check(not SaveSeal.active() and SaveSeal.seal("{}") == "{}", "without a secret nothing is sealed")
	SaveSeal.use_key("test key")
	var dir := "user://seal_test/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "platz_1.json"
	var text := JSON.stringify({"name": "Ada", "coins": 40, "version": 2})
	check(SaveSeal.unseal(SaveSeal.seal(text)).status == "sealed", "a sealed text is recognised")
	check(SaveSeal.unseal(SaveSeal.seal(text)).text == text, "unsealing gives the text back")
	check(SaveSeal.write(path, text) and SaveSeal.read(path) == text, "a written file reads back")
	# Edit the coins by hand: the seal no longer fits.
	var edited := FileAccess.get_file_as_string(path).replace("40", "99999")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(edited)
	file.close()
	check(SaveSeal.unseal(edited).status == "tampered", "an edited file is detected")
	check(SaveSeal.read(path) == "", "an edited file is not loaded")
	# A forged seal of the wrong key does not pass either.
	check(SaveSeal.unseal(text + SaveSeal.TAG + "00".repeat(32)).status == "tampered", "a made-up seal is detected")
	# An old file without a seal: read while seals are not required, refused after.
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	SaveSeal.strict = false
	check(SaveSeal.read(path) == text, "an old unsealed file is read before the migration")
	DirAccess.remove_absolute(SaveSeal.MARKER)
	SaveSeal.migrate([dir])
	check(SaveSeal.strict and SaveSeal.unseal(FileAccess.get_file_as_string(path)).status == "sealed", "the migration seals old files")
	check(SaveSeal.read(path) == text, "a migrated file keeps its content")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	check(SaveSeal.read(path) == "", "after the migration a file without a seal is refused")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(SaveSeal.MARKER)
	DirAccess.remove_absolute(dir)
	SaveSeal.use_key("")
	if failures == 0:
		print("PASS: save seal")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
