extends SceneTree
## Headless test for Storage (scripts/sim/storage.gd): the bank, the house
## deeds and the ranking keep their books through it, so a server can keep them
## somewhere else. Run with: godot --headless -s tests/storage.gd

var failures := 0
const HERO := "Storage test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# The default backend is files in the user folder, where the books always were.
	check(Storage.backend() is Storage.Files, "files are the default")
	check((Storage.backend() as Storage.Files).path("bank") == "user://bank.json", "the bank keeps its old file")

	# Memory: what is written comes back, through JSON.
	var memory := Storage.Memory.new()
	Storage.use(memory)
	check(Storage.read("nothing") == null, "a missing record is null")
	check(Storage.write("thing", {"a": 1, "list": [1, 2]}), "a record is written")
	var back = Storage.read("thing")
	check(back is Dictionary and int(back.a) == 1 and back.list.size() == 2, "a record comes back")

	# The bank, the deeds and the ranking go through Storage.
	Bank.reload()
	Bank.deposit(HERO, 25)
	check(memory.records.has(Bank.RECORD), "the bank writes through Storage")
	Bank.reload()
	check(Bank.gold(HERO) == 25, "the bank reads its books back")
	Homes.reload()
	check(Homes.claim(HERO, 2), "a house is claimed")
	check(memory.records.has(Homes.RECORD), "the deeds write through Storage")
	Homes.reload()
	check(Homes.house_of(HERO) == 2, "the deeds read back")
	Ranking.add(HERO, 3, "Die Gruft", 10, false)
	check(memory.records.has(Ranking.RECORD), "the ranking writes through Storage")
	check(Ranking.load_all().size() == 1, "the ranking reads back")

	# Files in another folder (a server's own save folder).
	var folder := "user://storage_test/"
	var files := Storage.Files.new("user://storage_test")
	check(files.folder == folder, "a folder gets its slash")
	check(files.write("record", [1, 2, 3]), "a file record is written")
	var read_back = files.read("record")
	check(read_back is Array and read_back.size() == 3, "a file record comes back")
	DirAccess.remove_absolute(files.path("record"))
	DirAccess.remove_absolute(folder)

	Storage.use(null)
	Bank.reload()
	Homes.reload()
	check(Storage.backend() is Storage.Files, "use(null) goes back to files")

	if failures == 0:
		print("PASS: storage")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
