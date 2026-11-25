extends SceneTree
## Headless test for Fritz frozen on the market square in the snow (see FrozenFritz): he
## leaves the tavern when the snow lies thick, freezes in his toast with ice, snow and icicles on
## him, cannot sing, only mumbles when talked to, serves birds as a perch, and thaws when the snow
## has melted. With SHOTS=<folder> (and a display) it also takes pictures.
## Run with: godot --headless --fixed-fps 60 -s tests/frozen_fritz.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


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


func _shot(name: String, from: Vector3, to: Vector3, fov := 45.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	cam.make_current()
	await _wait(10)
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	lvl.night = false
	lvl.set_hour(12.0)
	if shots != "":
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
	for line: String in FrozenFritz.MUFFLED:
		check(Lang.EN.has(line), "the muffled line has an English text: %s" % line)
	var fritz: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == FrozenFritz.ROLE:
			fritz = v
	check(fritz != null, "Fritz lives in the village")
	if fritz == null:
		_finish()
		return
	check(not fritz.is_frozen() and fritz._ice == null, "Fritz is not frozen while the snow is away")
	# His mug is part of his look: the tavern code that puts the brewer's mug away never takes it from him.
	var mug := fritz.find_child("Mug", true, false) as Node3D
	check(mug != null and mug.visible, "Fritz holds his mug")
	fritz.hold_mug(false)
	check(mug != null and mug.visible, "Fritz keeps his mug when the tavern puts a mug away")

	# The snow is thick: he goes to the market square (put near it to keep the test short).
	var spot := FrozenFritz.spot(lvl)
	check(spot != Vector3.INF, "the market square has a place for him")
	game.set_weather(Weather.SNOW, 50.0)
	game.snow_cover = 1.0
	fritz.global_position = spot + Vector3(3.0, 0, 0)
	fritz.reset_physics_interpolation()
	fritz._start("sit", 30.0)
	game.player.global_position = spot + Vector3(5.0, 0, 7.0)
	await _wait(200)
	check(fritz.is_frozen(), "Fritz freezes when the snow lies thick")
	check(fritz._ice != null and fritz._ice.get_child_count() >= 15, "there is ice, snow and icicles on him")
	check(not fritz._anim.is_playing() and fritz._current_anim == "frozen", "he is held in his pose")
	# The toast arm really reaches out: the mug is held up and in front, and the icicles hang from it.
	var arm := fritz._ice._bone(fritz._bones(), "handslot.r")
	var shoulder := fritz._ice._bone(fritz._bones(), "upperarm.r")
	check(arm.y - shoulder.y > 0.1 and arm.distance_to(shoulder) > 0.4, "his arm is raised out with the mug (%s, %s)" % [arm, shoulder])
	# Out of view and back (see OffscreenAnim): the animation steps that catch up must not take the arm down.
	var steps := fritz.find_child("OffscreenAnim", true, false) as OffscreenAnim
	steps.rest()
	await _wait(12)
	steps.wake()
	await _wait(3)
	arm = fritz._ice._bone(fritz._bones(), "handslot.r")
	check(arm.y - shoulder.y > 0.1 and arm.distance_to(shoulder) > 0.4, "the arm stays out after he was out of view (%s)" % arm)
	var near_arm := 0
	for icicle: Node in fritz._ice.get_children():
		if icicle is MeshInstance3D and icicle.mesh is CylinderMesh and icicle.mesh.bottom_radius == 0.0 and icicle.position.distance_to(arm) < 0.5:
			near_arm += 1
	check(near_arm >= 3, "icicles hang from the mug and the arm (%d)" % near_arm)
	check(fritz.global_position.distance_to(spot) < 4.0, "he stands on the market square (%s)" % fritz.global_position.distance_to(spot))
	check(not fritz.can_chat() and not fritz.can_remark(), "frozen, he neither chats nor remarks")
	var turned := fritz.rotation.y
	fritz.talk(game.player)
	check(fritz._bubble_time > 0.0, "he mumbles something when talked to")
	await _wait(30)
	check(is_equal_approx(turned, fritz.rotation.y) and fritz._current_anim == "frozen", "he stays stiff when talked to")
	# Bumped via the station path, or greeted: still frozen, still the same pose.
	game._use_station({"kind": "npc", "npc": fritz, "pos": fritz.global_position})
	game.hero_chat.answer(fritz, "hallo")
	await _wait(10)
	check(fritz.is_frozen() and fritz._ice != null and fritz._current_anim == "frozen", "a bump or a greeting leaves him frozen")
	# He cannot sing: no song starts for him.
	check(not fritz.can_chat(), "frozen Fritz is not free for a song")
	game.drinking_songs.stop()
	check(not game.drinking_songs.start_song(lvl), "no drinking song while he is frozen")

	# Birds land on him: his head, his mug and his arm.
	var birds: VillageBirds = lvl.birds
	check(birds != null, "the village has birds")
	if birds != null:
		game.player.global_position = spot + Vector3(9.0, 0, 9.0)
		var points := [fritz.perch_point(0), fritz.perch_point(1), fritz.perch_point(2)]
		check(points[0].y > points[1].y and points[1].y > 1.3 and points[2].y > 1.2, "the perches are on his head, mug and arm (%s)" % [points])
		var seen := 0
		for i in 60:
			await _wait(60)
			seen = maxi(seen, birds.birds.filter(func(b: Dictionary): return b.state == "perch").size())
			if seen > 0:
				break
		check(seen > 0, "a bird lands on frozen Fritz")
		if shots != "":
			await _shot("frozen_fritz_front", fritz.global_position + Vector3(0.6, 1.7, 4.0), fritz.global_position + Vector3(0, 1.35, 0), 40.0)
			await _shot("frozen_fritz_close", fritz.global_position + Vector3(1.5, 2.0, 2.2), fritz.global_position + Vector3(-0.2, 1.5, 0), 40.0)
			await _shot("frozen_fritz_market", fritz.global_position + Vector3(6.0, 6.0, 9.0), fritz.global_position + Vector3(0, 1.2, 0), 55.0)

	# The snow melts: he thaws and walks back to the tavern.
	game.set_weather(Weather.CLEAR, 50.0)
	game.snow_cover = 0.0
	await _wait(150)
	check(not fritz.is_frozen() and fritz._ice == null, "Fritz thaws when the snow has melted")
	check(fritz._anim.is_playing(), "he moves again")
	if birds != null:
		await _wait(30)
		check(birds.feeding.is_empty() or not birds.feeding.get("frozen", false), "the birds stop coming to him")
	_finish()


func _finish() -> void:
	if failures == 0:
		print("PASS: frozen Fritz")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
