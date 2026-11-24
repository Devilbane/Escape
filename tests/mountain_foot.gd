extends SceneTree
## Headless test: the hero can walk right up to the mountain rock (it stops at the rock tiles' edge) and
## the rock mesh does not rise where the feet stand, so nobody sinks into the face (see Mountains).
## Run with: godot --headless -s tests/mountain_foot.gd
var game
var frames := 0
func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	if frames < 5: return false
	game.hero_name = "Probe"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	var lvl: Level = game.level
	var tris := PackedVector3Array()
	for n in lvl.get_children():
		if n is MeshInstance3D and n.name.begins_with("Mountains"):
			tris.append_array(n.mesh.get_faces())
	print("verts ", tris.size())
	# Sample open ground points within 1.2 m of the rock-tile collision boxes: report mesh height.
	var worst := {}
	var bucket := {}
	for i in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var k := Vector2i(floori(a.x/2.0), floori(a.z/2.0))
		if not bucket.has(k): bucket[k] = []
		bucket[k].append(i)
	var hist := {}
	var samples := 0
	for y in lvl.height:
		for x in lvl.width:
			var cc := Vector2i(x, y)
			if Mountains.is_rock(lvl, cc) or lvl.cell_char(cc) == "#": continue
			var near := false
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if lvl.cell_char(cc+d) == "=": near = true
			if not near: continue
			var m := lvl.cell_to_world(cc)
			# One sample a metre over the tile: the hero's feet cover far more than that.
			for sx in range(-2, 3):
				for sz in range(-2, 3):
					var p := m + Vector3(sx, 0, sz)
					if Mountains.near_rock(lvl, p.x, p.z, 0.4) : continue
					samples += 1
					var h := _mesh_h(tris, bucket, p)
					if h > 0.12:
						var key := "%.1f" % snappedf(h, 0.2)
						hist[key] = hist.get(key, 0) + 1
	var bad := 0
	for k in hist:
		bad += int(hist[k])
	print("samples %d, sunken %d %s" % [samples, bad, hist])
	var ok := samples > 300 and bad == 0
	print("PASS: mountain foot" if ok else "FAILED: mountain foot")
	game.delete_save(game.save_path())
	quit(0 if ok else 1)
	return true
func _mesh_h(tris: PackedVector3Array, bucket: Dictionary, p: Vector3) -> float:
	var best := 0.0
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			var k := Vector2i(floori(p.x/2.0)+dx, floori(p.z/2.0)+dz)
			if not bucket.has(k): continue
			for i in bucket[k]:
				var a: Vector3 = tris[i]; var b: Vector3 = tris[i+1]; var c: Vector3 = tris[i+2]
				var v0 := Vector2(b.x-a.x, b.z-a.z); var v1 := Vector2(c.x-a.x, c.z-a.z); var v2 := Vector2(p.x-a.x, p.z-a.z)
				var den := v0.x*v1.y - v1.x*v0.y
				if absf(den) < 1e-6: continue
				var u := (v2.x*v1.y - v1.x*v2.y)/den
				var w := (v0.x*v2.y - v2.x*v0.y)/den
				if u >= 0 and w >= 0 and u+w <= 1:
					best = maxf(best, a.y + u*(b.y-a.y) + w*(c.y-a.y))
	return best
