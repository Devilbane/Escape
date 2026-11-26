extends SceneTree
## Headless test for the seats in the tavern and the mage tower (see Seats.add_indoor): every chair, stool,
## bench and sofa is a seat the hero sits on by running into it, with the hips over the seat at its height,
## and gets up again clear of the furniture; the seats are no wider than the hero's seat needs.
## Run with: godot --headless --fixed-fps 60 -s tests/hall_seats.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	WalkIn.lock_halls = false
	Storage.use(Storage.Memory.new())
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


func _free(at: Vector3, radius: float) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), at + Vector3(0, 0.75, 0))
	query.exclude = [(game.player as CollisionObject3D).get_rid()]
	var hit := (game.level as Node3D).get_world_3d().direct_space_state.intersect_shape(query, 2)
	for h in hit:
		var cs: Node = h.collider.get_child(h.shape)
		print('  hit ', at, ' ', h.collider.get_parent(), ' ', cs.shape.size if cs is CollisionShape3D and cs.shape is BoxShape3D else '', ' ', cs.global_position)
	return hit.is_empty()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Seat test"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var p: Player = game.player
	var seats: Array = lvl.stations.filter(func(s): return s.kind == Seats.KIND and s.has("indoor"))
	# The tavern's and the mage tower's, the guildhall's stools, the houses' stools and the smith's.
	check(seats.size() >= 40, "the halls and houses have their seats (%d)" % seats.size())
	var kinds := {}
	for seat: Dictionary in seats:
		kinds[kind_of(lvl, seat)] = true
	for kind: String in ["tavern", MageTower.KIND, "guild", "house"]:
		check(kinds.has(kind), "there are seats in the %s" % kind)
	for seat: Dictionary in seats:
		var kind := kind_of(lvl, seat)
		var out := Seats.stand_spot(seat, lvl, p.radius)
		check(_free(out, p.radius - 0.05), "%s: one gets up clear of the furniture at %s" % [kind, seat.pos])
		p.global_position = out
		p.reset_physics_interpolation()
		await _wait(2)
		game._use_station(seat)
		await _wait(70)
		check(p.is_seated(), "%s: the hero sits at %s" % [kind, seat.pos])
		var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0]
		var hips: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips")).origin
		var along := Seats.front(seat)
		var off: Vector3 = hips - (seat.pos as Vector3)
		check(absf(off.dot(along)) < 0.15 and absf(off.dot(along.cross(Vector3.UP))) < 0.15, "%s: the hips are over the seat at %s (off by %s)" % [kind, seat.pos, off])
		check(absf(off.y - 0.48) < 0.1, "%s: and at the height of the seat (%.2f over the floor)" % [kind, off.y])
		p.stand_up()
		await _wait(60)
	# A click on a seat walks the hero to where one gets up from it and sits them down there; a bump
	# against something beside a seat (a rail, a wall) seats no one.
	var tried := {}
	for i in seats.size():
		var seat: Dictionary = seats[i]
		var kind := kind_of(lvl, seat)
		var key := "%s%d" % [kind, int(seat.pos.y)]
		if tried.has(key) or i == 0:
			continue
		var other: Dictionary = seats[i - 1]
		if kind_of(lvl, other) != kind or absf(other.pos.y - seat.pos.y) > 0.3 or (other.pos as Vector3).distance_to(seat.pos) > 6.0:
			continue
		tried[key] = true
		p.stand_up()
		await _wait(60)
		p.global_position = Seats.stand_spot(other, lvl, p.radius)
		p.reset_physics_interpolation()
		await _wait(3)
		game._click(seat.pos)
		var sat := false
		for t in 60 * 15:
			await physics_frame
			if p.is_seated():
				sat = true
				break
		await _wait(80)
		check(sat and p.is_seated(), "%s: a click on the seat at %s walks the hero there and sits them down (at %s)" % [kind, seat.pos, p.global_position])
		var spot := Seats.sit_spot(seat)
		check(Vector2(p.global_position.x - spot.x, p.global_position.z - spot.z).length() < 0.1, "%s: and onto its sitting place (at %s, wanted %s, from %s)" % [kind, p.global_position, spot, other.pos])
		p.stand_up()
		await _wait(60)
		check(not p.is_seated() and _free(p.global_position, p.radius - 0.05), "%s: getting up steps out clear of the furniture" % kind)
	check(tried.size() >= 3, "clicks were tried on seats of several halls (%d)" % tried.size())
	# No little table stands about without a use: the smith's and the guildhall cellar's are gone.
	for rec in lvl.walk_in.buildings:
		check((rec.node as Node3D).find_child("SmithTable", true, false) == null, "no little table in the smithy")
	game.delete_save(game.save_path())
	print("PASS: hall seats" if failures == 0 else "FAILED: hall seats")
	quit(failures)


## The kind of the hall a seat stands in.
func kind_of(lvl: Outdoor, seat: Dictionary) -> String:
	for rec in lvl.walk_in.buildings:
		var node: Node3D = rec.node
		var local := node.global_transform.affine_inverse() * (seat.pos as Vector3)
		if absf(local.x) < 6.0 and absf(local.z) < 6.0 and local.y > -3.5 and local.y < 8.0:
			return String(rec.kind)
	return ""
