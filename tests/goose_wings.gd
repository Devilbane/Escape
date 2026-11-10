extends SceneTree
## Headless test: a goose's wings join its body. Each wing's shoulder lies inside the body
## ellipsoid, and the folded wing's inner edge stays inside it too.
## Run with: godot --headless -s tests/goose_wings.gd

func _initialize() -> void:
	var failures := 0
	var radii := Vector3(0.18, 0.17, 0.31)
	var centre := Vector3(0, 0.36, 0)
	var shoulder: Vector3 = FarmAnimal.WING_SHOULDER
	var inside := ((shoulder - centre) / radii).length()
	if inside >= 1.0:
		failures += 1
		print("FAIL: the wing shoulder floats outside the body (%.2f)" % inside)
	# Wing ball: centre offset 0.04 from the shoulder, half-width 0.05.
	var inner := Vector3(shoulder.x + 0.04 - 0.05, shoulder.y - 0.06, shoulder.z - 0.04)
	if ((inner - centre) / radii).length() >= 1.0:
		failures += 1
		print("FAIL: the folded wing does not touch the body")
	print("PASS" if failures == 0 else "FAILED")
	quit(failures)
