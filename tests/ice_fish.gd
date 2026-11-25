extends SceneTree
## The fish under the river's ice (see IceFish): built when the water first freezes, shown while it is
## frozen, hidden in a thaw, and they keep to the open water.
## Run with: godot --headless -s tests/ice_fish.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Fish test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	await _wait(5)
	var school: IceFish = lvl.ice_fish
	check(school != null, "the fish live in the open water all year")
	if school == null:
		quit(1)
		return
	check(school._fish.size() >= 6 and school._fish.size() <= IceFish.MAX_FISH, "a few fish, not a crowd (%d)" % school._fish.size())
	check(school.visible, "the fish show in open water")
	check(school._cover == 0.0, "open water: no ice over the fish")
	# Ripples: a ring starts beside a fish now and then in open water, and none under the ice.
	school.active_range = 1.0e9
	school._wake_near()
	var rings := 0
	var darted := 0
	for i in 120:
		school._stir(0.2)
		var now := 0
		for a in school._ring_age:
			if a < 1.0:
				now += 1
		rings = maxi(rings, now)
		darted = maxi(darted, school._fish.filter(func(f): return f.state != "swim").size())
	check(rings >= 1, "a ring spreads on the water (%d)" % rings)
	check(darted >= 1, "a fish startled by a ring bolts and dives (%d)" % darted)
	# A bolting fish sinks and fades, then is gone, then comes back.
	var scared: Dictionary = {}
	for f in school._fish:
		if f.state != "swim":
			scared = f
			break
	if not scared.is_empty():
		for i in 80:
			school._startled(scared, 0.1)
			if scared.state == "gone":
				break
		check(scared.state == "gone" and not scared.node.visible, "the startled fish dives out of sight")
		scared.timer = 0.01
		for i in 5:
			school._startled(scared, 0.1)
		check(scared.state == "return" or scared.state == "swim", "and comes back later")
		scared.state = "swim"
		scared.node.visible = true
		scared.mat.set_shader_parameter("fade", 1.0)
	game.ice_cover = 1.0
	lvl.set_ice(1.0)
	await _wait(3)
	check(school._cover > 0.9, "the frost veils the fish")
	for i in school._ring_age.size():
		school._ring_age[i] = 1.0
	for i in 60:
		school._stir(0.2)
	var iced := 0
	for a in school._ring_age:
		if a < 1.0:
			iced += 1
	check(iced == 0, "no rings under the ice")
	school.active_range = 1.0e9
	school._wake_near()
	var start: Array[Vector3] = []
	for f in school._fish:
		start.append(f.node.position)
	for i in 120:
		await process_frame
		school._process(0.1)
	var moved := 0
	var heads := 0
	for f in school._fish:
		# The head is the end of the body the fish swims towards.
		var holder: Node3D = f.node
		var model: Node3D = holder.get_child(0)
		var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var a := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Face")).origin
		var b := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Tail_end")).origin
		var heading := Vector3(sin(f.heading), 0, cos(f.heading))
		if (a - b).dot(heading) > 0.0:
			heads += 1
	check(heads == school._fish.size(), "every fish swims head first (%d of %d)" % [heads, school._fish.size()])
	for i in school._fish.size():
		var f: Dictionary = school._fish[i]
		var at: Vector3 = f.node.position
		if at.distance_to(start[i]) > 0.3:
			moved += 1
		check(lvl.pond_shore_at(at) > 0.5, "fish %d keeps to the water (%.2f from the bank)" % [i, lvl.pond_shore_at(at)])
	check(moved >= school._fish.size() / 2, "the fish swim (%d of %d moved)" % [moved, school._fish.size()])
	game.ice_cover = 0.0
	lvl.set_ice(0.0)
	await _wait(3)
	school.active_range = 0.5
	school._wake_near()
	var asleep := 0
	for f in school._fish:
		if not (f.node as Node3D).visible:
			asleep += 1
	check(asleep >= school._fish.size() - 2, "far fish are paused and hidden (%d of %d)" % [asleep, school._fish.size()])
	check(school.visible and school._cover == 0.0, "the thaw brings the fish back into the open")
	# Every river and pond has a fish (the bodies of water, see IceFish.build).
	var bodies := {}
	for f in school._fish:
		bodies[lvl.world_to_cell(f.home)] = true
	check(bodies.size() >= 5, "the fish are spread over the waters (%d spots)" % bodies.size())
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: ice_fish")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
