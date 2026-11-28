extends SceneTree
## The performance benchmark's helpers (see PerfBenchmark): the summary of a run, and that the places and
## conditions it steps through are complete. Run with: godot --headless -s tests/perf_benchmark.gd

var failed := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	var s := PerfBenchmark.summary([4.0, 2.0, 6.0, 8.0])
	check(is_equal_approx(s.avg, 5.0), "the average is the mean")
	check(is_equal_approx(s.max, 8.0), "the maximum is the highest")
	check(s.p95 <= s.max and s.p95 >= s.avg, "the 95th percentile lies between")
	check(PerfBenchmark.summary([]).max == 0.0, "an empty run has no numbers")
	check(PerfBenchmark.SPOTS.size() == 3, "three places")
	var names := {}
	for c: Dictionary in PerfBenchmark.CONDITIONS:
		names[c.name] = true
		check(c.season in [Weather.SPRING, Weather.SUMMER, Weather.AUTUMN, Weather.WINTER], "%s names a season" % c.name)
		check(c.weather != Weather.RAIN or c.season != Weather.WINTER, "%s: no rain in winter" % c.name)
	check(names.size() == PerfBenchmark.CONDITIONS.size(), "every condition has its own name")
	check(PerfBenchmark.CONDITIONS.any(func(c): return c.hour >= 21.0), "a night is measured")
	print("PASS: perf benchmark" if failed == 0 else "FAILED: %d" % failed)
	quit(1 if failed else 0)
