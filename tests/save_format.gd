extends SceneTree
## Headless test for SaveFormat (scripts/sim/save_format.gd): every version
## has a step to the next, old records come up to date, newer ones are marked
## instead of changed, and the game saves the current version.
## Run with: godot --headless -s tests/save_format.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Save format test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for version in range(1, SaveFormat.VERSION):
		check(SaveFormat.STEPS.has(version), "version %d has a step" % version)
	var old := {"version": 1, "name": "Alt", "coins": 5}
	var up := SaveFormat.upgrade(old)
	check(int(up.version) == SaveFormat.VERSION, "an old record comes up to date")
	check(up.name == "Alt" and int(up.coins) == 5, "upgrading keeps what was there")
	check(int(old.version) == 1, "the old record itself is not changed")
	check(int(SaveFormat.upgrade({"name": "Uralt"}).version) == SaveFormat.VERSION, "a record without a version counts as version 1")
	var future := SaveFormat.upgrade({"version": SaveFormat.VERSION + 1, "name": "Neu"})
	check(future.get("too_new", false) and int(future.version) == SaveFormat.VERSION + 1, "a newer record is marked, not changed")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	game.hero_name = HERO
	var record: Dictionary = game.hero_record()
	check(int(record.version) == SaveFormat.VERSION, "the game writes the current version")
	check(record.name == HERO, "the record names the hero")
	check(JSON.parse_string(JSON.stringify(record)) is Dictionary, "the record survives JSON")
	if failures == 0:
		print("PASS: save format")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true
