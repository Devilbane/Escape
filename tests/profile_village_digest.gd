extends SceneTree
## Loading-speed helper (not a pass/fail test): builds the village (the open map) and prints how long it
## took plus a digest of everything that was built (every mesh, multimesh and transform, in no particular
## order). The digest must not change when the build is made faster: same look, same village.
## Run with: godot --headless -s tests/profile_village_digest.gd [-- dump_file]  (the dump lists every node's line, to diff two runs)

func _initialize() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var t := Time.get_ticks_msec()
	game.load_level(10)
	var ms := Time.get_ticks_msec() - t
	var lines: Array[String] = []
	var count := 0
	for n: Node in game.level.find_children("*", "", true, false):
		var d: String = n.get_class()
		if n is Node3D:
			d += str((n as Node3D).transform)
		if n is MeshInstance3D and n.mesh != null:
			d += _mesh(n.mesh)
		if n is MultiMeshInstance3D and n.multimesh != null:
			d += str(n.multimesh.instance_count) + str(hash(n.multimesh.buffer)) + _mesh(n.multimesh.mesh)
		if n is Label3D:
			d += n.text
		# Plain nodes at the origin are the roaming life, turned and sized by chance each time.
		if d.begins_with("Node3D") and d.ends_with("O: (0.0, 0.0, 0.0)]"):
			continue
		lines.append(d)
		count += 1
	lines.sort()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var f := FileAccess.open(args[0], FileAccess.WRITE)
		for l in lines:
			f.store_line(l)
		f.close()
	var parts := {}
	for l in lines:
		var k: String = l.split("(")[0] if l.length() > 0 else ""
		parts[k] = int(parts.get(k, 0)) + hash(l)
	var keys := parts.keys()
	keys.sort()
	for k in keys:
		print("  DIGEST %-28s %d" % [k, parts[k]])
	print("village nodes: %d  digest: %d" % [count, hash(lines)])
	print("village load: %d ms" % ms)
	game.delete_save(game.save_path())
	quit()


func _mesh(m: Mesh) -> String:
	var s := ""
	if m == null:
		return s
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		for arr in a:
			if arr != null:
				s += str(hash(arr))
	return s
