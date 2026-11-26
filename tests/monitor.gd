extends SceneTree

func _init() -> void:
	var ok := true
	ok = ok and Monitor.pick(1, 2) == 0
	ok = ok and Monitor.pick(2, 2) == 1
	ok = ok and Monitor.pick(3, 2) == 0
	ok = ok and Monitor.pick(0, 2) == 0
	ok = ok and Monitor.pick(1, 0) == 0
	ok = ok and Monitor.wanted_number(PackedStringArray(["--monitor=2"])) == 2
	# The mode button visits every mode once and comes round again; the monitor button wraps.
	var seen := {}
	var m: String = Monitor.MAXIMIZED
	for i in Monitor.MODES.size():
		seen[m] = true
		m = Monitor.next_mode(m)
	ok = ok and seen.size() == Monitor.MODES.size() and m == Monitor.MAXIMIZED
	ok = ok and Monitor.next_monitor(1, 2) == 2 and Monitor.next_monitor(2, 2) == 1 and Monitor.next_monitor(1, 1) == 1
	for which: String in Monitor.MODES:
		ok = ok and Monitor.NAMES.has(which) and Monitor.HINTS.has(which)
		ok = ok and (which == Monitor.MAXIMIZED or which in [Monitor.BORDERLESS, Monitor.FULLSCREEN] or Monitor.SIZES.has(which))
	print("monitor: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
