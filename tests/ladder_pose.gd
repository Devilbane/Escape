extends SceneTree
## Headless test for the hero's ladder climb (see LadderPose): hand over hand up the rungs,
## left and right taking turns, the pull-over onto the top and the hop off at the bottom.
## Run with: godot --headless -s tests/ladder_pose.gd

## The rails stand this far before the edge (HouseSketcher._ladder: THICK / 2 + 0.08).
const RAIL_FORWARD := -0.18

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("  ok: ", what)


func _initialize() -> void:
	for tall in [HouseSketch.STOREY_HEIGHT, HouseSketch.DEPTH]:
		_keys(tall)
	var model = load("res://assets/characters/Rogue.glb").instantiate()
	root.add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.play("Idle")
	player.seek(0.0, true)
	player.pause()
	await process_frame
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var base := ClimbPose.base_of(sk)
	# Each arm its own angle: a pose with arm_l / arm_r turns the two arms apart.
	ClimbPose.apply(sk, base, LadderPose.pose("rung_l"))
	var high_l := _hand(sk, "l")
	var low_r := _hand(sk, "r")
	check(high_l.y > low_r.y + 0.1, "on a rung one hand reaches above the other (%.2f, %.2f)" % [high_l.y, low_r.y])
	ClimbPose.apply(sk, base, LadderPose.pose("rung_r"))
	check(_hand(sk, "r").y > _hand(sk, "l").y + 0.1, "and on the next rung the other one")
	# The reaching hand is at the rails, not in the air before them or through the wall.
	var reach := high_l.z + LadderPose.RUNG_FORWARD
	check(reach > RAIL_FORWARD - 0.2 and reach < RAIL_FORWARD + 0.12, "the reaching hand is at the rails (%.2f m from the edge)" % reach)
	ClimbPose.apply(sk, base, {"arm": 90.0})
	var both := _hand(sk, "l")
	ClimbPose.apply(sk, base, {"arm_l": 90.0, "arm_r": 90.0})
	check(both.distance_to(_hand(sk, "l")) < 0.001, "arm_l / arm_r mean the same as arm for both")
	print("PASS: ladder pose" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The climbs up and down a ladder `tall` metres high.
func _keys(tall: float) -> void:
	var up := LadderPose.up_keys(tall, -0.7)
	var down := LadderPose.down_keys(tall, LadderPose.TOP_FORWARD)
	for keys: Array in [up, down]:
		var ordered := true
		for i in range(1, keys.size()):
			ordered = ordered and float(keys[i][0]) > float(keys[i - 1][0])
		check(ordered, "the keys of a %.1f m climb follow one another" % tall)
		var low := 1e9
		var high := -1e9
		var t := 0.0
		while t <= LadderPose.length(keys):
			var s := LadderPose.at(keys, t)
			low = minf(low, s.height)
			high = maxf(high, s.height)
			t += 1.0 / 60.0
		check(low > -0.01 and high < tall + 0.01, "the climb stays between the foot and the top (%.2f..%.2f)" % [low, high])
	var first := LadderPose.at(up, 0.0)
	check(is_equal_approx(first.forward, -0.7) and first.height == 0.0 and first.side == 1.0, "a climb starts where the hero stands")
	var last := LadderPose.at(up, LadderPose.length(up))
	check(is_equal_approx(last.forward, LadderPose.TOP_FORWARD) and is_equal_approx(last.height, tall) and _standing(last.pose),
		"up a %.1f m ladder the hero stands on the top at the end" % tall)
	check(LadderPose.at(up, 0.5).side == 0.0, "and is in line with the rungs once on them")
	# On the rungs: feet on a rung at each key, the reaching hand changing sides each rung.
	var rungs := 0
	var turns := true
	var last_high := ""
	for k: Array in up:
		if float(k[1]) == LadderPose.RUNG_FORWARD and float(k[2]) > 0.0:
			rungs += 1
			check(is_equal_approx(fmod(float(k[2]), LadderPose.RUNG), 0.0) or is_equal_approx(fmod(float(k[2]), LadderPose.RUNG), LadderPose.RUNG), "feet on a rung at %.2f m" % k[2])
			var high := "l" if float(k[3].arm_l) > float(k[3].arm_r) else "r"
			turns = turns and high != last_high
			last_high = high
	check(rungs == LadderPose.rungs_for(tall) and rungs >= 6, "a %.1f m ladder takes %d rungs" % [tall, rungs])
	check(turns, "left and right hands take turns")
	# The pull-over: the feet are still on the rungs below the edge while leaning over.
	var over: Array = up[up.size() - 4]
	check(float(over[2]) < tall and float(over[1]) < 0.0, "the pull-over starts on the rungs below the edge")
	# Down: the hop off the last rungs lands before the ladder, in a crouch first.
	var end := LadderPose.at(down, LadderPose.length(down))
	check(end.height == 0.0 and end.forward < LadderPose.RUNG_FORWARD - 0.3 and _standing(end.pose), "down the ladder the hero hops off and lands before it (%.2f)" % end.forward)
	var let_go := 0.0
	var landed := 0.0
	for k: Array in down:
		if k[3] == LadderPose.POSES["let_go"]:
			let_go = float(k[0])
		if float(k[4]) > 0.0:
			landed = float(k[0])
	var mid := LadderPose.at(down, (let_go + landed) * 0.5)
	var start := LadderPose.at(down, let_go)
	check(landed > let_go and mid.height > start.height * 0.5, "the hop arcs up, not a plain drop (%.2f at mid-air)" % mid.height)
	check(start.height > LadderPose.RUNG, "the hero lets go a rung or two above the ground (%.2f)" % start.height)
	check(LadderPose.at(down, landed + 0.12).pose.get("hips_y", 0.0) < -0.1, "and lands in a crouch")


## Whether `pose` is the plain standing pose (every angle 0).
func _standing(pose: Dictionary) -> bool:
	for k in pose:
		if absf(float(pose[k])) > 0.001:
			return false
	return true


func _hand(sk: Skeleton3D, side: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone("hand." + side)).origin
