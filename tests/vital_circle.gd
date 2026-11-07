extends SceneTree
## Headless test: the circle of a vital blow (see VitalCircle). As the hero
## leaps, the weapon swings down and round in one full circle with a streak of
## light, and is back on the animation's pose when the chop lands.
## - The angle runs from 0 to a full turn within CIRCLE_TIME and is 0 after, so
##   the circle ends exactly on the animation's pose.
## - The circle fits in the time the blade needs to land: it costs no time.
## - Every melee weapon (and the bare dagger) gets a circle, with a blade end
##   away from the grip; the circle starts with the vital strike and goes
##   again with the next one.
## - Mid-circle the weapon is turned away from its rest pose and a streak is
##   drawn; afterwards the weapon is back at rest and the streak is gone.
## - The damage and the cooldown of the vital blow are untouched.
## Run with: godot --headless --fixed-fps 60 -s tests/vital_circle.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _test() -> void:
	# The curve.
	check(VitalCircle.angle_at(0.0) == 0.0, "the circle starts at rest")
	check(VitalCircle.angle_at(VitalCircle.CIRCLE_TIME * 0.999) > TAU * 0.99, "it ends a full turn round")
	check(VitalCircle.angle_at(VitalCircle.CIRCLE_TIME) == 0.0 and VitalCircle.angle_at(1.0) == 0.0, "afterwards it is the animation's pose again")
	var last := 0.0
	var steady := true
	for i in 30:
		var a := VitalCircle.angle_at(VitalCircle.CIRCLE_TIME * i / 30.0)
		steady = steady and a >= last
		last = a
	check(steady, "the weapon only ever turns on")
	check(VitalCircle.CIRCLE_TIME < Player.VITAL_HIT, "the circle is over before the blade lands")
	check(Player.VITAL_HIT <= 0.4 + 0.001, "the blow lands as fast as before")

	var player: Player = game.player
	var level: Node = game.level
	player.power = 4
	# A hero without a model part to swing gets no circle.
	check(VitalCircle.start(null, level, Vector3.FORWARD) == null, "no hero, no circle")

	for weapon in ["", "schwert", "axt", "langschwert", "streitaxt", "streitkolben", "kriegshammer"]:
		if weapon == "":
			player.unequip("waffe")
		else:
			player.bag.append(weapon)
			player.equip(weapon)
		await _wait(2)
		var part := VitalCircle.weapon_part(player)
		check(part != null, "'%s' has a part to swing" % weapon)
		if part == null:
			continue
		check(VitalCircle.blade_end(part).length() > 0.1, "'%s' has a blade end away from the grip" % weapon)
		var rest := part.transform
		var circle := VitalCircle.start(player, level, player.facing())
		check(circle != null, "'%s' circles" % weapon)
		# A quarter of the way round the weapon stands off its rest pose.
		var streaks := 0
		var off := false
		for i in 12:
			await process_frame
			off = off or not part.transform.basis.is_equal_approx(rest.basis)
			for c in level.get_children():
				if c is MeshInstance3D and c.mesh is ImmediateMesh and c.mesh.get_surface_count() > 0:
					streaks += 1
		check(off, "'%s' is swung off its rest pose" % weapon)
		check(streaks > 0, "'%s' leaves a streak of light" % weapon)
		await _wait(60)
		check(not is_instance_valid(circle), "'%s' circle frees itself" % weapon)
		check(part.transform.is_equal_approx(rest), "'%s' is back at rest" % weapon)
		var left := 0
		for c in level.get_children():
			if c is MeshInstance3D and c.mesh is ImmediateMesh:
				left += 1
		check(left == 0, "'%s' leaves no streak behind" % weapon)

	# A real vital strike starts the circle, and does what it did before.
	player.bag.append("schwert")
	player.equip("schwert")
	MonsterLore.kills["krieger"] = 1000
	for e in game.level.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.level.enemies.clear()
	var foe := Enemy.new()
	foe.kind = "krieger"
	foe.level = game.level
	game.level.add_child(foe)
	game.level.enemies.append(foe)
	player.face(Vector3(0, 0, 1))
	player._auto_cooldown = 99.0
	foe.hp = 500
	foe.hardening = 0
	foe._awake = false
	foe.attack_slow = 1.0
	foe.global_position = player.global_position + Vector3(0, 0, 1.6)
	var started := false
	for i in 40:
		player._attack_cooldown = 0.0
		player.melee()
		if player._current_anim == Player.VITAL_ANIM:
			started = player.get_node_or_null("VitalCircle") != null
			check(is_equal_approx(player._attack_cooldown, Player.VITAL_HIT + 0.35), "the vital blow's cooldown is untouched")
			break
		await _wait(40)
	check(started, "a vital strike starts the circle")
	await _wait(90)
	check(player.get_node_or_null("VitalCircle") == null, "the circle is gone after the blow")

	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
