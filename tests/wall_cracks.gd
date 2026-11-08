extends SceneTree
## Headless test for the cracks in the village wall (see WallCracks, WallBrick):
## - the stage grows with the damage: none when whole, then light, medium and heavy;
## - each stage draws more than the one before, and a hurt brick shows the matching number of
##   crack layers on every stone, a mended one shows none;
## Run with: godot --headless -s tests/wall_cracks.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _visible_layers(brick: WallBrick, i: int) -> int:
	var n := 0
	for c: MeshInstance3D in brick._cracks[i]:
		if c.visible:
			n += 1
	return n


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(WallCracks.stage(1.0) == 0, "a whole brick has no cracks")
	check(WallCracks.stage(0.95) == 0, "a scratch is no crack yet")
	check(WallCracks.stage(0.8) == 1, "light cracks at 80%")
	check(WallCracks.stage(0.5) == 2, "medium cracks at 50%")
	check(WallCracks.stage(0.2) == 3, "heavy cracks at 20%")
	check(WallCracks.stage(0.0) == 3, "a broken brick stays heavily cracked")
	var last := 0
	for s in range(1, WallCracks.STAGES + 1):
		for v in WallCracks.VARIANTS:
			var count := WallCracks.mesh(s, v).surface_get_array_len(0)
			check(count > 0, "stage %d variant %d draws something" % [s, v])
			if v == 0:
				check(count > last, "stage %d draws more than the one before" % s)
				last = count
	var brick := WallBrick.new()
	root.add_child(brick)
	check(brick._cracks.size() == brick._stones.size() and brick._stones.size() > 0, "every stone has cracks")
	for i in brick._stones.size():
		check(_visible_layers(brick, i) == 0, "a whole brick shows no cracks")
	var steps := {800: 1, 500: 2, 200: 3}
	for hp in steps:
		brick.hp = hp
		brick._refresh()
		for i in brick._stones.size():
			check(_visible_layers(brick, i) == steps[hp], "%d HP shows %d crack layers" % [hp, steps[hp]])
	brick.hp = WallBrick.MAX_HP
	brick._refresh()
	for i in brick._stones.size():
		check(_visible_layers(brick, i) == 0, "a mended brick shows no cracks")
	if failures == 0:
		print("PASS: wall cracks")
	quit(1 if failures > 0 else 0)
