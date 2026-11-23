extends SceneTree
## Headless test for the chimneys of the village houses: each ends in a timber rim round an open,
## soot-dark flue, the snow lies on the rim only (never in the opening), and the smoke's spot lies
## over the opening. No bird nests by a chimney.
## Run with: godot --headless -s tests/chimney_flue.gd

var failures := 0
var done := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	for s in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		_house(VillageHouse.build(Vector2(9, 8), rng, StandardMaterial3D.new()), "house %d" % s)
		_house(VillageHouse.build_narrow(Vector2(4.5, 8), s + 1, rng, StandardMaterial3D.new()), "narrow house %d" % s)
	print("PASS: chimney flue" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _house(house: Node3D, label: String) -> void:
	root.add_child(house)
	var tris := AgedStone.triangles(house)
	var flue := tris.filter(func(t: Dictionary) -> bool: return t.has("flue"))
	check(not flue.is_empty(), label + ": the flue has an inside")
	var tops := SnowCaps._open_tops(tris, house.global_position.y, SnowCaps.LOWEST)
	var top_y := -1e9
	for t: Dictionary in tris:
		if not t.has("flue") and (t.n as Vector3).y > 0.9:
			top_y = maxf(top_y, (t.a as Vector3).y)
	var rim_snow := false
	for t: Dictionary in tops:
		check(not t.has("flue"), label + ": no snow in the flue")
		if (t.a as Vector3).y > top_y - 0.01:
			rim_snow = true
	check(rim_snow, label + ": snow lies on the rim")
	if not flue.is_empty():
		var inner := (flue[0].a as Vector3).y
		check(inner < top_y - 0.03, label + ": the opening lies below the rim's top")
	# No nest by the chimney, where the birds would be smoked: on the ridge instead.
	if house.has_meta("chimney"):
		var mouth: Vector3 = house.global_transform * (house.get_meta("chimney") as Vector3)
		var nest := AgedStone.nest_spot(tris, house.global_position.y, [mouth])
		check(nest != Vector3.INF, label + ": a nest finds a spot")
		check(Vector2(nest.x - mouth.x, nest.z - mouth.z).length() >= AgedStone.NEST_SMOKE_CLEAR, label + ": the nest keeps clear of the chimney")
	house.queue_free()
