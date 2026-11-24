extends SceneTree
## Headless test for the climbing gear (see Climbing.SET): five pieces, each worn in its own slot (the
## hammer in the weapon hand, the rope in the shield hand), +1 Klettern for every worn piece and
## Climbing.SET_BONUS more for the whole set; carried in the bag a piece does nothing. The gear is for sale
## at the shop's restock.
## Run with: godot --headless -s tests/climbing_gear.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var slots := {"waffe": "kletterhammer", "schild": "kletterseil", "kopf": "kletterhelm",
		"schuhe": "kletterschuhe", "handschuhe": "kletterhandschuhe"}
	check(Climbing.SET == slots, "the set is hammer, rope, helmet, shoes and gloves in their slots")
	for slot: String in slots:
		var item: Dictionary = Items.ALL[slots[slot]]
		check(item.slot == slot, "%s is worn in %s" % [slots[slot], slot])
		check(int(item.skills.klettern) == 1, "%s gives +1 Klettern" % slots[slot])
		check(Climbing.GEAR_FOR_SALE.has(slots[slot]), "%s is for sale" % slots[slot])
	check(Climbing.GEAR_FOR_SALE.has("kletterhaken"), "nails are for sale")
	check(Items.ALL["kletterhaken"].slot == "erz" and not Items.ALL["kletterhaken"].has("skills"), "nails stay in the bag and give no level")

	var hero := Player.new()
	root.add_child(hero)
	var base := hero.skill("klettern")
	var worn := 0
	for slot: String in slots:
		hero.equipped[slot] = slots[slot]
		worn += 1
		var want := base + worn + (Climbing.SET_BONUS if worn == slots.size() else 0)
		check(hero.skill("klettern") == want, "%d pieces worn: Klettern %d (want %d)" % [worn, hero.skill("klettern"), want])
	check(Climbing.set_complete(hero.equipped), "the set is complete")
	hero.equipped.erase("schuhe")
	check(hero.skill("klettern") == base + 4, "without the shoes the set bonus is gone: %d" % hero.skill("klettern"))
	hero.equipped.clear()
	hero.bag.append_array(slots.values())
	check(hero.skill("klettern") == base, "gear in the bag does nothing")

	print("PASS: climbing gear" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
