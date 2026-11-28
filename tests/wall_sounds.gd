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
		if WallSounds.RECORDED.has(kind):
			# A recorded sample: every take exists and has no way to be silent here, and the takes differ.
			for take in WallSounds.RECORDED[kind]:
				if not ResourceLoader.exists("res://assets/sounds/%s.wav" % take):
					fails += 1
					print("FAIL the recorded sound ", take, " is missing")
			if WallSounds.recorded(kind, 0) == WallSounds.recorded(kind, 1) and WallSounds.RECORDED[kind].size() > 1:
				fails += 1
				print("FAIL ", kind, " has no varied takes")
			continue
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
	# Each contact sounds while the pose holds it: the grip when the hand has arrived at the hold and the boot while the
	# foot is down (the moments the poses' keys name; measured on the bones: the hand stops at 0.36, the foot at 0.53).
	var windows := {
		"pull_l": {"grip": ["reach_l", 0.34, 0.42], "boot": ["frog_r", 0.52, 0.60]},
		"side_r": {"grip": ["t_grip_r", 0.40, 0.50], "boot": ["t_foot_r", 0.52, 0.62]},
	}
	for key in windows:
		for kind in windows[key]:
			var w: Array = windows[key][kind]
			var found := false
			for c in WallSounds.cues(key):
				if c.kind == kind and float(c.at) >= float(w[1]) and float(c.at) <= float(w[2]):
					found = true
			if not found:
				fails += 1
				print("FAIL ", kind, " of ", key, " is not within the ", w[0], " key (", w[1], "..", w[2], ")")
	var effort := false
	var gear_clink := false
	var pebbles := false
	for c in WallSounds.cues("pull_l"):
		effort = effort or (c.kind == "grunt" and float(c.at) > 0.6)
		gear_clink = gear_clink or (c.kind == "clink" and bool(c.get("gear", false)))
		pebbles = pebbles or c.kind == "pebbles"
	if not (effort and gear_clink and pebbles):
		fails += 1
		print("FAIL a pull needs its grunt, its gear clink and its pebbles")
	print("PASS" if fails == 0 else "FAILED %d" % fails)
	quit(1 if fails > 0 else 0)
