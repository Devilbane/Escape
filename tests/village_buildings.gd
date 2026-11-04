extends SceneTree
## Headless test for the village buildings: every house block gets a stone
## house (see VillageHouse) and the temple a chapel from the Modular
## Cathedral Kit. Each building stays inside its block, keeps its door in
## front for the villagers, and its windows glow at night only. All of them
## share the temple's old stone look (see AgedStone): the KayKit buildings
## wear the aged stone, ivy climbs the walls (never over a door), birds live
## in nests up on the roofs, and every door has a way paved like the square.
## Run with: godot --headless --fixed-fps 60 -s tests/village_buildings.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: village buildings")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## The box round everything a building shows, in world space.
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## A material shows a texture: its own, or the old stone's (see AgedStone).
func _textured(mat: Material) -> bool:
	if mat is ShaderMaterial:
		return mat.get_shader_parameter("trim") != null
	return mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null


## The block of tiles (in metres) a building stands on.
func _block_area(lvl: Outdoor, block: Rect2i) -> Rect2:
	var half := Level.TILE * 0.5
	var a := lvl.cell_to_world(block.position)
	return Rect2(Vector2(a.x - half, a.z - half), Vector2(block.size) * Level.TILE)


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(2)
	var lvl: Outdoor = game.level

	var houses: Array[Node3D] = []
	var chapel: Node3D
	for child in lvl.get_children():
		if not child is Node3D or not child.has_meta("block"):
			continue
		if child.has_meta("village_house"):
			houses.append(child)
		elif child.name.begins_with("Chapel"):
			chapel = child

	# The houses.
	var blocks := 0
	var seen := {}
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) == "h" and not seen.has(c):
				blocks += 1
				for dy in 2:
					for dx in 2:
						seen[c + Vector2i(dx, dy)] = true
	check(blocks > 0, "the village has house blocks")
	check(houses.size() == blocks, "every house block gets a half-timbered house (%d of %d)" % [houses.size(), blocks])
	check(lvl.spots.houses.size() == blocks, "every house has a door the villagers walk to")
	var looks := {}
	for house in houses:
		var box := _bounds(house)
		var area := _block_area(lvl, house.get_meta("block"))
		check(area.grow(0.3).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "a house stays inside its block")
		check(box.size.y > 6.0 and box.size.y < 14.0, "a house has two floors and a roof (%.1f m high)" % box.size.y)
		var mesh: Mesh = (house.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		var glass := false
		for i in mesh.get_surface_count():
			if mesh.surface_get_material(i) == lvl._house_glass():
				glass = true
			elif not _textured(mesh.surface_get_material(i)):
				check(false, "every part of a house is textured")
		check(glass, "a house has windows")
		looks["%.2f" % box.size.x + "/%.2f" % box.size.y] = true
	check(looks.size() > 1, "the houses do not all look the same")

	# The chapel.
	check(chapel != null, "the temple is a chapel")
	if chapel:
		check(chapel.get_child_count() >= Outdoor.CHAPEL_PARTS.size() + 2, "the chapel has all its pieces and both gables")
		var box := _bounds(chapel)
		var area := _block_area(lvl, chapel.get_meta("block"))
		check(area.grow(0.3).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "the chapel stays inside its block")
		check(box.size.y > 15.0, "the chapel's spire rises over the village (%.1f m)" % box.size.y)
		var dark := 0
		for mi: MeshInstance3D in chapel.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(i) == null:
					dark += 1
		check(dark == 0, "every piece of the chapel has the kit's textures")
		check(lvl.doors.has("s") and not lvl.astar.is_point_solid(lvl.world_to_cell(lvl.doors["s"])), "the square in front of the chapel door is free")
		var front: Vector3 = lvl.doors["s"] - box.get_center()
		check(front.z > 0.0, "the chapel door looks to the square")

	# Windows: dark by day, warm at night.
	var house_glass := lvl._house_glass()
	var chapel_glass: StandardMaterial3D = lvl._scenes.get("mat_chapel_glass")
	lvl.set_hour(12.0)
	check(is_zero_approx(house_glass.emission_energy_multiplier), "house windows are dark by day")
	check(chapel_glass != null and is_zero_approx(chapel_glass.emission_energy_multiplier), "the chapel's windows are dark by day")
	lvl.set_hour(23.0)
	check(house_glass.emission_energy_multiplier > 1.0, "house windows glow at night")
	check(chapel_glass != null and chapel_glass.emission_energy_multiplier > 1.0, "the chapel's stained glass glows at night")
	lvl.set_hour(12.0)

	# The houses keep the villagers out of their walls.
	for house in houses:
		var mid := lvl.world_to_cell(house.position)
		check(lvl.astar.is_point_solid(mid), "a house is solid")

	_check_aged(lvl)
	_finish()


func _check_aged(lvl: Outdoor) -> void:
	# The KayKit buildings wear the old stone, and their windows still glow.
	var kit := 0
	for child in lvl.get_children():
		if not child is Node3D or not child.has_meta("block"):
			continue
		var letter := lvl.cell_char((child.get_meta("block") as Rect2i).position)
		if letter == "R" or not Outdoor.BLOCK_MODELS.has(letter):
			continue
		for mi: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
			kit += 1
			var mat := mi.material_override as ShaderMaterial
			check(mat != null and mat.shader == AgedStone.SHADER, "%s is built of the old stone" % child.name)
	check(kit > 5, "the smithy, tavern, shop and the rest are there (%d)" % kit)
	lvl.set_hour(23.0)
	var lit := false
	for mat in lvl._window_mats.values():
		if mat is ShaderMaterial and float(mat.get_shader_parameter("glow")) > 1.0:
			lit = true
	check(lit, "the stone buildings' windows glow at night")
	lvl.set_hour(12.0)

	# Ivy: plenty of it, all of it close to a wall and low down, none in
	# front of a door.
	var ivy: MultiMeshInstance3D = lvl.get_node_or_null("Ivy")
	check(ivy != null and ivy.multimesh.instance_count > 1000, "ivy climbs the walls")
	if ivy:
		check(ivy.multimesh.instance_count < 60000, "the ivy and shrubs stay cheap (%d leaves)" % ivy.multimesh.instance_count)
		var near_door := 0
		for i in ivy.multimesh.instance_count:
			var at := ivy.multimesh.get_instance_transform(i).origin
			if at.y > AgedStone.IVY_HEIGHT.y + 0.5 or at.y < 0.0:
				check(false, "a leaf grows from the ground up (%.1f m)" % at.y)
				break
			for e: Dictionary in lvl._entrances:
				var door: Vector3 = e.door
				if Vector2(at.x - door.x, at.z - door.z).length() < 1.0 and at.y < 2.4:
					near_door += 1
		check(near_door == 0, "no ivy grows over a door (%d leaves)" % near_door)

	# Nests up high, two birds to each, sitting in them at night.
	check(lvl.nests.size() >= 4 and lvl.nests.size() <= Outdoor.MAX_NESTS, "there are bird nests on the roofs (%d)" % lvl.nests.size())
	for nest in lvl.nests:
		check(nest.y > AgedStone.NEST_HEIGHT, "a nest sits up high (%.1f m)" % nest.y)
	var birds: VillageBirds = lvl.birds
	check(birds != null and birds.birds.size() == lvl.nests.size() * VillageBirds.PER_NEST, "two birds live in each nest")
	if birds:
		lvl.player = game.player
		game.player.global_position = lvl.nests[0] - Vector3(0, lvl.nests[0].y, 0)
		var flew := false
		for i in 600:
			birds._process(1.0 / 60.0)
			if birds.birds.any(func(b): return b.state == "fly"):
				flew = true
				break
		check(flew, "by day the birds fly out")
		var kinds := {}
		for b: Dictionary in birds.birds:
			kinds[b.kind] = true
		check(kinds.size() >= 4, "the birds come in several colourful kinds (%d)" % kinds.size())
		# They come down to the market square, peck there (dipping for worms
		# and now and then pulling one out) and take off when the hero comes.
		check(not birds.market.is_empty(), "the birds know the market square")
		# (No hero for a while, so nobody scares them off.)
		lvl.player = null
		var on_market := false
		var dipped := false
		var wormed := false
		for i in 60 * 240:
			birds._process(1.0 / 30.0)
			for b: Dictionary in birds.birds:
				if b.state == "peck" and b.market:
					on_market = true
					dipped = dipped or b.dipping > 0.0
					wormed = wormed or b.worm > 0.0
			if on_market and dipped and wormed:
				break
		check(on_market, "birds land on the market square")
		check(dipped, "pecking birds dip their heads")
		check(wormed, "now and then a bird pulls out a worm")
		lvl.player = game.player
		var pecker: Dictionary = {}
		for b: Dictionary in birds.birds:
			if b.state == "peck":
				pecker = b
				break
		if not pecker.is_empty():
			game.player.global_position = lvl.to_global(pecker.at)
			birds._process(1.0 / 30.0)
			check(pecker.state == "fly", "a pecking bird takes off when the hero walks up")
		game.player.global_position = lvl.nests[0] - Vector3(0, lvl.nests[0].y, 0)
		lvl.night = true
		for i in 60 * 30:
			birds._process(1.0 / 20.0)
		check(birds.birds.all(func(b): return b.state == "sit" and b.at == b.home), "at night the birds are home in their nests")
		lvl.night = false

	# A paved way to every door, and the way in front of it is free.
	check(lvl._entrances.size() >= 20, "the doors are known (%d)" % lvl._entrances.size())
	for e: Dictionary in lvl._entrances:
		var at: Vector3 = e.door + (e.out as Vector3) * 1.0
		var px := Vector2i(roundi((at.x / Level.TILE + 0.5) * 4.0 - 0.5), roundi((at.z / Level.TILE + 0.5) * 4.0 - 0.5))
		var m := lvl._ground_img.get_pixelv(px)
		check(m.r > 0.9 and m.g > 0.9, "the way to the door at %s is paved" % at)
	# (Not the smithy's: Gorm's forge stands in front of it, see Outdoor._build_forge.)
	for ch in ["n", "m", "s", "k", "o", "w", "b"]:
		if lvl.doors.has(ch):
			check(not lvl.astar.is_point_solid(lvl.world_to_cell(lvl.doors[ch])), "the way in front of %s is free" % ch)
