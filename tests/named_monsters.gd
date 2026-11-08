extends SceneTree
## Named monsters (given a name in the map workshop) are tougher than plain
## ones of their kind; bosses, wardens and maker-set numbers are left alone.

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _enemy(kind: String, custom := {}) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.custom = custom
	root.add_child(e)
	return e


func _init() -> void:
	var plain := _enemy("schlaeger")
	var named := _enemy("schlaeger", {"title": "Grom"})
	check(named.is_named_elite() and not plain.is_named_elite(), "only the named one is an elite")
	check(named.max_hp() >= int(plain.max_hp() * 1.7), "named life is about %sx" % Enemy.NAMED_HP_MULT)
	check(named._stats.damage > plain._stats.damage, "named blow is harder")
	check(named.hardening == plain.hardening + Enemy.NAMED_ARMOR_BONUS, "named hardening is higher")
	check(named.rated_level >= plain.rated_level, "named is rated at least as high")
	var set := _enemy("schlaeger", {"title": "Grom", "hp": 40, "damage": 4, "armor": 2})
	check(set.max_hp() == 40 and set._stats.damage == 4 and set.hardening == 2, "maker-set numbers stay")
	var unnamed := _enemy("schlaeger", {"hp": 40})
	check(unnamed.max_hp() == 40, "a monster without a name is not toughened")
	var chief := _enemy("hauptmann", {"title": "Chef"})
	check(not chief.is_named_elite(), "a boss gets no step up")
	print("named_monsters: %s" % ("OK" if failures == 0 else "%d failed" % failures))
	quit(1 if failures else 0)
