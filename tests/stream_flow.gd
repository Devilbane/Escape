extends SceneTree
## The leaves on the stream (see StreamFlow): real leaves that follow the season, a few sticks, none in winter.
## Run with: godot --headless -s tests/stream_flow.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var flow := StreamFlow.new()
	flow.to = Vector3(0, 0, 10)
	flow.count = 16
	flow.foam_every = 0
	flow.seasonal = true
	flow.palette = StreamFlow.GREEN_LEAVES
	root.add_child(flow)
	await process_frame
	var autumn_day := 0
	var summer_day := 0
	var winter_day := 0
	for d in 400:
		if Weather.is_autumn(d) and autumn_day == 0:
			autumn_day = d
		if Weather.is_winter(d) and winter_day == 0:
			winter_day = d
		if not Weather.is_autumn(d) and not Weather.is_winter(d) and not Weather.is_spring(d) and summer_day == 0:
			summer_day = d
	flow.set_season(autumn_day)
	check(flow._mm.visible_instance_count == 16, "autumn: all the leaves float")
	check(flow._colours[0].r > flow._colours[0].g * 0.9, "autumn leaves are red or gold")
	flow.set_season(summer_day)
	check(flow._mm.visible_instance_count == 8, "summer: fewer leaves")
	check(flow._colours[0].g > flow._colours[0].r, "summer leaves are green")
	flow.set_season(winter_day)
	check(flow._mm.visible_instance_count == 0, "winter: no leaves")
	check(flow._sticks != null and flow._sticks.count == 2, "a couple of sticks drift by")
	check(flow._mm.mesh is QuadMesh, "the leaves are textured leaf quads")
	print("PASS: stream_flow" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
