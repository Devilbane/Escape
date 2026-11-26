extends SceneTree
## Headless test: a real mouse click on the mage tower's steps or its upper floor (the click ray through them, see
## Game._mouse_to_floor, WalkIn.surface_under_ray) walks the hero there, not to a spot on the ground outside.
## Run with: godot --headless --fixed-fps 60 -s tests/mage_tower_clicks.gd

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


## A real mouse click: the ray from the camera through a point of the steps or of the upper floor, as the game
## turns it into a place to walk to (see Game._mouse_to_floor, WalkIn.surface_under_ray).
func _ray_point(world: Vector3) -> Vector3:
	var cp: Vector3 = game.camera.global_position
	var dr: Vector3 = (world - cp).normalized()
	var hit: Variant = game.level.walk_in.surface_under_ray(cp, dr)
	if hit == null:
		return cp + dr * (-cp.y / dr.y)
	return hit


func _click_at(hall: Node3D, local: Vector3, what: String, want_y: float) -> void:
	var pt := _ray_point(hall.global_transform * local)
	game._click(pt)
	var t: Vector3 = hall.global_transform * local
	var got := false
	for i in 60 * 30:
		await physics_frame
		var d: Vector3 = game.player.global_position - t
		if Vector2(d.x, d.z).length() < 0.8 and absf(d.y) < 0.6:
			got = true
			break
	check(got, "a mouse click on %s walks the hero there (hero at %s)" % [what, hall.global_transform.affine_inverse() * game.player.global_position])


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Mage tower clicks"
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
	var way := lvl.walk_in.door_points(rec)
	game.player.global_position = way[1]
	game.player.reset_physics_interpolation()
	await _physics(30)
	for spot: Array in [["halfway up the first flight", a, 0.5], ["the top step of the first flight", a, 0.9]]:
		game.player.global_position = way[1]
		game.player.reset_physics_interpolation()
		await _physics(10)
		var f: Dictionary = spot[1]
		var z: float = lerpf(float(f.foot), float(f.top), float(spot[2]))
		await _click_at(hall, Vector3((float(f.x0) + float(f.x1)) * 0.5, GuildHall.ramp(f, z), z), spot[0], float(f.high))
	# Upstairs: the boards of the library, and the second flight.
	game.player.global_position = hall.global_transform * Vector3(2.2, lay.up_floor, -2.4)
	game.player.reset_physics_interpolation()
	await _physics(30)
	await _click_at(hall, Vector3(1.5, lay.up_floor, 1.5), "the library floor", float(lay.up_floor))
	var zb: float = lerpf(float(b.foot), float(b.top), 0.5)
	await _click_at(hall, Vector3((float(b.x0) + float(b.x1)) * 0.5, GuildHall.ramp(b, zb), zb), "halfway up the second flight", float(b.high))
	print("PASS: mage tower clicks" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
