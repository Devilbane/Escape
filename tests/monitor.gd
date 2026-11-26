extends SceneTree

func _init() -> void:
	var ok := true
	ok = ok and Monitor.pick(1, 2) == 0
	ok = ok and Monitor.pick(2, 2) == 1
	ok = ok and Monitor.pick(3, 2) == 0
	ok = ok and Monitor.pick(0, 2) == 0
	ok = ok and Monitor.pick(1, 0) == 0
	ok = ok and Monitor.wanted_number(PackedStringArray(["--monitor=2"])) == 2
	print("monitor: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
