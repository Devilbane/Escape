extends SceneTree
## Headless test for the geese's voices (tools/make_goose_sounds.py, GooseVoice): every take is part of the
## game and short, far geese are silent, and a flock waking together stays within the sound budget.
## Run with: godot --headless -s tests/goose_voice.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for pair in [["goose_honk_%d", GooseVoice.HONKS], ["goose_alarm_%d", GooseVoice.ALARMS]]:
		for i in pair[1]:
			var path: String = Sfx.DIR + (pair[0] % i) + ".wav"
			var stream := load(path) as AudioStreamWAV
			check(stream != null, "%s is part of the game" % path)
			if stream:
				check(stream.get_length() > 0.2 and stream.get_length() < 1.6, "%s is short" % path)
	check(GooseVoice.distance_db(1.0) == 0.0, "close by is full volume")
	check(GooseVoice.distance_db(15.0) < 0.0, "farther is quieter")
	check(GooseVoice.distance_db(GooseVoice.HEARD_FROM) == -INF, "out of hearing is silent")
	var allowed := 0
	for i in 20:
		if GooseVoice.budget(100.0):
			allowed += 1
	check(allowed == GooseVoice.MAX_PER_WINDOW, "a flock gets %d sounds per window" % GooseVoice.MAX_PER_WINDOW)
	check(GooseVoice.budget(100.0 + GooseVoice.WINDOW + 0.1), "the budget refills")
	if failures == 0:
		print("PASS: goose voice")
	quit(1 if failures > 0 else 0)
