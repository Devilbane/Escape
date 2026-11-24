extends SceneTree
## Headless test: the stairs of the mage tower (see MageTower, GuildHall) are climbed the ways a player tries:
## - pushing straight up a flight, as on the keys, gets the hero to its top;
## - a click on the steps themselves (halfway up, or the top step) walks the hero from the door onto them.
## Run with: godot --headless --fixed-fps 60 -s tests/mage_tower_stairs.gd

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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _ground(hall: Node3D, local: Vector3) -> float:
	var from := hall.global_transform * (local + Vector3(0, 0.9, 0))
	var to := hall.global_transform * (local - Vector3(0, 1.2, 0))
	var space := (game.level as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return -INF
	return (hall.global_transform.affine_inverse() * (hit.position as Vector3)).y


func _walk(target: Vector3, seconds: float) -> bool:
	game.player.walk_to(target)
	for i in int(seconds * 60.0):
		await physics_frame
		var at: Vector3 = game.player.global_position
		if Vector2(at.x - target.x, at.z - target.z).length() < 0.5 and absf(at.y - target.y) < 0.4:
			return true
	return false


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Mage tower stairs"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level
	var rec: Dictionary = lvl.walk_in.buildings.filter(func(r): return r.kind == MageTower.KIND)[0]
	var hall: Node3D = rec.node
	var lay: Dictionary = rec.layout
	var a: Dictionary = lay.a
	var b: Dictionary = lay.b
	await _climb(hall, Vector3((float(a.x0) + float(a.x1)) * 0.5, lay.floor, float(a.foot) + 0.9), float(lay.up_floor), "the first flight")
	await _climb(hall, Vector3((float(b.x0) + float(b.x1)) * 0.5, lay.up_floor, float(b.foot) + 0.9), float(lay.deck), "the second flight")
	var way := lvl.walk_in.door_points(rec)
	for spot: Array in [["halfway up the first flight", a, 0.5], ["the top step of the first flight", a, 0.95],
			["halfway up the second flight", b, 0.5], ["the top step of the second flight", b, 0.95]]:
		game.player.global_position = way[0]
		game.player.reset_physics_interpolation()
		await _physics(5)
		var f: Dictionary = spot[1]
		var z: float = lerpf(float(f.foot), float(f.top), float(spot[2]))
		var target := hall.global_transform * Vector3((float(f.x0) + float(f.x1)) * 0.5, GuildHall.ramp(f, z), z)
		game.player.walk_to(target)
		var got := false
		for i in 60 * 40:
			await physics_frame
			var d: Vector3 = game.player.global_position - target
			if Vector2(d.x, d.z).length() < 0.6 and absf(d.y) < 0.5:
				got = true
				break
		check(got, "a click on %s walks the hero onto the steps (at %s)" % [spot[0], hall.global_transform.affine_inverse() * game.player.global_position])
	_end()


func _end() -> void:
	print("PASS: mage tower stairs" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Pushes straight along the flight from `from_local` for a while: the hero must get to `want_y`.
func _climb(hall: Node3D, from_local: Vector3, want_y: float, what: String) -> void:
	game.player.global_position = hall.global_transform * from_local
	game.player.reset_physics_interpolation()
	await _physics(10)
	var dir: Vector3 = hall.global_transform.basis * Vector3(0, 0, -1)
	var top_y := -INF
	for i in 60 * 8:
		game.player.steer = dir
		await physics_frame
		top_y = maxf(top_y, (hall.global_transform.affine_inverse() * game.player.global_position).y)
	game.player.steer = Vector3.ZERO
	check(top_y > want_y - 0.3, "%s: pushing straight up it gets the hero to the top (highest %.2f of %.2f)" % [what, top_y, want_y])
