extends SceneTree
## Headless test for keeping the drawn hero out of walls (see WallClearance): with a big hat,
## a spiked shield and a battle axe, standing, walking, running and blocking against a wall
## face-on, side-on and back to it, no part of the body or the gear sinks into the wall.
## In a doorway the hero walks through as before, and the model is not shoved about.
## Run with: godot --headless --fixed-fps 60 -s tests/wall_clearance.gd

var failures := 0
var game: Node
var frames := 0
## Where the test stands the hero: far from the level's own walls, on a floor of its own.
const SPOT := Vector3(700, 0, 700)
## How far past the wall's face a part may reach (the test's measuring tolerance).
const SLACK := 0.02


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _box(parent: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = at
	return body


## Every vertex of the drawn hero, skinned as it is drawn now, in world space.
func drawn_points(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not WallClearance._shown_in(mi, model):
			continue
		var sk: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin != null else null
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if sk != null and bones != null and weights != null and not pts.is_empty():
				var per: int = bones.size() / pts.size()
				for i in pts.size():
					var p := Vector3.ZERO
					for k in per:
						var w: float = weights[i * per + k]
						if w > 0.0:
							var slot: int = bones[i * per + k]
							var bone: int = mi.skin.get_bind_bone(slot)
							if bone < 0:
								bone = sk.find_bone(mi.skin.get_bind_name(slot))
							p += w * ((sk.get_bone_global_pose(bone) * mi.skin.get_bind_pose(slot)) * pts[i])
					out.append(sk.global_transform * p)
			else:
				for i in pts.size():
					out.append(mi.global_transform * pts[i])
	return out


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _test() -> void:
	var p: Player = game.player
	for id in ["streitaxt", "stachelschild", "baerenkappe", "koenigsumhang"]:
		p.equipped[Items.ALL[id].slot] = id
	p.refresh_stats()
	var stage := Node3D.new()
	game.add_child(stage)
	_box(stage, SPOT + Vector3(0, -0.5, 0), Vector3(30, 1, 30))
	# A wall to the hero's north (+z), its face where the capsule touches it.
	var face := SPOT.z + p.radius + 0.01
	var wall := _box(stage, Vector3(SPOT.x, 1.5, face + 0.1), Vector3(8, 3, 0.2))
	p.controllable = false
	p._anim_hold = 1e6
	p.global_position = SPOT
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await _ticks(10)
	var anim: AnimationPlayer = p._anim
	var worst := -1e9
	var worst_what := ""
	var slowest := 0
	var total := 0
	var samples := 0
	# Facing the wall, side-on both ways and back to it.
	for facing in [0.0, PI * 0.5, -PI * 0.5, PI]:
		for name in ["Idle", "Walking_A", "Running_A", "Blocking", "2H_Melee_Idle"]:
			for k in 4:
				p.global_position = SPOT
				p._model.rotation.y = facing
				anim.play(name)
				anim.seek(anim.get_animation(name).length * k / 4.0, true)
				anim.pause()
				await _ticks(20)
				var t0 := Time.get_ticks_usec()
				p._clearance.tick(p, p._clearance_pivot, p._model, 1.0 / 60.0, true)
				var spent := Time.get_ticks_usec() - t0
				slowest = maxi(slowest, spent)
				total += spent
				samples += 1
				for q in drawn_points(p._model):
					if q.y > SPOT.y + WallClearance.BANDS[0].x and q.z - face > worst:
						worst = q.z - face
						worst_what = "%s facing %.0f°" % [name, rad_to_deg(facing)]
	check(worst <= SLACK, "no part of the hero sinks into the wall (deepest %.3f m, %s)" % [worst, worst_what])
	print("deepest part past the wall: %.3f m (%s); probe %d µs on average, %d µs at most" % [worst, worst_what, total / samples, slowest])
	check(total / samples < 2000, "the probe takes well under a frame (%d µs on average)" % (total / samples))

	# A swollen belly (see BloatedBelly) stays out of the wall as well.
	p.ailments[BloatedBelly.KIND] = 999.0
	p.refresh_stats()
	p._model.rotation.y = 0.0
	anim.play("Idle")
	anim.seek(0.0, true)
	anim.pause()
	await _ticks(20)
	var belly := -1e9
	for q in drawn_points(p._model):
		if q.y > SPOT.y + WallClearance.BANDS[0].x:
			belly = maxf(belly, q.z - face)
	check(belly <= SLACK, "a swollen belly stays out of the wall (deepest %.3f m)" % belly)
	p.ailments.erase(BloatedBelly.KIND)
	p.refresh_stats()

	# Without the clearance the same hero does sink in: the test measures something.
	p._model.rotation.y = 0.0
	anim.play("Running_A")
	anim.seek(0.2, true)
	anim.pause()
	p._clearance.shift = Vector3.ZERO
	p._clearance_pivot.position = Vector3.ZERO
	var sunk := -1e9
	for q in drawn_points(p._model):
		if q.y > SPOT.y + 1.0:
			sunk = maxf(sunk, q.z - face)
	check(sunk > 0.2, "a running hero's head would reach into the wall without it (%.2f m)" % sunk)
	wall.free()

	# Out in the open the model stays on the body.
	await _ticks(30)
	check(p._clearance_pivot.position.length() < 0.01, "away from walls the model stands on the body (%.3f m off)" % p._clearance_pivot.position.length())

	# A doorway (1.4 m between the jambs, as a built house's door): the hero walks through
	# as before, and the model is not thrown about on the way.
	var jamb := Vector3(0.3, 2.0, 0.3)
	_box(stage, SPOT + Vector3(-0.85, 1.0, 2.0), jamb)
	_box(stage, SPOT + Vector3(0.85, 1.0, 2.0), jamb)
	p.global_position = SPOT
	p.reset_physics_interpolation()
	p._model.rotation.y = 0.0
	anim.play("Running_A")
	await _ticks(5)
	var most := 0.0
	for i in 90:
		p.velocity = Vector3(0, 0, 3.0)
		p.move_and_slide()
		most = maxf(most, p._clearance_pivot.position.length())
		await physics_frame
	check(p.global_position.z > SPOT.z + 3.5, "the hero walks through the doorway (z %.2f)" % (p.global_position.z - SPOT.z))
	check(most < 0.5, "the model is not thrown about in the doorway (at most %.2f m off)" % most)
	stage.queue_free()
	print("PASS: wall clearance" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
