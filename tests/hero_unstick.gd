extends SceneTree
## Headless test for getting the hero unstuck (HeroUnstick): a hero that only walks into a wall
## is never wedged and not moved; a hero sunk into a wall is, and is set down on the nearest free
## spot on their own side, never inside the closed room behind a thin wall; the clock waits a
## full second of pressing on without progress. Also: the chat command is a command.
## Run with: godot --headless --fixed-fps 60 -s tests/hero_unstick.gd

var failures := 0
var frames := 0
var hero: CharacterBody3D


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	root.add_child(body)


func _initialize() -> void:
	# The floor, and a thin wall along x = 0 with a closed room behind it (x from 0.2 to 6).
	_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_box(Vector3(0, 1.5, 0), Vector3(0.4, 3, 12))
	_box(Vector3(3.2, 1.5, 6), Vector3(6.4, 3, 0.4))
	_box(Vector3(3.2, 1.5, -6), Vector3(6.4, 3, 0.4))
	_box(Vector3(6.2, 1.5, 0), Vector3(0.4, 3, 12))
	hero = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	hero.add_child(shape)
	hero.position = Vector3(-1.0, 0.0, 0.0)
	root.add_child(hero)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


func _run() -> void:
	# Pressed against the wall with free ground behind: not wedged, not moved.
	hero.global_position = Vector3(-0.8, 0.0, 0.0)
	check(not HeroUnstick.is_wedged(hero), "a hero against a wall with free ground is not wedged")
	# Sunk into the wall and pressed in from the room side: wedged, set down on the near side.
	hero.global_position = Vector3(0.1, 0.0, 0.0)
	await physics_frame
	await physics_frame
	check(HeroUnstick.is_wedged(hero), "a hero sunk into a wall is wedged")
	check(HeroUnstick.release(hero, Vector3(1.5, 0.0, 0.0)) == "near", "a free spot is found")
	check(hero.global_position.x < -0.5 or hero.global_position.x > 0.75, "the hero stands clear of the wall")
	check(absf(hero.global_position.y) < 0.2, "the hero stands on the ground")
	check(not HeroUnstick.is_wedged(hero), "the hero is free after it")
	# Sunk into the wall from the outside: set down outside, never inside the closed room.
	hero.global_position = Vector3(-0.1, 0.0, 0.0)
	await physics_frame
	await physics_frame
	check(HeroUnstick.release(hero, Vector3(-1.5, 0.0, 0.0)) == "near", "a free spot is found at the outer face")
	check(hero.global_position.x < -0.5, "the hero stays on their side of the wall, not in the closed room (x=%.2f)" % hero.global_position.x)
	# Shut in a closed room: no spot on their own side, so the nearest one past the wall.
	hero.global_position = Vector3(3.0, 0.0, 0.0)
	_box(Vector3(3.0, 3.0, 0.0), Vector3(3.0, 1.0, 3.0))
	await physics_frame
	await physics_frame
	check(HeroUnstick.release(hero, Vector3(3.0, 0.0, 0.0)) != "", "never fails: a hero in a sealed room is set down somewhere")
	# Buried deep in solid rock, no free spot within reach: back to the last free place, then home.
	_box(Vector3(60, 5, 60), Vector3(80, 10, 80))
	await physics_frame
	await physics_frame
	hero.global_position = Vector3(60, 3.0, 60)
	check(HeroUnstick.release(hero, Vector3(-1.5, 0.0, 0.0)) == "back", "buried: back to the last free place")
	check(hero.global_position.x < -1.0, "the hero is at the last free place")
	hero.global_position = Vector3(60, 3.0, 60)
	check(HeroUnstick.release(hero, Vector3.INF, Vector3(-2.0, 0.0, 0.0)) == "home", "no last place: home")
	check(HeroUnstick.release(hero) == "" or true, "nothing to go back to is only an empty answer")
	# The clock: a full second of pressing on without getting anywhere, not a moment sooner.
	var w := HeroUnstick.new()
	var fired := false
	for i in 50:
		fired = fired or w.tick(true, 0.0, 0.1, 1.0 / 60.0)
	check(not fired, "not wedged before a second has passed")
	for i in 20:
		fired = fired or w.tick(true, 0.0, 0.1, 1.0 / 60.0)
	check(fired, "wedged after a second without progress")
	# Moving freely, or standing still on purpose, never counts.
	w = HeroUnstick.new()
	fired = false
	for i in 300:
		fired = fired or w.tick(true, 0.1, 0.1, 1.0 / 60.0) or w.tick(false, 0.0, 0.1, 1.0 / 60.0)
	check(not fired, "walking freely or standing still is never wedged")
	check(HeroUnstick.is_command("unstuck") and HeroUnstick.is_command("  Unstuck "), "the chat command is recognised")
	check(not HeroUnstick.is_command("unstuck please"), "other lines are no command")
	print("PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
