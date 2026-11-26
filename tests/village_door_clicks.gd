extends SceneTree
## Headless test: a real mouse click on the door of the mage tower (the click ray through its body at several
## heights, see Game._mouse_to_floor, WalkIn.door_under_ray) walks the hero in, not into the wall.
## Run with: godot --headless --fixed-fps 60 -s tests/village_door_clicks.gd

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


func _try(hall: Node3D, rec: Dictionary, h: float) -> void:
	var way: Array = game.level.walk_in.door_points(rec)
	game.player.global_position = way[0] + hall.global_transform.basis * Vector3(0, 0, 4.0)
	game.player.reset_physics_interpolation()
	await _physics(20)
	var d: Vector3 = rec.door
	var world: Vector3 = hall.global_transform * Vector3(d.x, h, float(rec.wall_out))
	var cp: Vector3 = game.camera.global_position
	var dr: Vector3 = (world - cp).normalized()
	var pt: Variant = game.level.walk_in.door_under_ray(cp, dr)
	check(pt != null, "a ray through the door at %.1f m meets the door" % h)
	if pt == null:
		return
	game._click(pt)
	for i in 60 * 20:
		await physics_frame
		if game.player.path.is_empty():
			break
	await _physics(30)
	var local: Vector3 = hall.global_transform.affine_inverse() * game.player.global_position
	check(local.z < float(rec.wall_out) - 0.4 and not game.level.walk_in.building_at(game.player.global_position, 0.1).is_empty(),
			"a click on the door at %.1f m walks the hero in (at %s)" % [h, local])


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Tower door"
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var rec: Dictionary = game.level.walk_in.buildings.filter(func(r): return r.kind == MageTower.KIND)[0]
	for h in [0.3, 1.0, 1.8]:
		await _try(rec.node, rec, h)
	print("PASS: village door clicks" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
