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
	for spot in WallSpots.GATHER.keys() + ["door"]:
		if not WallSounds.SPOTS.has(spot):
			fails += 1
			print("FAIL no spot sounds for ", spot)
		for c in WallSounds.SPOTS.get(spot, []):
			kinds[c.kind] = true
	for family in ["pull_l", "pull_r", "side_l", "desc_l", "leap", "slip", "arrest", "hammer", "hammer5", "bed", "wake"]:
		if WallSounds.cues(family).is_empty():
			fails += 1
			print("FAIL no cues for ", family)
	for kind in kinds:
		var a := WallSounds.stream(kind, 0)
		var b := WallSounds.stream(kind, 1)
		var peak := 0
		for i in range(0, a.data.size(), 2):
			peak = maxi(peak, absi(a.data.decode_s16(i)))
		if WallSounds.PEAKS.has(kind) and peak < 25000:
			fails += 1
			print("FAIL ", kind, " is not brought up to its loudness (peak ", peak, ")")
		if peak < 2000:
			fails += 1
			print("FAIL ", kind, " is silent (peak ", peak, ")")
		if a.data == b.data:
			fails += 1
			print("FAIL ", kind, " has no varied takes")
	# The five blows of the hammer fall on the hammer_hit keys of the pose, and the steps on the foot's landing.
	var hits := []
	for k: Array in RopeClimbPose.KEYS["hammer5"]:
		if String(k[1]) == "hammer_hit":
			hits.append(float(k[0]))
	var clangs := []
	for c in WallSounds.CUES["hammer5"]:
		if c.kind == "clang":
			clangs.append(float(c.at))
	if hits.size() != 5 or clangs != hits:
		fails += 1
		print("FAIL the clangs ", clangs, " are not on the hammer's blows ", hits)
	var boots := []
	for c in WallSounds.cues("pull_l"):
		if c.kind == "boot":
			boots.append(float(c.at))
	if boots.is_empty() or absf(float(boots[0]) - 0.54) > 0.03:
		fails += 1
		print("FAIL the boot of a pull does not land with the foot")
	print("PASS" if fails == 0 else "FAILED %d" % fails)
	quit(1 if fails > 0 else 0)
