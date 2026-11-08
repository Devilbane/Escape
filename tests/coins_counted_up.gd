extends SceneTree
## Headless test: the purse shows its coins counted up into silver and gold
## (Loot.counted_up, Loot.worth_text) without changing them.
## Run with: godot --headless -s tests/coins_counted_up.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	var up := Loot.counted_up(250, 0, 0)
	check(up["goldmuenze"] == 1 and up["silbermuenze"] == 0 and up["kupfermuenze"] == 0, "250 copper count up to 1 gold")
	up = Loot.counted_up(60, 3, 0)
	check(up["goldmuenze"] == 0 and up["silbermuenze"] == 5 and up["kupfermuenze"] == 10, "60 copper + 3 silver = 5 silver 10 copper")
	up = Loot.counted_up(24, 9, 2)
	check(up["goldmuenze"] == 2 and up["silbermuenze"] == 9 and up["kupfermuenze"] == 24, "nothing to carry stays as it is")
	check(Loot.worth_text(0, 0, 0) == "0 copper", "an empty purse reads 0 copper")
	check(Loot.worth_text(54, 11, 1) == "2 gold, 3 silver, 4 copper", "full line: " + Loot.worth_text(54, 11, 1))
	check(Loot.worth_text(0, 10, 0) == "1 gold", "10 silver leave no copper in the line")
	print("coins_counted_up: ", "ok" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
