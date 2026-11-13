extends SceneTree
## Headless test for the use table (see Training.SKILL_FIRST): the cost of
## the levels matches the progression research (level 5 = 1,156 uses, level 10
## = 11,497, level 20 = 92,694), training reaches level SKILL_MAX and no
## further, and a hero saved in the old table keeps every level and the share
## of the way to the next one when it is loaded; the file is stamped with the
## new table so a second load changes nothing.
## Run with: godot --headless -s tests/training_curve.gd

var failures := 0
const HERO := "Training curve test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


func _read_all() -> Dictionary:
	if not FileAccess.file_exists(Training.FILE):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(Training.FILE))
	return data if data is Dictionary else {}


func _write_all(all: Dictionary) -> void:
	var file := FileAccess.open(Training.FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(all))


func _initialize() -> void:
	# The table of the research.
	check(_near(Training.skill_xp_for(1), 80.0, 0.01), "level 1 costs 80 uses")
	check(_near(Training.skill_xp_for(5), 1156.0, 3.0), "level 5 is 1,156 uses in all (%s)" % Training.skill_xp_for(5))
	check(_near(Training.skill_xp_for(10), 11497.0, 15.0), "level 10 is 11,497 uses in all (%s)" % Training.skill_xp_for(10))
	check(_near(Training.skill_xp_for(20), 92694.0, 100.0), "level 20 is 92,694 uses in all (%s)" % Training.skill_xp_for(20))
	check(Training.skill_step_cost(10) < Training.skill_step_cost(9) * 1.13, "past level 10 each level costs 1.12 times the last")
	for level in range(0, Training.SKILL_TABLE_MAX):
		check(Training.skill_step_cost(level + 1) > Training.skill_step_cost(level), "level %d costs more than level %d" % [level + 2, level + 1])
	# Training reaches SKILL_MAX and no further.
	var all_the_uses := Training.skill_xp_for(Training.SKILL_TABLE_MAX) * 2.0
	check(Training.skill_level(all_the_uses, "klingen") == Training.SKILL_MAX, "a basic skill stops at level %d" % Training.SKILL_MAX)
	check(Training.skill_level(Training.skill_xp_for(4) + 1.0, "klingen") == 4, "level 4 is reached at its cost")
	check(Training.skill_level(Training.skill_xp_for(4) - 1.0, "klingen") == 3, "one use short is still level 3")
	check(_near(Training.skill_progress(Training.skill_xp_for(3) + Training.skill_step_cost(3) / 2.0, "klingen"), 0.5, 0.001), "halfway is 50 %")
	check(Training.skill_progress(all_the_uses, "klingen") == 1.0, "a full skill shows full progress")

	# The old table, level for level, with a share of the next level.
	for level in range(0, Training.SKILL_MAX + 1):
		for share in [0.0, 0.5, 0.9]:
			var old := 0.0
			var cost := Training.OLD_SKILL_FIRST
			for i in level:
				old += cost
				cost *= Training.OLD_SKILL_GROWTH
			if level < Training.SKILL_MAX:
				old += share * cost
			var moved := Training.skill_from_old_table(old, "klingen")
			check(Training.skill_level(moved, "klingen") == level, "old level %d (+%d %%) stays level %d (%d)" % [level, share * 100, level, Training.skill_level(moved, "klingen")])
			if level < Training.SKILL_MAX:
				check(_near(Training.skill_progress(moved, "klingen"), share, 0.001), "old level %d keeps %d %% of the way" % [level, share * 100])

	# A hero in the file without the stamp is moved when loaded.
	var all := _read_all()
	var had = all.get(HERO)
	all[HERO] = {"klingen": 700.0, "alchemie": Training.OLD_SKILL_FIRST * 3.0, "staerke": 1234.0, "erkunden": 0.0}
	_write_all(all)
	var xp := Training.load_hero(HERO)
	var klingen_old := Training.points(700.0, Training.OLD_SKILL_FIRST, Training.OLD_SKILL_GROWTH, Training.SKILL_MAX)
	check(Training.skill_level(xp["klingen"], "klingen") == klingen_old, "a saved hero keeps Klingen %d (%d)" % [klingen_old, Training.skill_level(xp["klingen"], "klingen")])
	check(Training.skill_level(xp["alchemie"], "alchemie") == Training.points(Training.OLD_SKILL_FIRST * 3.0, Training.OLD_SKILL_FIRST, Training.OLD_SKILL_GROWTH, Training.SKILL_MAX), "and the craft Alchemie")
	check(xp["staerke"] == 1234.0, "an attribute's training is not touched")
	check(xp["erkunden"] == 0.0, "an untrained skill stays untrained")
	check(not xp.has(Training.CURVE_KEY), "the stamp is not a skill")
	# Saved again, the file carries the stamp and a second load changes nothing.
	Training.keep = true
	Training.save_hero(HERO, xp)
	var again := Training.load_hero(HERO)
	check(_near(again["klingen"], xp["klingen"], 0.001) and _near(again["alchemie"], xp["alchemie"], 0.001) and Training.skill_level(again["klingen"], "klingen") == Training.skill_level(xp["klingen"], "klingen"), "a second load changes nothing")
	check(int(_read_all()[HERO][Training.CURVE_KEY]) == Training.CURVE, "the file is stamped with the new table")
	# A hero that has never trained loads empty.
	check(Training.load_hero("nobody called this").is_empty(), "a new hero has no training")

	# Put the file back as it was.
	all = _read_all()
	if had == null:
		all.erase(HERO)
	else:
		all[HERO] = had
	_write_all(all)
	print("PASS" if failures == 0 else "FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
