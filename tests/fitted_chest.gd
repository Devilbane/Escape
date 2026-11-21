extends SceneTree
## Headless test for the chests with metal fittings (see FittedChest): every style builds a body and
## a lid hinged at the back, is the size of the kit chest it replaced, opens its lid upwards (with
## the fittings on the lid swinging along) and shows gold only when it is a loot chest. Loot chests
## take the style that fits their worth, and the shipped maps build their chests from it.
## Run with: godot --headless -s tests/fitted_chest.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_check_styles()
	_check_loot_styles()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check_styles() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for style: String in FittedChest.STYLES:
		for gold: bool in [false, true]:
			var what := "%s chest%s" % [style, " with gold" if gold else ""]
			var chest := FittedChest.place(holder, style, Vector3(3, 0, 1), 0.5, gold)
			check(chest.get_parent() == holder and chest.position == Vector3(3, 0, 1), what + " stands where it is put")
			var lid := FittedChest.lid_of(chest)
			check(lid != null, what + " has a lid")
			if lid == null:
				continue
			var foot := Level.footprint(chest, chest)
			check(absf(foot.size.x - FittedChest.WIDTH) < 0.2 and absf(foot.size.z - FittedChest.DEPTH) < 0.25,
					what + " is as big as the kit chest (%s)" % foot.size)
			check(foot.end.y > 1.0 and foot.end.y < 1.45, what + " is about as high as the kit chest (%.2f)" % foot.end.y)
			check(absf(foot.position.y) < 0.01, what + " stands on the floor")
			# Wood and metal on body and lid, gold only in a loot chest.
			var body := chest.get_node(FittedChest.BODY) as MeshInstance3D
			check(body.mesh.get_surface_count() == (4 if gold else 2), what + ": body has wood, metal%s" % (", gold and jewels" if gold else ""))
			check((lid as MeshInstance3D).mesh.get_surface_count() == 2, what + ": lid has wood and metal")
			check(chest.has_meta("glints") == gold, what + ": glints only over gold")
			if gold:
				check(not (chest.get_meta("glints") as CPUParticles3D).emitting, what + ": the gold does not blink while shut")
			# The lid's front edge rises when it turns as Level.search turns it.
			var front := Vector3(0, FittedChest.RIM, FittedChest.DEPTH)
			var shut_y := (lid.transform * front).y
			lid.rotation.x -= Level.LID_OPEN
			var open_y := (lid.transform * front).y
			check(open_y > shut_y + 0.8, what + ": the lid swings up and back (%.2f to %.2f)" % [shut_y, open_y])
			check(absf(lid.position.z + FittedChest.DEPTH * 0.5) < 0.01, what + ": the lid is hinged at the back")
			# Shut, the lid covers the body: the gold inside stays below the lid's top.
			lid.rotation.x = 0.0
			if gold:
				var lid_top := (lid.transform * (lid as MeshInstance3D).get_aabb()).end.y
				check(body.get_aabb().end.y < lid_top - 0.05, what + ": the heap of gold fits under the shut lid")
			chest.free()
	# The meshes are built once per style and shared.
	var a := FittedChest.place(holder, "oak", Vector3.ZERO)
	var b := FittedChest.place(holder, "oak", Vector3.ONE)
	check((a.get_node(FittedChest.BODY) as MeshInstance3D).mesh == (b.get_node(FittedChest.BODY) as MeshInstance3D).mesh,
			"chests of one style share their meshes")
	holder.free()


func _check_loot_styles() -> void:
	var lv := Level.new()
	lv.grid = ["#####", "#P.C#", "#####"]
	lv.height = 3
	lv.width = 5
	root.add_child(lv)
	check(lv.chest_style(Vector2i(3, 1)) == "oak", "an everyday loot chest is iron-banded oak")
	check(lv.chest_style(Vector2i(3, 1), true) == "brass", "an epic chest is ornate brass")
	lv.free()
	# A dungeon map with a chest builds it from the fitted chests, its lid and its glints wired up.
	var dir := DirAccess.open("res://levels")
	var built := 0
	for file in dir.get_files():
		if not file.ends_with(".txt") or Level.is_outdoor_file("res://levels/" + file):
			continue
		var text := FileAccess.get_file_as_string("res://levels/" + file)
		if not text.contains("C"):
			continue
		var lvl := Level.new()
		root.add_child(lvl)
		lvl.load_from_file("res://levels/" + file)
		lvl.build()
		for obj: Dictionary in lvl.interactables:
			if obj.get("label", "") != "Schatztruhe":
				continue
			built += 1
			check(obj.lid != null and obj.lid.name == FittedChest.LID, "%s: a treasure chest has a fitted lid" % file)
			check(obj.get("shine") is CPUParticles3D, "%s: a treasure chest has its glints" % file)
		lvl.free()
		if built > 0:
			break
	check(built > 0, "a shipped dungeon map has a treasure chest")
