extends SceneTree
## Headless test for the pose of the hero climbing out of a pit (see ClimbPose): the body
## stays clear of the wall that is climbed, and the hands reach the ledge at the hang.
## Run with: godot --headless -s tests/climb_pose.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var model = load("res://assets/characters/Rogue.glb").instantiate()
	root.add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.play("Idle")
	player.seek(0.0, true)
	player.pause()
	await process_frame
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var base := ClimbPose.base_of(sk)
	var worst := 1e9
	var worst_at := 0.0
	var steps := 100
	for i in steps + 1:
		var u := float(i) / steps
		# The hero starts at the wall as the game puts them (the capsule's radius from it).
		var state := ClimbPose.at(u, -2.6, -0.35)
		ClimbPose.apply(sk, base, state.pose)
		await process_frame
		var front := ClimbPose.front_below_ledge(sk, state.height)
		if front < -1e8:
			continue
		var gap: float = -(front + state.forward)
		# The first moments are the hero's own standing at the wall (see clear_of_wall).
		if u > 0.07 and u < ClimbPose.FREE_FROM and gap < worst:
			worst = gap
			worst_at = u
	check(worst >= -0.005, "the body stays clear of the wall all along the climb (closest approach %.3f m at u=%.2f)" % [worst, worst_at])
	# At the hang the hands are on the ledge, not sunk into the wall nor far from it.
	var hang := ClimbPose.at(0.24, -2.6, -0.35)
	ClimbPose.apply(sk, base, hang.pose)
	await process_frame
	var hand := sk.get_bone_global_pose(sk.find_bone("hand.l")).origin
	var top: float = hand.y + hang.height
	var top_z: float = hand.z + hang.forward
	check(absf(top) < 0.25, "the hands are at the height of the ledge at the hang (%.2f m)" % top)
	check(top_z > -0.2 and top_z < 0.4, "the hands are at the ledge's edge at the hang (%.2f m from the wall's face)" % top_z)
	print("PASS: climb pose" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
