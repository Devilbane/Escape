extends SceneTree
## The climbing wall's own sounds: every kind in the cue lists can be made, is not silent and not clipped,
## has several different takes, and the cues of a move are in order.

func _initialize() -> void:
	var fails := 0
	var kinds := {}
	for key in WallSounds.CUES:
		var last := -1.0
		for c in WallSounds.CUES[key]:
			kinds[c.kind] = true
			if float(c.at) < last or float(c.at) > 1.0:
				fails += 1
				print("FAIL cues out of order in ", key)
			last = float(c.at)
	for family in ["pull_l", "pull_r", "side_l", "desc_l", "leap", "slip", "arrest", "hammer", "bed", "wake"]:
		if WallSounds.cues(family).is_empty():
			fails += 1
			print("FAIL no cues for ", family)
	for kind in kinds:
		var a := WallSounds.stream(kind, 0)
		var b := WallSounds.stream(kind, 1)
		var peak := 0
		for i in range(0, a.data.size(), 2):
			peak = maxi(peak, absi(a.data.decode_s16(i)))
		if peak < 2000:
			fails += 1
			print("FAIL ", kind, " is silent (peak ", peak, ")")
		if a.data == b.data:
			fails += 1
			print("FAIL ", kind, " has no varied takes")
	print("PASS" if fails == 0 else "FAILED %d" % fails)
	quit(1 if fails > 0 else 0)
