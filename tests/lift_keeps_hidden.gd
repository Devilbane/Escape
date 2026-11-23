extends SceneTree
## Lifting a roof off and putting it back (WalkIn._lift) must not show what was hidden on purpose,
## such as the range circle of a guild ballista (it appeared at random as the hero walked by).
## Run with: godot --headless -s tests/lift_keeps_hidden.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var gun := HouseBallista.new()
	var roof := Node3D.new()
	roof.add_child(gun)
	root.add_child(roof)
	await process_frame
	check(gun._ring != null, "the ballista built its range circle")
	for round in 3:
		WalkIn._lift(roof, true)
		WalkIn._lift(roof, false)
		var ring: Node3D = gun._ring
		check(ring != null and not ring.visible, "the range circle stays hidden after the roof is put back (round %d)" % round)
	gun.show_range(true)
	WalkIn._lift(roof, true)
	check(not gun._ring.visible, "a lifted roof hides it")
	WalkIn._lift(roof, false)
	check(gun._ring.visible, "and a shown one comes back shown")
	print("lift_keeps_hidden: ", "OK" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
