extends SceneTree
## Headless test for the slimes' sounds (tools/make_slime_sounds.py,
## SlimeSounds): every take is part of the game and short, bigger slimes sound
## lower and louder, far slimes are silent, and a crowd stays within budget.
## Run with: godot --headless -s tests/slime_sounds.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for pair in [["slime_glide_%d", SlimeSounds.GLIDES], ["slime_attack_%d", SlimeSounds.ATTACKS]]:
		for i in pair[1]:
			var path: String = Sfx.DIR + (pair[0] % i) + ".wav"
			var stream := load(path) as AudioStreamWAV
			check(stream != null, "%s is part of the game" % path)
			if stream:
				check(stream.get_length() > 0.1 and stream.get_length() < 1.0, "%s is short" % path)
	check(SlimeSounds.pitch_for(2.6) < SlimeSounds.pitch_for(1.0), "a big slime sounds lower")
	check(SlimeSounds.pitch_for(0.5) > SlimeSounds.pitch_for(1.0), "a small slime sounds higher")
	check(SlimeSounds.loudness_db(2.6) > SlimeSounds.loudness_db(1.0), "a big slime is louder")
	check(SlimeSounds.loudness_db(100.0) <= 6.0 and SlimeSounds.loudness_db(0.01) >= -6.0, "loudness is capped")
	check(SlimeSounds.distance_db(1.0) == 0.0, "close by is full volume")
	check(SlimeSounds.distance_db(8.0) < 0.0, "farther is quieter")
	check(SlimeSounds.distance_db(SlimeSounds.HEARD_FROM) == -INF, "out of hearing is silent")
	check(SlimeSounds.glide_gap(2.6) > SlimeSounds.glide_gap(1.0), "a big slime slurps slower")
	var allowed := 0
	for i in 20:
		if SlimeSounds.budget(100.0):
			allowed += 1
	check(allowed == SlimeSounds.MAX_PER_WINDOW, "a crowd gets %d sounds per window" % SlimeSounds.MAX_PER_WINDOW)
	check(SlimeSounds.budget(100.0 + SlimeSounds.WINDOW + 0.1), "the budget refills")
	if failures == 0:
		print("PASS: slime sounds")
	quit(1 if failures > 0 else 0)
