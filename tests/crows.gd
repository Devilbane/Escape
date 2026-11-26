extends SceneTree
## Test of the crows (see Crows): they come to the fields only in autumn and winter and by day, peck about
## on a field, go up together when the hero walks near (a clatter of wings and caws), circle over the fields,
## come down again on another field away from the hero, land at once when the hero leaves them in the
## air, and keep still when he is far. Run with: godot --headless -s tests/crows.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _day_of(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d
	return 0


func _run() -> void:
	var fields: Array[Vector3] = []
	for x in 6:
		for z in 4:
			fields.append(Vector3(x * 8.0, 0.0, z * 8.0))
	var crows := Crows.new(null, fields, 4.0, "test")
	root.add_child(crows)
	await process_frame
	check(crows.flocks.size() >= 1 and crows.flocks.size() <= Crows.MAX_FLOCKS, "one or two flocks (%d)" % crows.flocks.size())
	for flock in crows.flocks:
		var n: int = flock.crows.size()
		check(n >= Crows.FLOCK_SIZE.x and n <= Crows.FLOCK_SIZE.y, "a flock of %d crows" % n)
	var far := Vector3(400, 0, 400)
	# Only in autumn and winter, and only by day.
	for season in ["spring", "summer"]:
		crows.set_season(_day_of(season))
		crows.tick(0.1, far, 12.0)
		check(not crows.active and not crows.visible, "no crows in %s" % season)
	crows.set_season(_day_of("autumn"))
	crows.tick(0.1, far, 12.0)
	check(crows.active and crows.visible, "crows in autumn by day")
	crows.tick(0.1, far, 23.0)
	check(not crows.visible, "they roost at night")
	crows.set_season(_day_of("winter"))
	crows.tick(0.1, far, 12.0)
	check(crows.visible, "crows in winter")
	crows.set_season(_day_of("autumn"))
	# Far from the hero: still.
	var where: Vector3 = crows.crows[0].at
	for k in 200:
		crows.tick(0.1, far, 12.0)
	check(crows.crows[0].at == where and not crows.flying(), "a flock far from the hero keeps still")
	# Near but beyond SHY: they peck about on their field, and stay on the ground.
	var flock: Dictionary = crows.flocks[0]
	var spot: Vector3 = flock.spot
	var hero := spot + Vector3(Crows.SHY + 6.0, 0.0, 0.0)
	var heard := [0, 0]
	crows.cawed.connect(func(f: int, s: String):
		if f == 0:
			heard[0] += 1
			heard[1] += 1 if s == Crows.STARTLED else 0)
	var moved := false
	for k in 600:
		crows.tick(0.1, hero, 12.0)
		moved = moved or crows.crows[0].at != where
		for c: Dictionary in crows.crows:
			if c.flock == 0 and Vector2(c.at.x - spot.x, c.at.z - spot.z).length() > Crows.SPREAD * 1.6:
				check(false, "a pecking crow stays on its field")
	check(flock.state == "ground", "they peck while the hero keeps his distance")
	check(heard[0] >= 2 and heard[1] == 0, "they caw now and then on the ground (%d)" % heard[0])
	# The hero walks up: the flock goes up together.
	var took := [0]
	crows.took_off.connect(func(_f: int): took[0] += 1)
	hero = spot + Vector3(Crows.SHY - 3.0, 0.0, 0.0)
	crows.tick(0.1, hero, 12.0)
	check(took[0] == 1 and flock.state == "air", "the flock takes off when the hero comes close")
	check(heard[1] >= 1, "with a startled caw")
	var peak := 0.0
	var landings := [0]
	crows.landed.connect(func(_f: int): landings[0] += 1)
	var length: float = flock.length
	var t := 0.0
	var finite := true
	while flock.state == "air" and t < length + 5.0:
		crows.tick(0.1, hero, 12.0)
		t += 0.1
		for c: Dictionary in crows.crows:
			if c.flock == 0:
				peak = maxf(peak, c.at.y)
				finite = finite and is_finite(c.at.x) and is_finite(c.at.y) and is_finite(c.at.z)
	check(finite, "no crow goes astray")
	check(peak >= Crows.HEIGHT.x, "they climb over the fields (%.1f m)" % peak)
	check(flock.state == "ground" and landings[0] == 1, "the flock comes down again")
	check(t >= Crows.RISE + Crows.CIRCLE.x, "after circling a while (%.1f s)" % t)
	var landed_at: Vector3 = flock.spot
	check(landed_at != spot and Vector2(landed_at.x - spot.x, landed_at.z - spot.z).length() >= Crows.MOVE_MIN, "on another field")
	check(Vector2(landed_at.x - hero.x, landed_at.z - hero.z).length() >= Crows.SHY, "away from the hero")
	for c: Dictionary in crows.crows:
		if c.flock == 0:
			check(c.at.y <= Crows.FEET + 0.01, "back on the ground")
	# Calm for a while after landing, then wary again.
	check(flock.calm > 0.0, "calm after landing")
	# Leaving the hero's reach in mid-flight: they land at once.
	crows.startle(0)
	crows.tick(0.1, hero, 12.0)
	check(flock.state == "air", "up again")
	crows.tick(0.1, far, 12.0)
	check(flock.state == "ground", "a flock the hero has left lands")
	# Several seconds of play with the real mesh: every instance has a finite transform.
	var mm: MultiMesh = (crows.get_node("CrowMesh") as MultiMeshInstance3D).multimesh
	check(mm.instance_count == crows.crows.size(), "one instance to a crow")
	for i in mm.instance_count:
		check(mm.get_instance_transform(i).origin.is_finite(), "crow %d is drawn somewhere" % i)
	# No fields, no flocks.
	var none := Crows.new(null, [] as Array[Vector3], 4.0, "empty")
	check(none.flocks.is_empty(), "no fields, no crows")
	none.free()
	print("crows: ", "OK" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)
