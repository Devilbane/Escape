extends SceneTree
## Headless test for the nights and breakthroughs (see SleepRoll): practice
## only makes a skill ripe, a night rolls the level, the wait averages 30 % of
## the fill time, the feeling lines have no numbers, the history is kept.
## Run with: godot --headless -s tests/sleep_roll.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test()
	if failures == 0:
		print("PASS: sleep_roll")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _test() -> void:
	# The average wait is the share of the fill time the design asks for.
	for fill in [5, 10, 20, 50]:
		var base := SleepRoll.base_chance(fill)
		var wait := SleepRoll.expected_wait(base)
		var target := maxf(SleepRoll.MIN_WAIT, SleepRoll.WAIT_SHARE * fill)
		check(absf(wait - target) < 0.05, "fill %d waits about %.2f nights: %.2f" % [fill, target, wait])
	check(SleepRoll.slots(10, "bed") == 3 and SleepRoll.slots(18, "home") == 6, "dream slots")
	check(SleepRoll.quality("home", 9.0, 12.0, 0.0) > SleepRoll.quality("ground", 9.0, 12.0, 0.0), "own bed beats bare ground")

	# Practice makes a skill ripe but gives no level by itself.
	var state := SleepRoll.empty()
	var xp := {"klingen": 0.0}
	SleepRoll.practise(state, "klingen", xp)
	xp["klingen"] = Training.skill_xp_for(2) + 1.0
	check(SleepRoll.earned(state, "klingen", xp) == 0, "practice alone gives no level: %d" % SleepRoll.earned(state, "klingen", xp))
	check(SleepRoll.ripe(state, "klingen", xp), "the skill is ripe")
	# Nights until it breaks through (a sure thing with enough nights).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var nights := 0
	while SleepRoll.earned(state, "klingen", xp) == 0 and nights < 200:
		SleepRoll.practise(state, "klingen", xp)
		SleepRoll.night(state, xp, "bed", 9.0, 10, func(_id): return 12.0, 1, rng)
		nights += 1
	check(SleepRoll.earned(state, "klingen", xp) == 1, "a night gives the level: %d after %d nights" % [SleepRoll.earned(state, "klingen", xp), nights])
	var history := SleepRoll.history_lines(state, "klingen")
	check(history.size() == 1, "the history keeps the past level: %s" % [history])
	check(xp["klingen"] <= Training.skill_xp_for(1) + maxf(SleepRoll.CARRY, SleepRoll.HEAD_START) * Training.skill_step_cost(1) + 0.001, "the training carries over only a little")

	# A skill without an entry (an older hero) is not held back.
	var old := SleepRoll.empty()
	check(SleepRoll.earned(old, "klingen", {"klingen": Training.skill_xp_for(3) + 1.0}) == 3, "older heroes keep their levels")

	# What is saved comes back.
	var back := SleepRoll.checked(JSON.parse_string(JSON.stringify(state)))
	check(back.skills.klingen.earned == state.skills.klingen.earned and back.nights == state.nights, "the state survives a save")

	# The feeling: no digits, changes only with a night.
	var tip := SleepRoll.tip(state, "klingen", xp)
	var digits := RegEx.create_from_string("[0-9]")
	check(tip != "" and digits.search(tip) == null, "the tip has no numbers: %s" % tip)
	check(tip == SleepRoll.tip(state, "klingen", xp), "the tip stays the same between nights")
	check(SleepRoll.band(0.0) == 0 and SleepRoll.band(0.5) == 2 and SleepRoll.band(2.0) == 5, "feeling bands")
	for b in SleepRoll.FEELINGS.size():
		check(SleepRoll.FEELINGS[b].size() >= 5 and SleepRoll.AHEAD[b].size() >= 2, "band %d has lines" % b)
