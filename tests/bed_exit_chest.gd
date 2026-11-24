extends SceneTree
## Headless test: the hero never climbs out of bed into a chest. A chest is low (1.2 m), so the old ray
## at hip height flew over it and the hero stepped out between the bed and the chest and stuck there.
## BedRise.choose_side now stands a body on the floor of each side and takes the free one.
## Run with: godot --headless --fixed-fps 60 -s tests/bed_exit_chest.gd

var failures := 0
var game: Node
var frames := 0


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
		_run()
	return false


func _run() -> void:
	await _body()
	print("PASS: bed exit chest" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _body() -> void:
	# A bed far from everything else, in the open: both sides are free until a chest stands on one.
	var arena := Node3D.new()
	game.add_child(arena)
	var bed_pos := Vector3(900.0, 0.0, 900.0)
	var rot := 0.0
	var floor_spot := bed_pos + Vector3(0.0, 0.0, 2.2)
	var rid: Array = [game.player.get_rid()]
	await physics_frame
	var open_side := BedRise.choose_side(arena, bed_pos, rot, floor_spot, rid)
	check(open_side == BedRise.side_for(bed_pos, rot, floor_spot), "without a chest the preferred side is kept")
	for blocked: float in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.2, 1.2)
		shape.shape = box
		# A chest is low: lower than the hip, where the old ray flew over it.
		shape.position = BedRise.beside(bed_pos, rot, blocked) + Vector3(0.0, 0.6 - BedRise.HIP_HEIGHT, 0.0)
		body.add_child(shape)
		arena.add_child(body)
		for i in 3:
			await physics_frame
		var side := BedRise.choose_side(arena, bed_pos, rot, floor_spot, rid)
		check(side == -blocked, "the hero steps out on the side %+d, away from the chest on side %+d" % [-blocked, blocked])
		body.queue_free()
		await physics_frame
