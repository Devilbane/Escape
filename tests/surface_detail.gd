extends SceneTree
## Headless test: villagers, bandits and skeletons show what they are made
## of, like the hero's gear (see GearLook.dress_body and
## shaders/gear_material.gdshaderinc).
## - Every villager's clothes are drawn with the material shader as an
##   "outfit", keep the colour they were dyed, and carry their rest positions
##   (so the grain stays on the cloth when they move). A person's own body
##   reads no metal into grey (a beard, a glove).
## - A skeleton is "remains" (pale parts are bone), a tinted brute keeps its
##   tint and gets the grain on top, a bandit is an "outfit".
## - Glowing eyes and ghosts keep their own look.
## - Parts that look alike share one material.
## Run with: godot --headless -s tests/surface_detail.gd

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
	if frames == 5:
		game.load_level(game._outdoor_index(), false)
	if frames < 10:
		return false
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: surface detail")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _looked(mesh: MeshInstance3D) -> ShaderMaterial:
	var mat := mesh.material_override as ShaderMaterial
	if mat == null or mat.shader != GearLook.SHADER:
		return null
	return mat


func _has_rest(mesh: MeshInstance3D) -> bool:
	var arrays := mesh.mesh as ArrayMesh
	return arrays != null and arrays.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0 != 0


func _spawn(kind: String) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.gear = [] as Array[String]
	e.level = game.level
	game.level.add_child(e)
	return e


func _part(node: Node, suffix: String) -> MeshInstance3D:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).ends_with(suffix):
			return mesh
	return null


func _test() -> void:
	var villagers: Array = game.level.find_children("*", "Villager", true, false)
	check(villagers.size() > 5, "the village has its people")
	var bodies := 0
	for v: Villager in villagers:
		var body := _part(v, "_Body")
		var mat := _looked(body) if body else null
		check(mat != null and int(mat.get_shader_parameter("stuff")) == GearLook.KINDS.outfit, "%s's clothes show what they are made of" % v.display_name)
		if mat == null:
			continue
		bodies += 1
		check(_has_rest(body), "%s's clothes carry their rest positions" % v.display_name)
		check(not mat.get_shader_parameter("metal_where_grey"), "%s's own body reads no metal into grey" % v.display_name)
		var dyed: Color = v._info.colors[0]
		check(Color(mat.get_shader_parameter("dye")).is_equal_approx(dyed), "%s's clothes keep their dye" % v.display_name)
	check(bodies == villagers.size(), "every villager is dressed (%d of %d)" % [bodies, villagers.size()])

	# The smith's hammer is a weathered prop with its own look; his axe is
	# not a body part, so its grey is metal.
	var smith: Villager = null
	for v: Villager in villagers:
		if v.role == "1":
			smith = v
	if smith:
		var hammer := smith.find_child("SmithHammer", true, false)
		var looked := 0
		if hammer:
			for mesh: MeshInstance3D in hammer.find_children("*", "MeshInstance3D", true, false):
				if _looked(mesh) != null:
					looked += 1
		check(hammer != null and looked == 0, "the smith's hammer keeps its own weathered look")

	# Alike parts share one material.
	# Alike parts share one material: the undyed heads of the people on one model.
	var shared := {}
	var heads := 0
	for v: Villager in villagers:
		var head := _part(v, "_Head")
		if head and _looked(head):
			heads += 1
			shared[_looked(head)] = true
	check(heads > 3 and shared.size() < heads, "alike parts share their material (%d for %d heads)" % [shared.size(), heads])

	var skeleton := _spawn("krieger")
	var bones := _looked(_part(skeleton, "_Body"))
	check(bones != null and int(bones.get_shader_parameter("stuff")) == GearLook.KINDS.remains, "a skeleton is remains: bone, cloth and metal")
	check(bones != null and bones.get_shader_parameter("metal_where_grey"), "a skeleton's grey armour is metal")
	check(_has_rest(_part(skeleton, "_Body")), "the skeleton's bones carry their rest positions")
	var blade := _looked(_part(skeleton, "Skeleton_Blade"))
	check(blade != null, "the skeleton's blade shows its metal")

	var brute := _spawn("koloss")
	var tinted := _looked(_part(brute, "_Body"))
	check(tinted != null and int(tinted.get_shader_parameter("stuff")) == GearLook.KINDS.remains, "a tinted brute gets the grain too")
	check(tinted != null and Color(tinted.get_shader_parameter("tint")).is_equal_approx(Enemy.KINDS.koloss.tint), "the brute keeps its tint")
	var eyes := _part(brute, "_Eyes")
	check(eyes != null and _looked(eyes) == null, "glowing eyes keep their glow")

	var bandit := _spawn("halsabschneider")
	var shirt := _looked(_part(bandit, "_Body"))
	check(shirt != null and int(shirt.get_shader_parameter("stuff")) == GearLook.KINDS.outfit, "a bandit's clothes show what they are made of")

	var ghost := _spawn("banshee")
	var haunted := 0
	for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
		if _looked(mesh) != null:
			haunted += 1
	check(haunted == 0, "a ghost keeps its see-through look")

	for e in [skeleton, brute, bandit, ghost]:
		e.queue_free()
