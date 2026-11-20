extends SceneTree
## Headless test for the village's alarm horn (tools/make_horn_sounds.py,
## WarHorn, HornBlow, VillageProps.build_war_horn): the sound is part of the
## game and as long as the code says, the horn prop is built, and in the game
## the horn stands inside the west gate and the guard blows it for an alarm,
## with the bell following after it and one cooldown for both. Whoever blows it
## walks round to the mouthpiece, blows while each blast sounds and steps back
## for a breath between them, and can be called away from it at any time.
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
		check(absf(stream.get_length() - HornBlow.BLAST) < 0.1, "one blast sounds as long as HornBlow.BLAST says, got %.2f" % stream.get_length())
	_check_timeline()
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


## The blasts and the breath between them: each blast is blown (the lips on the
## horn, leaning in) for as long as it is heard, and the blower steps back for a
## breath in the pause.
func _check_timeline() -> void:
	check(HornBlow.BLASTS.size() == 2, "the horn is blown twice")
	var first: float = HornBlow.BLASTS[0]
	var second: float = HornBlow.BLASTS[1]
	check(first + HornBlow.BLAST < second, "the second blast starts after the first has died away")
	check(second + HornBlow.BLAST <= HornBlow.LENGTH + 0.3, "the blowing lasts until the second blast has died away")
	for start: float in HornBlow.BLASTS:
		for f in [0.05, 0.5, 1.5, HornBlow.HEARD - 0.05]:
			var at := HornBlow.at_time(start + f)
			check(float(at.back) < 0.01 and float(at.pose.get("spine", 0.0)) > 10.0, "lips on the mouthpiece %.2f s into a blast" % f)
			check(HornBlow.blowing_at(start + f), "blowing %.2f s into a blast" % f)
	var breath := (first + HornBlow.BLAST + second) * 0.5
	var pause := HornBlow.at_time(breath)
	check(float(pause.back) > HornBlow.BACK - 0.01, "stepped back from the mouthpiece to catch breath")
	check(float(pause.pose.get("arm", 0.0)) < 30.0, "hands off the horn while catching breath")
	check(not HornBlow.blowing_at(breath), "not blowing between the blasts")
	check(float(HornBlow.at_time(HornBlow.LENGTH).back) > HornBlow.BACK - 0.01 and HornBlow.at_time(HornBlow.LENGTH).pose.get("arm", 0.0) == 0.0, "standing easy again at the end")


## The lips (HornBlow.LIPS, moved with the head bone) of a posed rig, in the world.
func _mouth(body: Node3D) -> Vector3:
	var sk := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := sk.find_bone("head")
	var rest := sk.get_bone_global_rest(head)
	var local := rest.affine_inverse() * HornBlow.LIPS
	return sk.global_transform * sk.get_bone_global_pose(head) * local


## The guard runs round to the mouthpiece and blows each blast there, keeping
## clear of the horn; the blasts sound when his lips are on the horn.
func _guard_blows(lvl: Outdoor, guard: Villager) -> void:
	var blow: HornBlow = guard._blow
	var spot := HornBlow.mouth_spot(lvl, lvl.war_horn_at)
	check(lvl.is_open(lvl.world_to_cell(spot)) and not lvl.village_wall.bricks.has(lvl.world_to_cell(spot)), "the mouthpiece can be reached")
	var closest := INF
	var heard: Array[float] = []
	var mouth_off := INF
	var frames_left := 60 * 20
	while guard.blowing_horn() and frames_left > 0:
		var had := blow.blasts
		await _wait(1)
		frames_left -= 1
		if blow.walking:
			closest = minf(closest, Vector2(guard.global_position.x - lvl.war_horn_at.x, guard.global_position.z - lvl.war_horn_at.z).length())
		if blow.blasts > had:
			heard.append(blow.time)
		if not blow.walking and absf(blow.time - (float(HornBlow.BLASTS[0]) + 1.5)) < 0.01:
			var tip := lvl.war_horn_at + Basis(Vector3.UP, WarHorn.facing(lvl, lvl.war_horn_at)) * Vector3(0.95, 1.14, -0.1)
			mouth_off = _mouth(guard).distance_to(tip)
			check(guard.global_position.distance_to(Vector3(spot.x, guard.global_position.y, spot.z)) < 0.05, "the guard blows from the mouthpiece")
	check(closest >= HornBlow.CLEAR - 0.05, "the guard walks round the horn, not through it (came %.2f m near)" % closest)
	check(heard.size() == 2, "two blasts sound, got %d" % heard.size())
	for i in heard.size():
		check(absf(heard[i] - float(HornBlow.BLASTS[i])) < 0.05, "blast %d sounds as the guard blows it" % i)
	check(mouth_off < 0.25, "the guard's lips are on the mouthpiece (%.2f m off)" % mouth_off)
	print("guard: mouth %.2f m off the mouthpiece, came %.2f m near the horn" % [mouth_off, closest])
	check(not guard.blowing_horn() and guard._current_anim == "Idle", "the guard stands easy when the horn is done")


## The hero walks round to the mouthpiece and blows; the village gathers at the
## first blast. Walking off ends it, and before the first blast it costs no cooldown.
func _hero_blows(lvl: Outdoor) -> void:
	var hero: Node3D = game.player
	var away := Basis(Vector3.UP, WarHorn.facing(lvl, lvl.war_horn_at)) * Vector3.RIGHT
	# From the bell's side: the walk goes round the horn.
	hero.global_position = lvl.war_horn_at - away * 2.2
	await _wait(2)
	check(WarHorn.hero_cannot() == "", "the hero may blow the horn")
	var told: Array[String] = []
	var blow := WarHorn.hero_blow(lvl, hero.global_position, func(text: String): told.append(text))
	hero.blow_horn(blow)
	check(WarHorn.hero_cannot() == Lang.t(WarHorn.BUSY_HERO), "no second blowing while the hero blows")
	check(WarHorn.guard(lvl) == null, "the guard leaves the horn to the hero while the hero blows it")
	var closest := INF
	var frames_left := 60 * 10
	while blow.walking and frames_left > 0:
		await _wait(1)
		frames_left -= 1
		closest = minf(closest, Vector2(hero.global_position.x - lvl.war_horn_at.x, hero.global_position.z - lvl.war_horn_at.z).length())
	check(not blow.walking, "the hero gets to the mouthpiece")
	check(closest >= HornBlow.CLEAR - 0.05, "the hero walks round the horn (came %.2f m near)" % closest)
	check(told.is_empty(), "nothing is told before the horn sounds")
	while blow.time < float(HornBlow.BLASTS[0]) + 1.5 and hero.blowing_horn():
		await _wait(1)
	check(told.size() == 1 and blow.blasts == 1, "the village is told at the first blast")
	var tip := lvl.war_horn_at + Basis(Vector3.UP, WarHorn.facing(lvl, lvl.war_horn_at)) * Vector3(0.95, 1.14, -0.1)
	var off := _mouth(hero).distance_to(tip)
	check(off < 0.25, "the hero's lips are on the mouthpiece (%.2f m off)" % off)
	print("hero: mouth %.2f m off the mouthpiece" % off)
	# A step away ends it at once.
	hero.steer = -away
	await _wait(2)
	hero.steer = Vector3.ZERO
	check(not hero.blowing_horn() and blow.stopped, "a step away stops the blowing")
	check(WarHorn.hero_cannot() == Lang.t(WarHorn.TOO_SOON), "once the horn has sounded it has a cooldown")
	# Walking off before the horn has sounded costs no cooldown.
	WarHorn.reset_hero()
	hero.global_position = HornBlow.mouth_spot(lvl, lvl.war_horn_at) + away * 1.5
	await _wait(2)
	var early := WarHorn.hero_blow(lvl, hero.global_position)
	hero.blow_horn(early)
	await _wait(3)
	hero.steer = away
	await _wait(2)
	hero.steer = Vector3.ZERO
	check(early.stopped and early.blasts == 0, "walked off before the first blast")
	check(WarHorn.hero_cannot() == "", "no cooldown when the horn never sounded")


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
	var post := GuardWatch.post(lvl)
	check(lvl.war_horn_at != Vector3.INF, "the village has an alarm horn")
	check(lvl.war_horn_at.distance_to(post) <= Level.TILE * 1.01, "the horn stands right beside the guard's post at the west gate")
	check(gate != null and lvl.village_wall.bricks.has(lvl.world_to_cell(lvl.war_horn_at)) == false, "the horn does not stand in the wall")
	var centre: Vector3 = lvl.spots.square[0]
	check(gate != null and lvl.war_horn_at.distance_to(centre) < gate.global_position.distance_to(centre), "the horn stands inside the wall")
	var guard: Villager = null
	for v in lvl.villagers:
		v._fire_cool = 1.0e9
		if v.role == "4":
			guard = v
	check(guard != null, "the village has a guard")

	# At his post he blows it at once; the bell is held back until the horn has died away.
	VillageBell.reset()
	guard.global_position = post
	guard._start("watch", 30.0)
	check(WarHorn.guard(lvl) == guard, "the guard can blow the horn")
	check(VillageBell.ring(game, "slime", 1000.0), "an alarm rings")
	check(guard.blowing_horn() and not guard._horn_wait, "the guard goes to the horn from his post")
	await _guard_blows(lvl, guard)
	check(not VillageBell.ring(game, "wall", 1001.0), "the horn and the bell share one cooldown")
	check(not VillageBell.ring(game, "breach", 1000.0 + VillageBell.COOLDOWN - 1.0), "no second alarm while the cooldown lasts")

	# Away from it he walks to the horn first and blows it there.
	VillageBell.reset()
	guard._end_horn()
	guard.global_position = post + Vector3(12, 0, 0)
	guard._start("idle", 30.0)
	check(VillageBell.ring(game, "gate", 2000.0), "a second alarm rings after the cooldown")
	check(guard._horn_wait and guard._task == "walk" and guard.get_meta("then", "") == "watch", "the guard walks to the horn")
	guard.global_position = post
	guard._start("watch", 30.0)
	await _wait(3)
	check(guard.blowing_horn() and not guard._horn_wait, "he blows the horn once he is at his post")
	# Called away half way (a slime to fight), he stops blowing at once.
	await _wait(2)
	guard._start("idle", 5.0)
	await _wait(2)
	check(not guard.blowing_horn(), "the guard called away stops blowing the horn")

	# Without a guard able to blow it, only the bell tolls.
	VillageBell.reset()
	guard.eaten = true
	check(WarHorn.guard(lvl) == null, "an eaten guard blows no horn")
	check(not WarHorn.blow(lvl), "no guard, no horn: the bell tolls alone")
	guard.eaten = false
	guard.global_position = lvl.war_horn_at + Vector3(WarHorn.REACH + 10.0, 0, 0)
	check(WarHorn.guard(lvl) == null, "a guard too far from the horn does not blow it")
	VillageBell.reset()

	# The hero can blow the horn too, with a cooldown, and the villagers gather.
	WarHorn._sounded = true
	WarHorn.reset_hero()
	var st := lvl.station_at(lvl.war_horn_at)
	check(st.get("kind", "") == WarHorn.KIND, "the horn is a station the hero can use")
	await _hero_blows(lvl)
	WarHorn.reset_hero()
	game.delete_save(game.save_path())
	print("PASS: war horn" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
