extends SceneTree
## Headless test for the village's alarm horn (tools/make_horn_sounds.py,
## WarHorn, VillageProps.build_war_horn): the sound is part of the game and as
## long as the code says, the horn prop is built, and in the game the horn
## stands inside the west gate and the guard blows it for an alarm, with the
## bell following after it and one cooldown for both.
## Run with: godot --headless --fixed-fps 60 -s tests/war_horn.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var stream := load(Sfx.DIR + WarHorn.SOUND + ".wav") as AudioStreamWAV
	check(stream != null, "the horn sound is part of the game")
	if stream:
		check(absf(stream.get_length() - WarHorn.LENGTH) < 0.3, "the horn sounds as long as WarHorn.LENGTH says, got %.2f" % stream.get_length())
	var holder := Node3D.new()
	root.add_child(holder)
	var prop := VillageProps.build_war_horn(holder, Vector3(3, 0, 4), 0.7)
	check(prop != null and prop.mesh != null and prop.mesh.get_surface_count() > 0, "the horn prop has a mesh")
	if prop and prop.mesh:
		var size := prop.mesh.get_aabb().size
		check(size.y > 1.0 and size.x + size.z > 2.0, "the horn is large")
	holder.queue_free()
	seed(11)
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
		await physics_frame


func _run() -> void:
	game.hero_name = "Horn test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var gate := GuardWatch.west_gate(lvl)
	check(lvl.war_horn_at != Vector3.INF, "the village has an alarm horn")
	check(gate != null and lvl.war_horn_at.distance_to(gate.global_position) < WarHorn.GATE_MAX * Level.TILE + 0.1, "the horn stands near the west gate")
	var guard: Villager = null
	for v in lvl.villagers:
		v._fire_cool = 1.0e9
		if v.role == "4":
			guard = v
	check(guard != null, "the village has a guard")

	# The guard on his round blows the horn; the bell is held back until it has died away.
	VillageBell.reset()
	guard.global_position = GuardWatch.post(lvl)
	guard._start("watch", 30.0)
	check(WarHorn.guard(lvl) == guard, "the guard can blow the horn")
	check(VillageBell.ring(game, "slime", 1000.0), "an alarm rings")
	check(guard._horn_left > 0.0, "the guard blows the horn")
	check(not VillageBell.ring(game, "wall", 1001.0), "the horn and the bell share one cooldown")
	check(not VillageBell.ring(game, "breach", 1000.0 + VillageBell.COOLDOWN - 1.0), "no second alarm while the cooldown lasts")
	check(VillageBell.ring(game, "gate", 1000.0 + VillageBell.COOLDOWN + 1.0), "it sounds again after the cooldown")

	# Without a guard able to blow it, only the bell tolls.
	VillageBell.reset()
	guard.eaten = true
	check(WarHorn.guard(lvl) == null, "an eaten guard blows no horn")
	check(WarHorn.blow(lvl) == 0.0, "no horn, no wait before the bell")
	guard.eaten = false
	guard.global_position = lvl.war_horn_at + Vector3(WarHorn.REACH + 10.0, 0, 0)
	check(WarHorn.guard(lvl) == null, "a guard too far from the horn does not blow it")
	VillageBell.reset()
	game.delete_save(game.save_path())
	print("PASS: war horn" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
