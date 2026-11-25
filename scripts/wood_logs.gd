class_name WoodLogs
## The felled trunks lying beside the woodcutter, where anybody may cut timber
## for themselves: run into one and the hero chops TIMBER_YIELD pieces of timber
## out of it (two blows, like the rock faces of the quarry, see QuarryRocks),
## which go into the bag to build with. A chopped trunk is a sawn stump in a heap
## of chips until the next morning, then the woodcutter has dragged a new one
## there (kept in Level.taken as log_key plus the day it was chopped). A sign
## with an axe stands beside the trunk the woodcutter works on (see Outdoor._build_chopping_log). Windfalls spread over the woods
## of the whole map are chopped the same way (see build_windfalls).

## The station kind of a trunk.
const KIND := "holzplatz"
## The item a trunk gives (see Items) and how many pieces one gives.
const TIMBER := "bauholz"
const TIMBER_YIELD := 2
## The trunks lie scattered round the woodcutter's yard (relative to his
## tile), a tile or two apart instead of in one tidy row: two to the west
## between him and the road, one off to the south east by his barrels. Only a
## free tile of grass gets one.
const CELLS := [Vector2i(-2, -2), Vector2i(-2, 1), Vector2i(1, 2)]
## How far a yard trunk may lie turned from east to west (radians), and how
## far off the middle of its tile (metres): dragged there, not laid out.
const TURN := 0.6
const SHIFT := 0.4
## A trunk's length and radius (metres).
const LENGTH := 2.6
const RADIUS := 0.3
const BARK := Color(0.4, 0.27, 0.17)
const SAPWOOD := Color(0.86, 0.7, 0.48)
const HEARTWOOD := Color(0.68, 0.48, 0.28)
## The windfalls out in the woods (see build_windfalls): longer, with older,
## mossier bark, at most WINDFALLS of them, at least WINDFALL_GAP tiles apart.
const MOSSY_BARK := Color(0.33, 0.3, 0.19)
## A windfall is a whole tree: thicker, it takes WINDFALL_BLOWS swings and gives
## WINDFALL_YIELD pieces.
const WINDFALL_LENGTH := 3.6
const WINDFALL_RADIUS := 0.45
const WINDFALL_YIELD := 6
const WINDFALL_BLOWS := 4
const WINDFALLS := 16
const WINDFALL_GAP := 7


## Builds the yard trunks for a woodcutter on `home` and adds them to `level`.
static func build(level: Outdoor, home: Vector2i) -> void:
	for offset in CELLS:
		var cell: Vector2i = home + offset
		if level.cell_char(cell) != ".":
			continue
		_add_log(level, cell, BARK, LENGTH, RADIUS, TIMBER_YIELD, 2, 0.15, TURN, SHIFT)


## The windfalls: trees the storms threw down out in the woods, spread over the
## whole open map, each lying on bare grass beside a standing tree. They are
## chopped like the woodcutter's trunks. None lies in the village, close to the
## woodcutter's own trunks or on a building plot, and none closer than
## WINDFALL_GAP tiles to another, at most WINDFALLS of them.
static func build_windfalls(level: Outdoor) -> void:
	for cell in windfall_cells(level):
		_add_log(level, cell, MOSSY_BARK, WINDFALL_LENGTH, WINDFALL_RADIUS, WINDFALL_YIELD, WINDFALL_BLOWS, 0.75, 0.25, 0.0)


## The tiles the windfalls lie on (see build_windfalls), the same for every game.
static func windfall_cells(level: Outdoor) -> Array:
	var near: Array = level.stations.filter(func(s): return s.kind == KIND).map(func(s): return s.cell)
	var chosen: Array = []
	for y in level.height:
		for x in level.width:
			var c := Vector2i(x, y)
			if chosen.size() >= WINDFALLS:
				return chosen
			if level.cell_char(c) != ".":
				continue
			if not [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d): return level.cell_char(c + d) == "T"):
				continue
			if level.near_village(c) or Plots.owner_at(c) != "" or _in_open_grass(level, c):
				continue
			if (near + chosen).any(func(o: Vector2i): return maxi(absi(o.x - c.x), absi(o.y - c.y)) < WINDFALL_GAP):
				continue
			chosen.append(c)
	return chosen


## Whether tile `c` belongs to an open stretch of grass (a 3 x 3 block of bare
## grass holds it), where someone may want to build: windfalls lie in the
## thicket between trees instead, so building land stays free.
static func _in_open_grass(level: Level, c: Vector2i) -> bool:
	for oy in range(-2, 1):
		for ox in range(-2, 1):
			var open := true
			for y in 3:
				for x in 3:
					if level.cell_char(c + Vector2i(ox + x, oy + y)) != ".":
						open = false
			if open:
				return true
	return false


## Whether a trunk to chop lies on tile `c` (a building plot must keep clear of it).
static func lies_on(level: Level, c: Vector2i) -> bool:
	return level.stations.any(func(s): return s.kind == KIND and s.cell == c)


## One trunk on `cell`: the whole log with its sawn ends, and the stump and
## chips that stay when it has been chopped.
## `radius` is the trunk's, `pieces` the timber it gives and `blows` the swings it takes.
## Each trunk is grown from its tile (see trunk_mesh): no two are alike, and
## each lies at its own angle, up to `turn` from east to west and up to
## `shift` metres off the middle of its tile. `moss` is how mossy its upper side is.
static func _add_log(level: Outdoor, cell: Vector2i, bark_colour: Color, length: float, r := RADIUS, pieces := TIMBER_YIELD, blows := 2, moss := 0.15, turn := 0.25, shift := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var grain_seed := rng.randf_range(0.0, 50.0)
	var bark := log_material(bark_colour, r, moss, grain_seed, false)
	var ends := log_material(bark_colour, r, moss, grain_seed, true)
	var pos := level.cell_to_world(cell) + Vector3(rng.randf_range(-shift, shift), 0, rng.randf_range(-shift, shift))
	var root := Node3D.new()
	root.name = "WoodLog"
	root.position = pos
	root.rotation.y = rng.randf_range(-turn, turn)
	level.add_child(root)
	# The whole trunk, lying east to west, with its two sawn ends.
	var whole := Node3D.new()
	whole.name = "Trunk"
	root.add_child(whole)
	var trunk := MeshInstance3D.new()
	trunk.name = "Bark"
	trunk.mesh = trunk_mesh(length, r, rng)
	trunk.mesh.surface_set_material(0, bark)
	trunk.mesh.surface_set_material(1, ends)
	whole.add_child(trunk)
	# A broken-off branch or two sticking out of the bark.
	for i in rng.randi_range(1, 2):
		var stub := MeshInstance3D.new()
		var stub_mesh := CylinderMesh.new()
		stub_mesh.bottom_radius = r * rng.randf_range(0.18, 0.28)
		stub_mesh.top_radius = stub_mesh.bottom_radius * 0.55
		stub_mesh.height = r * rng.randf_range(0.7, 1.3)
		stub_mesh.radial_segments = 7
		stub_mesh.rings = 1
		stub.mesh = stub_mesh
		stub.material_override = bark
		var along := rng.randf_range(-0.3, 0.3) * length
		var round_at := rng.randf_range(-1.2, 1.2) + (PI if i == 1 else 0.0)
		var out := Vector3(0, cos(round_at), sin(round_at))
		if out.y < -0.2:
			out = Vector3(0, -out.y, out.z)
		var tilt := Basis(Vector3.UP.cross(out).normalized(), Vector3.UP.angle_to(out)) if out.cross(Vector3.UP).length() > 0.01 else Basis()
		stub.basis = tilt.rotated(out, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
		stub.position = Vector3(along, r, 0) + out * (r * 0.85 + stub_mesh.height * 0.5)
		whole.add_child(stub)
	# What stays when it is chopped: a short sawn stump standing on its end.
	var stump := MeshInstance3D.new()
	stump.name = "Stump"
	stump.mesh = trunk_mesh(0.28, r * 1.05, rng, 1)
	stump.mesh.surface_set_material(0, bark)
	stump.mesh.surface_set_material(1, ends)
	stump.rotation.z = PI * 0.5
	stump.position = Vector3(0.6 + r * 1.05, 0.14, 0.4)
	root.add_child(stump)
	var sapwood := _paint(SAPWOOD, 0.9)
	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.14, 0.025, 0.08)
	for i in 8:
		var chip := MeshInstance3D.new()
		chip.mesh = chip_mesh
		chip.material_override = sapwood
		chip.position = Vector3(rng.randf_range(-1.2, 1.2), 0.0125, rng.randf_range(-0.9, 0.9))
		chip.rotation.y = rng.randf() * TAU
		root.add_child(chip)
	# The trunk blocks the way where it lies, turned with it.
	var block := level._add_box(level._walls_body, pos + Vector3(0, (0.6 + r) * 0.5, 0), Vector3(length, 0.6 + r, 1.0 + r))
	block.rotation.y = root.rotation.y
	level.stations.append({"kind": KIND, "cell": cell, "pos": pos, "used": false, "spent": false, "root": root, "trunk": whole, "yield": pieces, "blows": blows})


## A felled trunk `length` long along its own x axis, lying on the ground
## (y = 0) with its middle over the origin: not a round pipe but a little
## lumpy round, thicker towards the root end (west, -x) where it flares out,
## with a slight bow along its length. Surface 0 is the bark (UV.x along the
## trunk in metres, UV.y round it), surface 1 the two sawn ends (UV from -1
## to 1 across, so the rings in felled_log.gdshader follow the outline).
## `flat` 1 keeps the trunk straight and even (a stump).
static func trunk_mesh(length: float, r: float, rng: RandomNumberGenerator, flat := 0) -> ArrayMesh:
	var around := 20
	var steps := 1 if flat == 1 else 10
	# The outline: a few slow bulges round the trunk, each with its own phase.
	var lumps := []
	for k in [2, 3, 5]:
		lumps.append([k, rng.randf_range(0.015, 0.05) * (2.0 / k + 0.4), rng.randf() * TAU])
	var flare_phase := rng.randf() * TAU
	var bow := Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(0.0, 0.05)) * (0.0 if flat == 1 else 1.0)
	var rings := []
	for i in steps + 1:
		var t := float(i) / steps
		var x := (t - 0.5) * length
		# Thicker at the root end, flaring out in buttresses at the very end.
		var size := r * (1.12 - 0.2 * t)
		var flare := 0.0 if flat == 1 else maxf(0.0, 0.18 - t) / 0.18
		var bend := 1.0 - 4.0 * (t - 0.5) * (t - 0.5)
		var centre := Vector3(x, 0, bow.x * bend)
		var ring := []
		for j in around + 1:
			var a := TAU * j / around
			var k := 1.0
			for l in lumps:
				k += l[1] * sin(l[0] * a + l[2] + t * 1.3)
			k += flare * (0.07 + 0.035 * sin(5.0 * a + flare_phase))
			ring.append([centre + Vector3(0, cos(a), sin(a)) * size * k, a])
		rings.append([ring, size])
	# Sit it on the ground: its lowest point at y = 0, its bow lifting the middle.
	var lowest := INF
	for i in rings.size():
		var t := float(i) / steps
		for v in rings[i][0]:
			lowest = minf(lowest, v[0].y - bow.y * (1.0 - 4.0 * (t - 0.5) * (t - 0.5)))
	var lift := -lowest
	for i in rings.size():
		var t := float(i) / steps
		var up := lift + bow.y * (1.0 - 4.0 * (t - 0.5) * (t - 0.5))
		for v in rings[i][0]:
			v[0].y += up
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		for j in around:
			# Clockwise seen from outside, which is what Godot draws (the other way round it is culled).
			var quad := [[i, j], [i + 1, j + 1], [i, j + 1], [i, j], [i + 1, j], [i + 1, j + 1]]
			for q in quad:
				var v: Array = rings[q[0]][0][q[1]]
				st.set_uv(Vector2(v[0].x, float(q[1]) / around))
				st.add_vertex(v[0])
	st.generate_normals()
	var mesh := st.commit()
	# The sawn ends, each a fan round its middle, cut square across.
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for end in [0, steps]:
		var ring: Array = rings[end][0]
		var middle := Vector3.ZERO
		for j in around:
			middle += ring[j][0]
		middle /= around
		var side := -1.0 if end == 0 else 1.0
		cap.set_normal(Vector3(side, 0, 0))
		for j in around:
			var tri := [ring[j + 1], ring[j]] if end != 0 else [ring[j], ring[j + 1]]
			cap.set_uv(Vector2.ZERO)
			cap.add_vertex(middle)
			for v in tri:
				cap.set_uv(Vector2(cos(v[1]), sin(v[1])))
				cap.add_vertex(v[0])
	cap.commit(mesh)
	return mesh


## The bark or the sawn ends of one trunk (see felled_log.gdshader).
static func log_material(bark_colour: Color, r: float, moss: float, grain_seed: float, end_grain: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/felled_log.gdshader")
	mat.set_shader_parameter("bark_colour", bark_colour)
	mat.set_shader_parameter("sapwood", SAPWOOD)
	mat.set_shader_parameter("heartwood", HEARTWOOD)
	mat.set_shader_parameter("end_grain", end_grain)
	mat.set_shader_parameter("moss", moss)
	mat.set_shader_parameter("radius", r)
	mat.set_shader_parameter("rings", round(r * 60.0))
	mat.set_shader_parameter("seed", grain_seed)
	return mat


static func _paint(colour: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = roughness
	return mat


## The key in Level.taken for the trunk at cell `c` chopped on `day`.
static func log_key(c: Vector2i, day: int) -> String:
	return "woodlog:%d:%d@%d" % [c.x, c.y, day]


## The day the trunk at `c` was last chopped, from Level.taken, or -1.
static func chopped_on(taken: Dictionary, c: Vector2i) -> int:
	var prefix := "woodlog:%d:%d@" % [c.x, c.y]
	for key in taken:
		if str(key).begins_with(prefix):
			return int(str(key).substr(prefix.length()))
	return -1


## Shows a trunk whole or chopped down to its stump.
static func set_log(station: Dictionary, spent: bool, animate := false) -> void:
	station.spent = spent
	var trunk: Node3D = station.trunk
	var size := Vector3(1.0, 0.01, 0.01) if spent else Vector3.ONE
	if not animate or not trunk.is_inside_tree():
		trunk.scale = size
		trunk.visible = not spent
		return
	trunk.visible = true
	var tween := trunk.create_tween()
	tween.tween_property(trunk, "scale", size, 0.4 if spent else 1.6)
	if spent:
		tween.tween_callback(trunk.hide)


## The trunks of `level` as the hero left them: one chopped before `day` has
## been replaced (its mark is gone), one chopped today is still a stump.
## `animate`: the new trunk appears before the hero's eyes (a new morning).
static func refresh(level: Level, day: int, animate := false) -> void:
	for st in level.stations:
		if st.kind != KIND:
			continue
		var chopped := chopped_on(level.taken, st.cell)
		if chopped >= 0 and chopped < day:
			level.taken.erase(log_key(st.cell, chopped))
			chopped = -1
		var spent := chopped >= 0
		if spent != st.spent or not animate:
			set_log(st, spent, animate)


## Marks a trunk as chopped on `day` and shows its stump, with a burst of
## chips. Returns false when it was chopped already.
static func mark_chopped(level: Level, station: Dictionary, day: int) -> bool:
	if station.spent:
		return false
	level.taken[log_key(station.cell, day)] = true
	set_log(station, true, true)
	var chips := Effects.make_wood_chips()
	chips.position = station.pos + Vector3(0, 0.6, 0)
	level.add_child(chips)
	chips.restart()
	return true
