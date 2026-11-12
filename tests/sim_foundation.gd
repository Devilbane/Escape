extends SceneTree
## Headless test for the building blocks of the online game: SimRng, SimClock
## and Commands (scripts/sim/). Run with: godot --headless -s tests/sim_foundation.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# Same seed, same rolls; a different seed differs.
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	var same := true
	for i in 50:
		same = same and a.roll() == b.roll()
	check(same, "the same seed gives the same rolls")
	check(SimRng.new(43).roll() != SimRng.new(42).roll(), "another seed gives other rolls")

	# Saving and loading carries on with the same rolls.
	var c := SimRng.new(7)
	for i in 10:
		c.roll()
	var restored := SimRng.from_save(JSON.parse_string(JSON.stringify(c.for_save())))
	var carries := true
	for i in 20:
		carries = carries and c.range_int(1, 1000) == restored.range_int(1, 1000)
	check(carries, "a saved source carries on with the same rolls")

	# Streams are independent of each other and of the parent.
	var parent := SimRng.new(5)
	var before := SimRng.new(5).roll()
	parent.stream("loot").roll()
	check(parent.roll() == before, "taking a stream does not use up the parent")
	check(parent.stream("loot").roll() == SimRng.new(5).stream("loot").roll(), "a stream is repeatable")
	check(parent.stream("loot").roll() != parent.stream("ai").roll(), "streams differ by name")

	var r := SimRng.new(3)
	var in_range := true
	for i in 200:
		var n := r.range_int(2, 4)
		in_range = in_range and n >= 2 and n <= 4
	check(in_range, "range_int stays in range")
	check(r.pick([]) == null, "pick of nothing is null")
	check(r.pick([9]) == 9, "pick of one is that one")

	# The clock turns seconds into whole ticks without losing any.
	var clock := SimClock.new()
	var ticks := 0
	for i in 100:
		ticks += clock.advance(0.016)
	check(ticks == clock.tick, "ticks add up")
	check(absf(clock.seconds() - 1.6) <= SimClock.TICK_SECONDS + 0.001, "the clock follows real time")
	check(clock.advance(-1.0) == 0, "time does not run backwards")
	var clock2 := SimClock.new()
	clock2.load_from(clock.for_save())
	check(clock2.tick == clock.tick, "the clock round-trips through a save")

	# Commands: good ones pass, bad ones say why.
	check(Commands.check(Commands.make("move", {"dir": Vector2(1, 0)})) == "", "a move is fine")
	check(Commands.check(Commands.make("attack", {"target": 12})) == "", "an attack is fine")
	check(Commands.check(Commands.make("say", {"text": "hello"})) == "", "speech is fine")
	check(Commands.check(5) != "", "a number is not a command")
	check(Commands.check({"kind": "fly"}) != "", "an unknown kind is refused")
	check(Commands.check(Commands.make("attack", {})) != "", "a missing field is refused")
	check(Commands.check(Commands.make("attack", {"target": "x"})) != "", "a wrong type is refused")
	check(Commands.check(Commands.make("attack", {"target": 1, "cheat": 1})) != "", "an extra field is refused")
	check(Commands.check(Commands.make("move", {"dir": Vector2(5, 5)})) != "", "a too fast move is refused")
	check(Commands.check(Commands.make("move", {"dir": Vector2(INF, 0)})) != "", "a non-finite move is refused")
	check(Commands.check(Commands.make("drop_item", {"slot": 0, "count": 0})) != "", "a zero count is refused")
	check(Commands.check(Commands.make("use_item", {"slot": -1})) != "", "a negative slot is refused")
	check(Commands.check(Commands.make("say", {"text": "x".repeat(500)})) != "", "long speech is refused")
	for kind in Commands.KINDS:
		check(Commands.KINDS[kind] is Dictionary, "kind %s has a schema" % kind)

	if failures == 0:
		print("PASS: sim_foundation")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
