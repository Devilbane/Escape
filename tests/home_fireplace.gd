extends SceneTree
## Headless test for the fireplaces of the hero's house (see HomeFireplace): every
## storey but the cellar has one, with flames and a warm light, on a free wall
## tile away from the stairs and the door.
## Run with: godot --headless -s tests/home_fireplace.gd

var failures := 0
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_run()
		print("PASS" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
	return false


func _run() -> void:
	var lv := Level.new()
	lv.load_from_file("res://levels/14_das_wohnhaus.txt")
	root.add_child(lv)
	lv.build()
	check(lv.is_home, "the house is a home")
	var storeys := lv.storey_count()
	check(lv.has_cellar(), "the house has a cellar")
	check(not lv.fireplaces.has(-1), "no fireplace in the cellar")
	for s in range(0, storeys):
		check(lv.fireplaces.has(s), "storey %d has a fireplace" % s)
	for s in lv.fireplaces:
		var fp: Node3D = lv.fireplaces[s]
		var light := fp.get_node_or_null("FireLight") as OmniLight3D
		check(light != null and light.light_energy > 0.0, "storey %d fireplace gives light" % s)
		var cell := lv.world_to_cell(fp.position)
		# The wall tile in front of the fire is open floor, and nothing sits beside it.
		var facing := Vector3(sin(fp.rotation.y), 0, cos(fp.rotation.y))
		var front := lv.world_to_cell(fp.position + facing * 2.0)
		check(lv.cell_char(front) == ".", "storey %d: free floor in front of the fire" % s)
		check(lv.storey_of(front) == s, "storey %d: fireplace is on its own storey" % s)
		var additive := false
		for n in fp.get_children():
			if n is MeshInstance3D and n.material_override is StandardMaterial3D and n.material_override.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
				additive = true
		check(not additive, "storey %d: no additive flames (fog)" % s)
