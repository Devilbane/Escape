class_name CosyBed
extends RefCounted
## The hero's own bed at home (the town house, the house in the open-air map and a self-built house;
## inns and dungeons keep the plain worn cot, bed_decorated). It is made like the bookshelf
## (see Bookshelf): dark walnut with lathe-turned posts and finials, a headboard and a footboard
## with turned spindles, a thick mattress under a patchwork quilt with the sheet folded over it,
## two plump pillows, a fur throw over the foot and a little bedside table with turned legs, a
## candle and a book.
##
## It stands exactly where the cot stood: the same footprint (so the same solid, see
## Level._add_fitted_solid), the pillows round Level.PILLOW (the spot a click uses) and the top of
## the mattress at Game.BED_MATTRESS_HEIGHT, where the hero lies.

## The node name of the bed.
const NODE := "CosyBed"
## The wool's knit, as colour and as bumps (see wool).
static var _knit: NoiseTexture2D
static var _knit_bumps: NoiseTexture2D
## The cot's footprint from its origin (metres): the bed from LEFT to RIGHT across, from HEAD (by
## the wall) to FOOT along, and the bedside table out to TABLE_EDGE beside its head.
const LEFT := -0.75
const RIGHT := 0.6
const HEAD := -1.56
const FOOT := 1.5
const TABLE_EDGE := 1.86
## How high the side rails and the mattress reach.
const RAIL_TOP := 0.48
const MATTRESS_TOP := 0.84
## The quilt's patches, warm and faded.
const PATCHES := [Color(0.62, 0.2, 0.16), Color(0.82, 0.62, 0.32), Color(0.32, 0.42, 0.28), Color(0.72, 0.42, 0.24),
		Color(0.5, 0.18, 0.2), Color(0.86, 0.78, 0.6)]
const LINEN := Color(0.9, 0.86, 0.76)
const FUR := Color(0.3, 0.22, 0.16)
const FUR_TIPS := Color(0.44, 0.34, 0.25)
const WAX := Color(0.95, 0.92, 0.82)
const FLAME := Color(1.0, 0.75, 0.35)
## The head posts: a bun foot, a vase, rings at the rail and the headboard, a finial on top.
const HEAD_POST := [Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.09, 0.05), Vector2(0.075, 0.12),
		Vector2(0.06, 0.16), Vector2(0.06, 0.5), Vector2(0.08, 0.53), Vector2(0.08, 0.58), Vector2(0.05, 0.62),
		Vector2(0.065, 0.8), Vector2(0.07, 1.0), Vector2(0.045, 1.2), Vector2(0.075, 1.24), Vector2(0.075, 1.3),
		Vector2(0.045, 1.34), Vector2(0.04, 1.48), Vector2(0.065, 1.53), Vector2(0.072, 1.59), Vector2(0.05, 1.65),
		Vector2(0.025, 1.7), Vector2(0.0, 1.76)]
## The foot posts: the same turning, cut short, with a ball on top.
const FOOT_POST := [Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.09, 0.05), Vector2(0.075, 0.12),
		Vector2(0.06, 0.16), Vector2(0.06, 0.5), Vector2(0.08, 0.53), Vector2(0.08, 0.58), Vector2(0.05, 0.62),
		Vector2(0.065, 0.78), Vector2(0.045, 0.94), Vector2(0.075, 0.98), Vector2(0.075, 1.03), Vector2(0.04, 1.06),
		Vector2(0.07, 1.1), Vector2(0.075, 1.15), Vector2(0.055, 1.2), Vector2(0.0, 1.22)]
## A spindle between two rails, one metre long (scaled to fit).
const SPINDLE := [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.08), Vector2(0.018, 0.14),
		Vector2(0.032, 0.42), Vector2(0.022, 0.6), Vector2(0.035, 0.66), Vector2(0.02, 0.72), Vector2(0.018, 0.86),
		Vector2(0.03, 0.92), Vector2(0.03, 1.0), Vector2(0.0, 1.0)]
## A leg of the bedside table.
const TABLE_LEG := [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.05, 0.05), Vector2(0.035, 0.1),
		Vector2(0.03, 0.3), Vector2(0.045, 0.42), Vector2(0.03, 0.52), Vector2(0.045, 0.56), Vector2(0.045, 0.68),
		Vector2(0.0, 0.68)]


## The bed at `pos`, turned by `rot` (its foot towards +z), under `parent`. No solid and no station:
## the caller adds them as it did for the cot.
## Without `table` the bed stands alone (the villagers' beds side by side, see WalkIn).
static func build(parent: Node, pos: Vector3, rot: float, table := true) -> Node3D:
	var root := Node3D.new()
	root.name = NODE
	root.position = pos
	root.rotation.y = rot
	parent.add_child(root)
	var wood := HomeStoreFurniture._mat(Bookshelf.OAK, 0.75)
	var turned := HomeStoreFurniture._mat(Bookshelf.TURNED_OAK, 0.55)
	var dark := HomeStoreFurniture._mat(Bookshelf.DARK_OAK, 0.85)
	var cx := (LEFT + RIGHT) * 0.5
	var width := RIGHT - LEFT
	var post := 0.085
	var xs := [LEFT + post, RIGHT - post]
	var head_z := HEAD + post
	var foot_z := FOOT - post
	# Four turned posts, tall at the head, short at the foot.
	var head_post := Bookshelf._lathe(HEAD_POST)
	var foot_post := Bookshelf._lathe(FOOT_POST)
	for x: float in xs:
		HomeStoreFurniture._add(root, head_post, turned, Vector3(x, 0, head_z))
		HomeStoreFurniture._add(root, foot_post, turned, Vector3(x, 0, foot_z))
	# The side rails and the end rails under the mattress.
	var inner := width - post * 2.0
	for x: float in xs:
		HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(0.07, 0.18, foot_z - head_z)), wood,
				Vector3(x, RAIL_TOP - 0.09, (head_z + foot_z) * 0.5))
	# The headboard: a low panel, spindles above it and a top rail between the posts.
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(inner, 0.5, 0.06)), dark, Vector3(cx, 0.6, head_z))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(inner, 0.07, 0.09)), wood, Vector3(cx, 0.88, head_z))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(inner + 0.04, 0.1, 0.11)), wood, Vector3(cx, 1.34, head_z))
	_spindles(root, turned, cx, inner, head_z, 0.92, 1.29, 5)
	# The footboard: lower, a panel with three spindles over it.
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(inner, 0.36, 0.06)), dark, Vector3(cx, 0.48, foot_z))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(inner, 0.06, 0.08)), wood, Vector3(cx, 0.69, foot_z))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(inner + 0.04, 0.08, 0.1)), wood, Vector3(cx, 0.96, foot_z))
	_spindles(root, turned, cx, inner, foot_z, 0.72, 0.92, 3)
	_bedding(root, cx, inner, head_z, foot_z)
	if table:
		_table(root, turned, wood)
	return root


## `count` turned spindles across `inner` between heights `low` and `high`.
static func _spindles(root: Node3D, mat: Material, cx: float, inner: float, z: float, low: float, high: float, count: int) -> void:
	var mesh := Bookshelf._lathe(SPINDLE, 8)
	for i in count:
		var x := cx - inner * 0.5 + inner * (i + 1) / (count + 1.0)
		var s := HomeStoreFurniture._add(root, mesh, mat, Vector3(x, low, z))
		s.scale = Vector3(1, high - low, 1)


## The mattress, the quilt with the sheet turned over it, the pillows and the fur throw: one mesh in
## vertex colours (the cloth), and the pillows and fur as soft rounded shapes.
static func _bedding(root: Node3D, cx: float, inner: float, head_z: float, foot_z: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := foot_z - head_z - 0.06
	var mid_z := (head_z + foot_z) * 0.5
	var bottom := RAIL_TOP - 0.06
	# A thick mattress with a piped seam round its top.
	Bookshelf._cube(st, Vector3(cx, (bottom + MATTRESS_TOP - 0.03) * 0.5, mid_z), Vector3(inner - 0.02, MATTRESS_TOP - 0.03 - bottom, length), LINEN.darkened(0.08))
	Bookshelf._cube(st, Vector3(cx, MATTRESS_TOP - 0.035, mid_z), Vector3(inner, 0.025, length + 0.02), LINEN.darkened(0.2))
	Bookshelf._cube(st, Vector3(cx, MATTRESS_TOP - 0.015, mid_z), Vector3(inner - 0.04, 0.03, length - 0.04), LINEN)
	# The patchwork quilt from below the pillows to the foot, hanging down both sides.
	var quilt_head := head_z + 0.95
	var quilt_len := foot_z - 0.05 - quilt_head
	var cols := 4
	var rows := 6
	var pw := (inner + 0.06) / cols
	var pl := quilt_len / rows
	for r in rows:
		for c in cols:
			var colour: Color = PATCHES[(r * 3 + c * 2 + r * c) % PATCHES.size()]
			var px := cx - (inner + 0.06) * 0.5 + pw * (c + 0.5)
			var pz := quilt_head + pl * (r + 0.5)
			Bookshelf._cube(st, Vector3(px, MATTRESS_TOP + 0.03, pz), Vector3(pw - 0.012, 0.04, pl - 0.012), colour)
			_puff(st, Vector3(px, MATTRESS_TOP + 0.05, pz), Vector2(pw - 0.012, pl - 0.012), 0.05, colour)
		# The quilt's sides hang over the mattress's edge, patch by patch.
		for sx: float in [-1.0, 1.0]:
			var colour: Color = PATCHES[(r * 5 + (3 if sx > 0 else 0)) % PATCHES.size()]
			Bookshelf._cube(st, Vector3(cx + sx * (inner * 0.5 + 0.03), MATTRESS_TOP - 0.1, quilt_head + pl * (r + 0.5)),
					Vector3(0.04, 0.26, pl - 0.012), colour.darkened(0.12))
	# The seams between the patches show as a darker cloth below them.
	Bookshelf._cube(st, Vector3(cx, MATTRESS_TOP + 0.03, quilt_head + quilt_len * 0.5), Vector3(inner + 0.05, 0.05, quilt_len - 0.01), Color(0.3, 0.16, 0.1))
	# The sheet folded back over the quilt's top edge, a soft roll.
	Bookshelf._cube(st, Vector3(cx, MATTRESS_TOP + 0.07, quilt_head + 0.1), Vector3(inner + 0.08, 0.04, 0.22), LINEN)
	_puff(st, Vector3(cx, MATTRESS_TOP + 0.09, quilt_head + 0.1), Vector2(inner + 0.08, 0.22), 0.04, LINEN)
	var cloth := wool(Color(0.9, 0.9, 0.9), 0.3)
	cloth.vertex_color_use_as_albedo = true
	var bedding := MeshInstance3D.new()
	bedding.name = "Bedding"
	bedding.mesh = st.commit()
	bedding.material_override = cloth
	root.add_child(bedding)
	# Two plump pillows round the spot a click uses, a little cushion in front of them.
	var linen := wool(LINEN.darkened(0.12), 0.4)
	var pillow := Level.PILLOW
	var plump := _soft(0.5, 16, 8)
	for sx: float in [-1.0, 1.0]:
		var p := HomeStoreFurniture._add(root, plump, linen, Vector3(cx + sx * inner * 0.24, pillow.y - 0.02, pillow.z - 0.04 + sx * 0.03))
		p.scale = Vector3(0.58, 0.42, 0.5)
		p.rotation = Vector3(-0.35, sx * 0.08, sx * 0.05)
	var cushion := HomeStoreFurniture._add(root, plump, wool(PATCHES[0], 0.6), Vector3(cx + 0.18, pillow.y + 0.01, pillow.z + 0.36))
	cushion.scale = Vector3(0.42, 0.24, 0.34)
	cushion.rotation = Vector3(-0.5, 0.35, 0.1)
	# A fur throw over the foot of the bed, spilling over one side: soft overlapping folds of hide,
	# darker underneath, lighter where the hair lies on top.
	var fur := wool(FUR, 1.0)
	var tips := wool(FUR_TIPS, 1.0)
	var lump_mesh := _soft(0.5, 14, 7)
	var throw_z := foot_z - 0.5
	var top := MATTRESS_TOP + 0.06
	var throw := Node3D.new()
	throw.name = "FurThrow"
	root.add_child(throw)
	var folds := 6
	for k in folds:
		var x := cx - inner * 0.42 + inner * 0.9 * k / (folds - 1.0)
		var fold := HomeStoreFurniture._add(throw, lump_mesh, fur if k % 2 == 0 else tips,
				Vector3(x, top + 0.01 * (k % 2), throw_z + 0.05 * sin(k * 2.2)))
		fold.scale = Vector3(0.5, 0.17, 0.62 + 0.06 * cos(k * 1.7))
	# Tufts of long hair along its edges.
	var tuft := _soft(0.5, 8, 4)
	for k in 12:
		var x := cx - inner * 0.5 + inner * (k + 0.5) / 12.0
		for sz: float in [-1.0, 1.0]:
			var t := HomeStoreFurniture._add(throw, tuft, tips if (k + int(sz > 0.0)) % 2 == 0 else fur,
					Vector3(x, top + 0.02, throw_z + sz * (0.31 + 0.025 * sin(k * 2.7))))
			t.scale = Vector3(0.11, 0.08, 0.12)
	for k in 2:
		var hang := HomeStoreFurniture._add(throw, lump_mesh, fur, Vector3(cx + inner * 0.5 + 0.05, top - 0.17, throw_z - 0.14 + 0.3 * k))
		hang.scale = Vector3(0.07, 0.4, 0.32)


## A soft rounded shape (a sphere to squash into a pillow or a fold of fur).
static func _soft(radius: float, sides := 12, rings := 6) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = rings
	return mesh


## A puffed-up top of `size` (across, along) round `centre`: it bulges `puff` high in the middle
## like a wadded quilt square, and is level with `centre` at its edges.
static func _puff(st: SurfaceTool, centre: Vector3, size: Vector2, puff: float, colour: Color, steps := 4) -> void:
	st.set_color(colour)
	var at := func(i: int, j: int) -> Vector3:
		var u := float(i) / steps
		var v := float(j) / steps
		return centre + Vector3((u - 0.5) * size.x, puff * sin(PI * u) * sin(PI * v), (v - 0.5) * size.y)
	var normal := func(i: int, j: int) -> Vector3:
		var u := float(i) / steps
		var v := float(j) / steps
		var du := puff * PI * cos(PI * u) * sin(PI * v) / size.x
		var dv := puff * PI * sin(PI * u) * cos(PI * v) / size.y
		return Vector3(-du, 1.0, -dv).normalized()
	for i in steps:
		for j in steps:
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
				st.set_normal(normal.call(i + k.x, j + k.y))
				st.add_vertex(at.call(i + k.x, j + k.y))


## A soft wool cloth in `tint`: a fine knit of light and dark fibres over it, a bumpy surface and
## a fuzzy sheen at the edges where the light grazes it. `fuzz` (0..1) is how long the hair is:
## a little for linen and quilt, all of it for fur. The textures are made once and shared.
static func wool(tint: Color, fuzz: float) -> StandardMaterial3D:
	if _knit == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.08
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.72, 0.72))
		ramp.set_color(1, Color(1, 1, 1))
		_knit = NoiseTexture2D.new()
		_knit.width = 128
		_knit.height = 128
		_knit.seamless = true
		_knit.noise = noise
		_knit.color_ramp = ramp
		_knit_bumps = NoiseTexture2D.new()
		_knit_bumps.width = 128
		_knit_bumps.height = 128
		_knit_bumps.seamless = true
		_knit_bumps.as_normal_map = true
		_knit_bumps.bump_strength = 6.0
		_knit_bumps.noise = noise
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _knit
	m.normal_enabled = true
	m.normal_texture = _knit_bumps
	m.normal_scale = 0.5 + fuzz
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (4.0 - fuzz * 1.5)
	m.roughness = 1.0
	m.rim_enabled = true
	m.rim = 0.1 + 0.3 * fuzz
	m.rim_tint = 0.8
	return m


## The bedside table beside the head: a top on four turned legs with a shelf, a candle in a brass
## dish and a bound book (one of the bookshelf's) on it.
static func _table(root: Node3D, turned: Material, wood: Material) -> void:
	var left := RIGHT + 0.12
	var cx := (left + TABLE_EDGE) * 0.5
	var w := TABLE_EDGE - left
	var cz := HEAD + 0.5
	var d := 0.9
	var leg := Bookshelf._lathe(TABLE_LEG, 8)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			HomeStoreFurniture._add(root, leg, turned, Vector3(cx + sx * (w * 0.5 - 0.08), 0, cz + sz * (d * 0.5 - 0.08)))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(w, 0.06, d)), wood, Vector3(cx, 0.71, cz))
	HomeStoreFurniture._add(root, HomeStoreFurniture._box(Vector3(w - 0.12, 0.04, d - 0.12)), wood, Vector3(cx, 0.2, cz))
	# The candle on a brass dish, its flame glowing.
	var brass := HomeStoreFurniture._mat(Bookshelf.BRASS, 0.35, 0.6)
	var dish := CylinderMesh.new()
	dish.top_radius = 0.14
	dish.bottom_radius = 0.11
	dish.height = 0.03
	dish.radial_segments = 10
	HomeStoreFurniture._add(root, dish, brass, Vector3(cx + 0.2, 0.755, cz - 0.15))
	HomeStoreFurniture._add(root, Bookshelf._rod(0.32, 0.045), HomeStoreFurniture._mat(WAX, 0.6), Vector3(cx + 0.2, 0.93, cz - 0.15))
	var flame := StandardMaterial3D.new()
	flame.albedo_color = FLAME
	flame.emission_enabled = true
	flame.emission = FLAME
	flame.emission_energy_multiplier = 2.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tip := HomeStoreFurniture._add(root, _soft(0.035), flame, Vector3(cx + 0.2, 1.12, cz - 0.15))
	tip.scale = Vector3(1, 1.8, 1)
	# A book lying on the table, and one on the shelf below.
	var book := MeshInstance3D.new()
	book.mesh = Bookshelf._book_mesh(5)
	book.position = Vector3(cx - 0.12, 0.74 + Bookshelf.book_look(5).size.x * 0.5, cz + 0.12)
	book.rotation = Vector3(0, 0.4, PI * 0.5)
	root.add_child(book)
	var lower := MeshInstance3D.new()
	lower.mesh = Bookshelf._book_mesh(2)
	lower.position = Vector3(cx, 0.22 + Bookshelf.book_look(2).size.x * 0.5, cz)
	lower.rotation = Vector3(0, -0.2, PI * 0.5)
	root.add_child(lower)
