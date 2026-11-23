extends SceneTree
## The candle stand of the hero's house (see CandleStand): its flames are told from the candles, a click
## puts flames and light out together, and a stand put out stays out in the books.

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	# A candle of 54 triangles round a flame of 12, as in candle_triple.glb: one fan each.
	var verts := PackedVector3Array()
	var index := PackedInt32Array()
	for piece in [[0.0, 54], [1.0, 12]]:
		var base := verts.size()
		verts.append(Vector3(piece[0], 0, 0))
		for i in int(piece[1]) + 1:
			verts.append(Vector3(piece[0] + 0.1, 0.01 * i, 0.05))
		for i in int(piece[1]):
			index.append_array(PackedInt32Array([base, base + 1 + i, base + 2 + i]))
	var lists := CandleStand.classify(verts, index)
	check(lists[0].size() == 54 * 3, "the candle stays (%d)" % lists[0].size())
	check(lists[1].size() == 12 * 3, "the flame is split off (%d)" % lists[1].size())
	# Flames and light go out together.
	var root := Node3D.new()
	var light := OmniLight3D.new()
	root.add_child(light)
	var flames := Node3D.new()
	root.add_child(flames)
	root.set_meta(CandleStand.LIGHT, light)
	root.set_meta(CandleStand.FLAMES, flames)
	CandleStand.set_lit(root, false)
	check(not light.visible and not flames.visible and not CandleStand.is_lit(root), "put out: no light, no flame")
	CandleStand.set_lit(root, true)
	check(light.visible and flames.visible and CandleStand.is_lit(root), "lit again: light and flame")
	# A stand put out stays out in the books; a lit one keeps no mark.
	var store := HouseFurniture.new()
	store.placed.append({"kind": "leuchter", "storey": 0, "x": 1, "y": 1, "rot": 0, CandleStand.OUT: 1})
	store.placed.append({"kind": "leuchter", "storey": 0, "x": 2, "y": 1, "rot": 0})
	store.save("Kerzenheld")
	var back := HouseFurniture.of("Kerzenheld")
	check(back.placed.size() == 2, "both stands come back (%d)" % back.placed.size())
	if back.placed.size() == 2:
		check(back.placed[0].has(CandleStand.OUT) and not back.placed[1].has(CandleStand.OUT), "the one put out is still out")
	check(HouseFurniture.KINDS.leuchter.station == HouseFurniture.CANDLE_STATION, "the candle stand is clicked")
	print("PASS: candle stand" if failures == 0 else "FAILED: candle stand (%d)" % failures)
	quit(1 if failures > 0 else 0)
