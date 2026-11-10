extends SceneTree
## Headless test: the god-born Traveller's backpack gives +1 hardening and +5 % speed while worn.
## Run with: godot --headless -s tests/godborn_backpack.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var item: Dictionary = Items.ALL.reiserucksack
	check(Items.RARITY.reiserucksack == "gottgeboren", "the Traveller's backpack is god-born")
	check(item.get("armor", 0) == 1, "it gives +1 hardening")
	check(is_equal_approx(item.get("speed", 0.0), 0.05), "it gives +5 % speed")
	var text := Items.describe("reiserucksack")
	check("+1" in text and "+5" in text, "the tooltip lists both bonuses: " + text)
	if failures == 0:
		print("PASS")
	quit(1 if failures > 0 else 0)
