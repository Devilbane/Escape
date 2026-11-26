extends SceneTree
## Headless test for RiddleVault (scripts/riddle_vault.gd): an entry accepts its answer in any case and spacing and
## nothing else, two entries of one answer differ, a code survives scrambling, and a guess is slow enough.
## Uses an invented phrase, never a real riddle's answer.
## Run with: godot --headless -s tests/riddle_vault.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var entry := RiddleVault.make_entry("Purple walrus, hums softly!")
	check(entry["hash"] != "" and entry["salt"] != "", "entry has a salt and a hash")
	check(RiddleVault.check("purple walrus hums softly", entry), "answer in other case and spacing")
	check(RiddleVault.check("  PURPLE-WALRUS... hums softly ", entry), "marks and spaces do not matter")
	check(not RiddleVault.check("purple walrus hums loudly", entry), "a wrong line")
	check(not RiddleVault.check("", entry), "an empty line")
	check(not RiddleVault.check("1234", entry), "a line without letters")
	check(not RiddleVault.check("a".repeat(500), entry), "a very long line")
	var other := RiddleVault.make_entry("purple walrus hums softly")
	check(other["salt"] != entry["salt"] and other["hash"] != entry["hash"], "two entries of one answer differ")
	check(not RiddleVault.check("purple walrus hums softly", {"salt": "x", "rounds": 10, "hash": entry["hash"]}), "another salt rejects it")
	var code := [3, 17, 0, 5, 25, 0, 9, 1, 2, 255]
	var text := RiddleVault.scramble(code, entry)
	check(RiddleVault.unscramble(text, entry) == code, "a code survives scrambling")
	check(RiddleVault.unscramble(text, other) != code, "another salt does not unscramble it")
	var t := Time.get_ticks_msec()
	RiddleVault.check("some guess", entry)
	var ms := Time.get_ticks_msec() - t
	check(ms < 400, "a guess is fast enough for the game (%d ms)" % ms)
	check(RiddleVault.ROUNDS >= 50000, "enough rounds to slow a word list")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)
