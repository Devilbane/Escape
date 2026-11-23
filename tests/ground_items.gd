extends SceneTree
## Headless test for items lying on the floor (see GroundItem): every item the hero can carry has a model that
## rests flat on the ground at a believable size, a stackable kind makes a pile that grows with the count, and
## a dropped item is a real model on the floor, not a floating glowing bubble.
## Run with: godot --headless -s tests/ground_items.gd

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
	if frames < 5:
		return false
	_models()
	_piles()
	_drop()
	game.delete_save(game.save_path())
	print("PASS: ground items" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for c in node.get_children():
		n += _meshes(c)
	return n


func _models() -> void:
	for id in Items.ALL:
		var node := GroundItem.build(str(id))
		check(_meshes(node) > 0, "%s has a model on the floor" % id)
		var box := GroundItem._bounds(node)
		check(absf(box.position.y) < 0.02, "%s rests on the ground (underside at %.3f)" % [id, box.position.y])
		var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
		check(longest > 0.05 and longest < 1.4, "%s is a believable size (%.2f)" % [id, longest])
		check(box.size.y < 0.75, "%s lies, it does not stand tall (%.2f)" % [id, box.size.y])
		node.free()
	# Something unknown still lies there as a pouch.
	var odd := GroundItem.build("not_an_item")
	check(_meshes(odd) > 0, "an unknown thing becomes a pouch")
	odd.free()


func _piles() -> void:
	var seen := {}
	for i in 12:
		var spot := GroundItem.slot(i, Vector3(0.1, 0.1, 0.3))
		seen[Vector3(snappedf(spot.offset.x, 0.01), snappedf(spot.offset.y, 0.01), snappedf(spot.offset.z, 0.01))] = true
	check(seen.size() == 12, "twelve of a kind lie at twelve different spots (%d)" % seen.size())
	check(GroundItem.slot(11, Vector3(0.1, 0.1, 0.3)).offset.y > 0.0, "a big pile grows upwards")
	check(GroundItem.stacks("fackel") and GroundItem.stacks("kupferring") and GroundItem.stacks("apfel"), "torches, rings and food pile up")
	check(not GroundItem.stacks("schwert"), "a sword does not pile up")


func _drop() -> void:
	game.hero_name = "Ground test"
	game.escaped = false
	for i in game.level_files.size():
		if "zuflucht" in game.level_files[i]:
			game.load_level(i, false)
			break
	var spot: Vector3 = game.player.global_position + Vector3(3, 0, 0)
	for i in 5:
		game.level._drop_item("fackel", spot)
	var drops: Array = game.level._pickups.filter(func(p): return p.kind == "item" and p.get("id", "") == "fackel")
	check(drops.size() == 5, "five torches lie there")
	for p in drops:
		var node: Node3D = p.node
		check(is_zero_approx(node.position.y), "a dropped torch rests on the floor")
		check(node.find_children("*", "OmniLight3D", true, false).is_empty(), "no lamp glows on a dropped item")
		check(node.find_children("*", "CPUParticles3D", true, false).is_empty(), "no sparkles float over a dropped item")
	var heights := drops.map(func(p): return GroundItem._bounds(p.node).end.y)
	check(heights.max() > heights.min() + 0.01, "the torches are piled, not all in one place")
