extends SceneTree
## Measures ClimbPose.CLEAR: for each fiftieth of the climb, how far forward the hero may
## stand so no part of the body below the ledge top sinks into the wall (a margin of
## MARGIN metres is kept). Prints the array to paste into scripts/climb_pose.gd.
## Run with: godot --headless -s tools/climb_clearance.gd
const MARGIN := 0.05


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
	var limits := []
	for i in ClimbPose.CLEAR_STEPS + 1:
		var u := float(i) / ClimbPose.CLEAR_STEPS
		var state := ClimbPose.at(u, -2.6, -0.4)
		ClimbPose.apply(sk, base, state.pose)
		await process_frame
		var front := ClimbPose.front_below_ledge(sk, state.height)
		limits.append(snappedf(-(front + MARGIN) if front > -1e8 and u < ClimbPose.FREE_FROM else 2.0, 0.01))
	print("const CLEAR := ", limits)
	quit()
