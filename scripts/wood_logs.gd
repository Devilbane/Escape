class_name WoodLogs
## The felled trunks lying beside the woodcutter, where anybody may cut timber
## for themselves: run into one and the hero chops TIMBER_YIELD pieces of timber
## out of it (two blows, like the rock faces of the quarry, see QuarryRocks),
## which go into the bag to build with. A chopped trunk is a sawn stump in a heap
## of chips until the next morning, then the woodcutter has dragged a new one
## there (kept in Level.taken as log_key plus the day it was chopped). A sign
## with an axe marks the spot from the road. Windfalls spread over the woods
## of the whole map are chopped the same way (see build_windfalls).

## The station kind of a trunk.
const KIND := "holzplatz"
## The item a trunk gives (see Items) and how many pieces one gives.
const TIMBER := "bauholz"
const TIMBER_YIELD := 2
## The trunks lie two tiles west of the woodcutter, between him and the road,
## one per row (relative to his tile). Only a free tile of grass gets one.
const CELLS := [Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1)]
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


## Builds the trunks and their sign for a woodcutter on `home` and adds them to `level`.
static func build(level: Outdoor, home: Vector2i) -> void:
	var first := Vector3.INF
	for offset in CELLS:
		var cell: Vector2i = home + offset
		if level.cell_char(cell) != ".":
			continue
		_add_log(level, cell, BARK, LENGTH, RADIUS, TIMBER_YIELD, 2)
		if first == Vector3.INF:
			first = level.cell_to_world(cell)
	if first == Vector3.INF:
		return
	# A sign with an axe beside the northern trunk, facing the road to the west.
	var board := Effects.shop_sign(Lang.t("Holzplatz"), preload("res://assets/fonts/Cinzel-Bold.woff2"), "axe")
	WeatheredProps.weather_plain(board)
	board.position = first + Vector3(-1.7, 0, -1.5)
	board.rotation.y = -PI * 0.5
	level.add_child(board)
	level._add_solid(board.position, Vector3(0.5, 2.6, 0.5))


## The windfalls: trees the storms threw down out in the woods, spread over the
## whole open map, each lying on bare grass beside a standing tree. They are
## chopped like the woodcutter's trunks. None lies in the village, close to the
## woodcutter's own trunks or on a building plot, and none closer than
## WINDFALL_GAP tiles to another, at most WINDFALLS of them.
static func build_windfalls(level: Outdoor) -> void:
	for cell in windfall_cells(level):
		_add_log(level, cell, MOSSY_BARK, WINDFALL_LENGTH, WINDFALL_RADIUS, WINDFALL_YIELD, WINDFALL_BLOWS)


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
			if level.near_village(c) or Plots.owner_at(c) != "":
				continue
			if (near + chosen).any(func(o: Vector2i): return maxi(absi(o.x - c.x), absi(o.y - c.y)) < WINDFALL_GAP):
				continue
			chosen.append(c)
	return chosen


## Whether a trunk to chop lies on tile `c` (a building plot must keep clear of it).
static func lies_on(level: Level, c: Vector2i) -> bool:
	return level.stations.any(func(s): return s.kind == KIND and s.cell == c)


## One trunk on `cell`: the whole log with its sawn ends, and the stump and
## chips that stay when it has been chopped.
## `radius` is the trunk's, `pieces` the timber it gives and `blows` the swings it takes.
static func _add_log(level: Outdoor, cell: Vector2i, bark_colour: Color, length: float, r := RADIUS, pieces := TIMBER_YIELD, blows := 2) -> void:
	var bark := _paint(bark_colour, 1.0)
	var sapwood := _paint(SAPWOOD, 0.9)
	var heartwood := _paint(HEARTWOOD, 0.9)
	var pos := level.cell_to_world(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var root := Node3D.new()
	root.name = "WoodLog"
	root.position = pos
	root.rotation.y = rng.randf_range(-0.25, 0.25)
	level.add_child(root)
	# The whole trunk, lying east to west, with its two sawn ends.
	var whole := Node3D.new()
	whole.name = "Trunk"
	root.add_child(whole)
	var trunk := MeshInstance3D.new()
	var round_mesh := CylinderMesh.new()
	round_mesh.top_radius = r
	round_mesh.bottom_radius = r * 1.1
	round_mesh.height = length
	round_mesh.radial_segments = 14
	round_mesh.rings = 1
	trunk.mesh = round_mesh
	trunk.material_override = bark
	trunk.position = Vector3(0, r, 0)
	trunk.rotation.z = PI * 0.5
	whole.add_child(trunk)
	for side in [-1.0, 1.0]:
		var radius: float = r * (1.1 if side < 0.0 else 1.0)
		for ring in [[radius * 0.94, sapwood, 0.012], [radius * 0.45, heartwood, 0.02]]:
			var disc := MeshInstance3D.new()
			var disc_mesh := CylinderMesh.new()
			disc_mesh.top_radius = ring[0]
			disc_mesh.bottom_radius = ring[0]
			disc_mesh.height = 0.02
			disc_mesh.radial_segments = 14
			disc_mesh.rings = 1
			disc.mesh = disc_mesh
			disc.material_override = ring[1]
			disc.position = Vector3(-side * (length * 0.5 + ring[2]), r, 0)
			disc.rotation.z = PI * 0.5
			whole.add_child(disc)
	# What stays when it is chopped: a short sawn stump and pale chips.
	var stump := MeshInstance3D.new()
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = r
	stump_mesh.bottom_radius = r * 1.15
	stump_mesh.height = 0.25
	stump_mesh.radial_segments = 14
	stump.mesh = stump_mesh
	stump.material_override = bark
	stump.position = Vector3(0.6, 0.125, 0.4)
	root.add_child(stump)
	var cut := MeshInstance3D.new()
	var cut_mesh := CylinderMesh.new()
	cut_mesh.top_radius = r * 0.94
	cut_mesh.bottom_radius = r * 0.94
	cut_mesh.height = 0.02
	cut_mesh.radial_segments = 14
	cut.mesh = cut_mesh
	cut.material_override = sapwood
	cut.position = Vector3(0.6, 0.26, 0.4)
	root.add_child(cut)
	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.14, 0.025, 0.08)
	for i in 8:
		var chip := MeshInstance3D.new()
		chip.mesh = chip_mesh
		chip.material_override = sapwood
		chip.position = Vector3(rng.randf_range(-1.2, 1.2), 0.0125, rng.randf_range(-0.9, 0.9))
		chip.rotation.y = rng.randf() * TAU
		root.add_child(chip)
	level._add_solid(pos, Vector3(length, 0.6 + r, 1.0 + r))
	level.stations.append({"kind": KIND, "cell": cell, "pos": pos, "used": false, "spent": false, "root": root, "trunk": whole, "yield": pieces, "blows": blows})


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
