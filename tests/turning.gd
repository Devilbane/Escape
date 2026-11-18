extends SceneTree
## Headless test: monsters and animals turn in arcs (see Turning), not on the spot.
## Run with: godot --headless -s tests/turning.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# A body that wants the opposite way swings round a little at a time.
	var heading := Vector3(0, 0, 1)
	var want := Vector3(0, 0, -1)
	var rate := Turning.rate(1.0, false)
	var next := Turning.steer(heading, want, 1.0 / 60.0, rate)
	var turned := heading.angle_to(next)
	check(turned > 0.0 and turned <= rate / 60.0 + 0.0001, "one step turns no more than the rate allows")
	check(next.length() > 0.99 and next.length() < 1.01, "the heading stays a unit vector")
	# It gets there in the end, and does not overshoot.
	for i in 600:
		heading = Turning.steer(heading, want, 1.0 / 60.0, rate)
	check(heading.angle_to(want) < 0.001, "the heading ends up on the wanted way")
	# Big bodies turn slower, hunters faster.
	check(Turning.rate(3.0, false) < Turning.rate(1.0, false), "big bodies turn slower than small ones")
	check(Turning.rate(1.0, true) > Turning.rate(1.0, false), "an alert body turns faster")
	check(Turning.rate(0.1, true) <= Turning.MAX_RATE and Turning.rate(9.0, false) >= Turning.MIN_RATE, "the rate stays in range")
	# Pace: full when lined up, never zero when facing away.
	check(is_equal_approx(Turning.pace(Vector3(0, 0, 1), Vector3(0, 0, 1)), 1.0), "full pace when lined up")
	check(is_equal_approx(Turning.pace(Vector3(0, 0, 1), Vector3(0, 0, -1)), Turning.MIN_PACE), "a slow arc when facing away")
	# Walking arc: turning right round keeps moving and covers ground.
	var pos := Vector3.ZERO
	heading = Vector3(0, 0, 1)
	for i in 120:
		heading = Turning.steer(heading, Vector3(0, 0, -1), 1.0 / 60.0, Turning.rate(1.0, true))
		pos += heading * 3.0 * Turning.pace(heading, Vector3(0, 0, -1)) / 60.0
	check(pos.length() > 0.5, "a turn is walked as an arc, not on the spot")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
