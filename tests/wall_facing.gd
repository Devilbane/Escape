extends SceneTree
## The climber faces the wall with the back to the camera, at rest and after the animation has run for a while
## and, asleep in the hammock, up at the sky (the animation resets his rotation every tick, which once turned him round to face the viewer).

func _initialize() -> void:
	Lang.language = "en"
	var map := WallMap.load_file("res://walls/sample_three_paths.txt")
	var stage := WallStage.new()
	root.size = Vector2i(640, 360)
	root.add_child(stage)
	stage.size = Vector2(640, 360)
	stage.setup(map, 20, false, "clear", 30)
	var failures := 0
	for i in 12:
		await process_frame
	var forward := stage.climber.model.global_transform.basis.z
	if forward.z > -0.9:
		failures += 1
		print("FAIL: the climber does not face the wall at rest (forward ", forward, ")")
	# In the middle of a move.
	var moved := false
	for dir in [WallMap.UP, WallMap.RIGHT, WallMap.LEFT]:
		if stage.try_move(dir, 0.0, 1.0) != WallClimb.Outcome.BLOCKED:
			moved = true
			break
	if not moved:
		failures += 1
		print("FAIL: no move could be made")
	await create_timer(0.1).timeout
	if not stage.busy():
		failures += 1
		print("FAIL: the move was over too soon to look at it")
	# The model's forward is its local +z; the wall lies on the far side from the camera (-z).
	forward = stage.climber.model.global_transform.basis.z
	if forward.z > -0.9:
		failures += 1
		print("FAIL: the climber does not face the wall in a move (forward ", forward, ")")
	# In the hammock he lies on his back: his face (forward) looks up at the sky.
	stage._queue.clear()
	stage._queue.append({"key": "bed", "secs": 2.0, "from": stage.feet, "to": stage.feet})
	await create_timer(0.5).timeout
	forward = stage.climber.model.global_transform.basis.z
	if forward.y < 0.9:
		failures += 1
		print("FAIL: the sleeping climber does not face the sky (forward ", forward, ")")
	print("PASS" if failures == 0 else "FAILED")
	quit(failures)
