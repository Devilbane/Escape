extends SceneTree
## Headless test: the words floating up for a find or for experience are sized
## by their worth (see DamageNumber.worth_size and Effects.loot_text). A plain
## sword is smaller than a godborn hammer, one copper coin smaller than a
## chestful, a little experience smaller than a boss's, and every size stays
## between WORTH_MIN_SIZE and WORTH_MAX_SIZE.
## Run with: godot --headless -s tests/loot_text_size.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _size(worth: float) -> int:
	return DamageNumber.worth_size(worth)


func _initialize() -> void:
	check(_size(0.0) == DamageNumber.WORTH_MIN_SIZE and _size(1.0) == DamageNumber.WORTH_MAX_SIZE, "worth 0 and 1 give the smallest and biggest size")
	check(_size(-3.0) == DamageNumber.WORTH_MIN_SIZE and _size(5.0) == DamageNumber.WORTH_MAX_SIZE, "worth outside 0 to 1 is held to the sizes")

	var plain := _size(DamageNumber.item_worth("schwert"))
	var godborn := _size(DamageNumber.item_worth("runenhammer"))
	check(plain < godborn, "a plain sword (%d) is smaller than a godborn hammer (%d)" % [plain, godborn])
	var last := 0
	for tier in ["normal", "ungewoehnlich", "selten", "episch", "gottgeboren"]:
		var s: int = _size(DamageNumber.TIER_WORTH[tier])
		check(s > last, "%s (%d) is bigger than the tier below it" % [tier, s])
		last = s

	var one := _size(DamageNumber.copper_worth(1))
	var chest := _size(DamageNumber.copper_worth(45))
	var hoard := _size(DamageNumber.copper_worth(500))
	check(one < chest and chest < hoard, "1 copper (%d) < 45 copper (%d) < 500 copper (%d)" % [one, chest, hoard])

	var hero := 4
	var kill := HeroLevel.kill_xp(hero, hero)
	var bit := _size(DamageNumber.xp_worth(maxi(1, roundi(kill * 0.25)), hero))
	var normal := _size(DamageNumber.xp_worth(kill, hero))
	var boss := _size(DamageNumber.xp_worth(HeroLevel.kill_xp(hero, hero, true), hero))
	check(bit < normal and normal < boss, "a little XP (%d) < a kill's XP (%d) < a boss's XP (%d)" % [bit, normal, boss])

	print("PASS: loot text size" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
