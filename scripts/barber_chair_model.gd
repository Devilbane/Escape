class_name BarberChairModel
extends RefCounted
## The barber's chair and his side table, built from shapes (see BarberChair). Everything is laid out with
## the chair's front towards +z and its feet on y = 0; the seat top is SEAT_TOP high.
##
## The wood and the iron are laid into one weathered mesh each (WeatheredProps.Builder, so they have
## grain, rust and grime like the rest of the village). The cushions are soft, rounded pads in
## stitched, tufted leather with a grain and a bumpy surface; the small things on the table
## (scissors, comb, razor, brush, bottle, mirror) have their own materials: polished steel, bone,
## glass, silvered glass and a woven towel.

## The height of the seat's top (metres).
const SEAT_TOP := 0.48
## How far the chair's box reaches behind its middle and in front of it (to the back and the footrest tip).
const BACK_REACH := 0.4
const FRONT_REACH := 0.86
## Where the chair's middle is, the table beside it, measured from the chair's middle.
const TABLE_AT := Vector3(0.95, 0.0, 0.12)
const TABLE_SIZE := Vector2(0.64, 0.46)
const TABLE_HEIGHT := 0.82

const WOOD := Color(0.5, 0.31, 0.17)
const DARK_WOOD := Color(0.34, 0.21, 0.12)
const IRON_DARK := Color(0.3, 0.31, 0.34)
const LEATHER := Color(0.46, 0.13, 0.09)
const BRASS := Color(0.86, 0.66, 0.3)

static var _leather: StandardMaterial3D
static var _grain: NoiseTexture2D
static var _bumps: NoiseTexture2D


## The chair and its table, one node with the feet of the chair on its origin.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BarberChair"
	_chair(root)
	var table := _table()
	table.position = TABLE_AT
	root.add_child(table)
	return root


# --- Materials ---------------------------------------------------------------------------------------

## Oxblood leather: a fine grain of darker creases over the colour, a bumpy surface and a soft
## shine. Made once and shared.
static func leather() -> StandardMaterial3D:
	if _leather != null:
		return _leather
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.07
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.55, 0.5, 0.5))
		ramp.set_color(1, Color(1, 1, 1))
		_grain = NoiseTexture2D.new()
		_grain.width = 256
		_grain.height = 256
		_grain.seamless = true
		_grain.noise = noise
		_grain.color_ramp = ramp
		_bumps = NoiseTexture2D.new()
		_bumps.width = 256
		_bumps.height = 256
		_bumps.seamless = true
		_bumps.as_normal_map = true
		_bumps.bump_strength = 5.0
		_bumps.noise = noise
	var m := StandardMaterial3D.new()
	m.albedo_color = LEATHER
	m.albedo_texture = _grain
	m.normal_enabled = true
	m.normal_texture = _bumps
	m.normal_scale = 0.8
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	m.roughness = 0.5
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.6
	_leather = m
	return m


static func _mat(colour: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	m.metallic = metallic
	return m


static func steel() -> StandardMaterial3D:
	return _mat(Color(0.82, 0.84, 0.88), 0.28, 0.85)


static func brass() -> StandardMaterial3D:
	return _mat(BRASS, 0.35, 0.8)


# --- Shapes ------------------------------------------------------------------------------------------

static func _sgn_pow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


## A soft, rounded pad (a superellipsoid: `n` 2 is an egg, 6 nearly a box), `size` big, with a smooth
## surface: cushions, armrest pads and the headrest.
static func pad(size: Vector3, n := 3.6, rings := 14, segments := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := 2.0 / n
	var grid: Array = []
	for i in rings + 1:
		var v := -PI * 0.5 + PI * i / rings
		var row: Array = []
		for j in segments + 1:
			var u := -PI + TAU * j / segments
			row.append(Vector3(size.x * 0.5 * _sgn_pow(cos(v), e) * _sgn_pow(cos(u), e),
					size.y * 0.5 * _sgn_pow(sin(v), e),
					size.z * 0.5 * _sgn_pow(cos(v), e) * _sgn_pow(sin(u), e)))
		grid.append(row)
	for i in rings:
		for j in segments:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j + 1]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i + 1][j]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(c)
	st.generate_normals()
	return st.commit()


static func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, at: Vector3, radius: float, mat: Material) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 5
	_add(parent, s, mat, at)


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(radius: float, height: float, segments := 14, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top < 0.0 else top
	c.height = height
	c.radial_segments = segments
	return c


# --- The chair ---------------------------------------------------------------------------------------

static func _chair(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wood := WeatheredProps.Builder.new()
	var iron := WeatheredProps.Builder.new()
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-14.0))
	var leather_mat := leather()
	var gold := brass()

	# The iron foot: a heavy round plate on four curled feet, the column and the pump with its collar.
	iron.cylinder(Vector3(0, 0.0, 0), 0.36, 0.33, 0.05, IRON_DARK, WeatheredProps.IRON, 18)
	iron.cylinder(Vector3(0, 0.05, 0), 0.3, 0.2, 0.05, IRON_DARK, WeatheredProps.IRON, 18)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var out := Vector3(cos(a), 0, sin(a))
		iron.bar(out * 0.2 + Vector3(0, 0.03, 0), out * 0.4 + Vector3(0, 0.012, 0), 0.03, IRON_DARK, WeatheredProps.IRON, 8)
	iron.cylinder(Vector3(0, 0.1, 0), 0.115, 0.1, 0.06, IRON_DARK, WeatheredProps.IRON, 14)
	iron.cylinder(Vector3(0, 0.16, 0), 0.085, 0.065, 0.2, IRON_DARK, WeatheredProps.IRON, 12)
	iron.cylinder(Vector3(0, 0.3, 0), 0.1, 0.1, 0.03, IRON_DARK, WeatheredProps.IRON, 12)

	# The seat: a wooden frame under the cushion, a rail round the back and a plank in the front.
	wood.box(Vector3(0, 0.33, 0), Vector3(0.78, 0.07, 0.62), WOOD)
	wood.box(Vector3(0, 0.325, 0.3), Vector3(0.82, 0.05, 0.04), DARK_WOOD)
	iron.box(Vector3(0, 0.305, 0), Vector3(0.6, 0.03, 0.4), IRON_DARK, WeatheredProps.IRON)

	# The back: two stout uprights that lean back, a top rail with a carved crest, a lower rail.
	var back_foot := Vector3(0, 0.36, -0.29)
	for sx: float in [-1.0, 1.0]:
		wood.box(back_foot + tilt * Vector3(sx * 0.36, 0, 0), Vector3(0.07, 0.9, 0.07), WOOD, WeatheredProps.WOOD, tilt)
	wood.box(back_foot + tilt * Vector3(0, 0.82, 0), Vector3(0.8, 0.08, 0.08), DARK_WOOD, WeatheredProps.WOOD, tilt)
	wood.box(back_foot + tilt * Vector3(0, 0.0, 0), Vector3(0.72, 0.07, 0.06), DARK_WOOD, WeatheredProps.WOOD, tilt)
	wood.frustum(back_foot + tilt * Vector3(0, 0.89, 0), Vector2(0.36, 0.06), Vector2(0.14, 0.05), 0.07, WOOD, WeatheredProps.WOOD, tilt)

	# The arms: a post up from the seat frame, a long board of wood with a rounded front.
	for sx: float in [-1.0, 1.0]:
		wood.box(Vector3(sx * 0.45, 0.34, 0.0), Vector3(0.06, 0.34, 0.06), WOOD)
		wood.box(Vector3(sx * 0.45, 0.66, -0.3), Vector3(0.085, 0.04, 0.62), DARK_WOOD)
		wood.cylinder(Vector3(sx * 0.45, 0.66, 0.31), 0.0425, 0.0425, 0.04, DARK_WOOD, WeatheredProps.WOOD, 10)
		wood.box(Vector3(sx * 0.45, 0.34, -0.3), Vector3(0.05, 0.32, 0.05), WOOD)

	# The headrest on two iron rods that slide up out of the top rail.
	var head_base := back_foot + tilt * Vector3(0, 0.86, 0)
	for sx: float in [-1.0, 1.0]:
		iron.bar(head_base + tilt * Vector3(sx * 0.09, 0, 0), head_base + tilt * Vector3(sx * 0.09, 0.3, 0.02), 0.012, IRON_DARK, WeatheredProps.IRON, 8)

	# The footrest: an iron arm from the column forward and a wooden step, tilted up at the toes, with a
	# brass strip along its edge.
	iron.bar(Vector3(0, 0.22, 0.06), Vector3(0, 0.2, 0.62), 0.028, IRON_DARK, WeatheredProps.IRON, 8)
	iron.bar(Vector3(-0.1, 0.21, 0.55), Vector3(-0.1, 0.18, 0.67), 0.02, IRON_DARK, WeatheredProps.IRON, 8)
	iron.bar(Vector3(0.1, 0.21, 0.55), Vector3(0.1, 0.18, 0.67), 0.02, IRON_DARK, WeatheredProps.IRON, 8)
	var step := Basis(Vector3.RIGHT, deg_to_rad(-24.0))
	wood.box(Vector3(0, 0.17, 0.72), Vector3(0.42, 0.045, 0.28), WOOD, WeatheredProps.WOOD, step)
	for k in 4:
		wood.box(Vector3(0, 0.205, 0.72) + step * Vector3(0, 0, -0.1 + k * 0.07), Vector3(0.38, 0.012, 0.02), DARK_WOOD, WeatheredProps.WOOD, step)

	# A lever at the side to tip the chair back and a foot pedal to pump it up.
	iron.bar(Vector3(0.14, 0.3, 0.05), Vector3(0.46, 0.38, -0.12), 0.012, IRON_DARK, WeatheredProps.IRON, 8)
	iron.bar(Vector3(0.1, 0.06, 0.1), Vector3(0.3, 0.05, 0.4), 0.016, IRON_DARK, WeatheredProps.IRON, 8)

	wood.finish(root)
	iron.finish(root)

	# The leather: the thick seat cushion, the padded back with tufted buttons, the head pad, the arm pads.
	_add(root, pad(Vector3(0.78, 0.18, 0.62), 3.2), leather_mat, Vector3(0, 0.4, 0.0))
	_add(root, pad(Vector3(0.66, 0.7, 0.14), 3.2), leather_mat, back_foot + tilt * Vector3(0, 0.46, 0.09), Vector3(deg_to_rad(-14.0), 0, 0))
	_add(root, pad(Vector3(0.36, 0.22, 0.11), 3.0), leather_mat, head_base + tilt * Vector3(0, 0.37, 0.05), Vector3(deg_to_rad(-14.0), 0, 0))
	for sx: float in [-1.0, 1.0]:
		_add(root, pad(Vector3(0.1, 0.06, 0.44), 3.0), leather_mat, Vector3(sx * 0.45, 0.7, -0.1))
		_ball(root, Vector3(sx * 0.45, 0.66, 0.335), 0.03, gold)
	# A thin padded cover on the step.
	_add(root, pad(Vector3(0.36, 0.035, 0.22), 3.0), leather_mat, Vector3(0, 0.205, 0.72) + step * Vector3(0, 0.03, 0), Vector3(deg_to_rad(-24.0), 0, 0))

	# Tufted buttons in the back, brass studs along the seat's front and the back's edge.
	var button := _mat(LEATHER.darkened(0.45), 0.5)
	for row in 4:
		for col in 3:
			var off := Vector3((col - 1) * 0.18 + (0.075 if row % 2 == 1 else 0.0) - (0.0375 if row % 2 == 1 else 0.0), 0.2 + row * 0.13, 0.17)
			_ball(root, back_foot + tilt * off, 0.017, button)
	for k in 9:
		_ball(root, Vector3(-0.34 + k * 0.085, 0.37, 0.305), 0.013, gold)
	for k in 8:
		_ball(root, back_foot + tilt * Vector3(-0.31 + k * 0.088, 0.76, 0.17), 0.011, gold)

	# Brass caps on the headrest rods, a brass ring on the column.
	for sx: float in [-1.0, 1.0]:
		_ball(root, head_base + tilt * Vector3(sx * 0.09, 0.3, 0.02), 0.016, gold)
	_add(root, _cyl(0.125, 0.018, 18), gold, Vector3(0, 0.255, 0))
	_add(root, _cyl(0.07, 0.012, 14), gold, Vector3(0, 0.07, 0))


# --- The side table ----------------------------------------------------------------------------------

## A small table of dark wood on turned legs, with a shelf under it for the clean towels, and on it
## what a barber needs: a standing mirror, scissors, a comb, a razor, a shaving bowl and brush, a
## tonic bottle and a folded towel.
static func _table() -> Node3D:
	var root := Node3D.new()
	root.name = "BarberTable"
	var wood := WeatheredProps.Builder.new()
	var w := TABLE_SIZE.x
	var d := TABLE_SIZE.y
	var h := TABLE_HEIGHT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var foot := Vector3(sx * (w * 0.5 - 0.05), 0, sz * (d * 0.5 - 0.05))
			wood.cylinder(foot, 0.028, 0.02, h - 0.04, DARK_WOOD, WeatheredProps.WOOD, 8)
			wood.cylinder(foot + Vector3(0, 0.2, 0), 0.034, 0.034, 0.05, DARK_WOOD, WeatheredProps.WOOD, 8)
			wood.cylinder(foot, 0.036, 0.03, 0.04, DARK_WOOD, WeatheredProps.WOOD, 8)
	wood.box(Vector3(0, h - 0.04, 0), Vector3(w + 0.04, 0.045, d + 0.04), WOOD)
	wood.box(Vector3(0, h - 0.07, 0), Vector3(w - 0.04, 0.04, d - 0.04), DARK_WOOD)
	wood.box(Vector3(0, 0.22, 0), Vector3(w - 0.06, 0.03, d - 0.06), WOOD)
	wood.finish(root)
	var gold := brass()
	var top := h + 0.005
	# Brass studs round the table top.
	for k in 6:
		_ball(root, Vector3(-w * 0.5 + 0.03 + k * (w - 0.06) / 5.0, h - 0.02, d * 0.5 + 0.022), 0.009, gold)

	# The standing mirror: a round silvered glass in a carved wooden ring on a stand that tips.
	var mirror := Node3D.new()
	mirror.position = Vector3(-0.1, top, -0.1)
	mirror.rotation.x = deg_to_rad(-9.0)
	root.add_child(mirror)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.135
	ring.outer_radius = 0.17
	ring.rings = 28
	ring.ring_segments = 10
	_add(mirror, ring, _mat(Color(0.42, 0.26, 0.14), 0.55), Vector3(0, 0.3, 0), Vector3(deg_to_rad(90.0), 0, 0))
	var glass := _cyl(0.14, 0.008, 28)
	var silver := _mat(Color(0.66, 0.78, 0.9), 0.05, 0.55)
	silver.rim_enabled = true
	silver.rim = 0.3
	silver.rim_tint = 0.0
	_add(mirror, glass, silver, Vector3(0, 0.3, 0.0), Vector3(deg_to_rad(90.0), 0, 0))
	for sx: float in [-1.0, 1.0]:
		_add(mirror, _cyl(0.011, 0.31), _mat(Color(0.34, 0.2, 0.11), 0.6), Vector3(sx * 0.16, 0.155, 0.0))
		_ball(mirror, Vector3(sx * 0.16, 0.315, 0.0), 0.017, gold)
	_add(mirror, _box(Vector3(0.38, 0.025, 0.08)), _mat(Color(0.34, 0.2, 0.11), 0.6), Vector3(0, 0.012, 0.0))

	# The scissors: two blades crossed on a pin, two finger rings, lying open on the table.
	var scissors := Node3D.new()
	scissors.position = Vector3(0.1, top + 0.004, -0.04)
	scissors.rotation.y = deg_to_rad(28.0)
	root.add_child(scissors)
	var blade := steel()
	for k: float in [-1.0, 1.0]:
		var a := Basis(Vector3.UP, k * deg_to_rad(9.0))
		_add(scissors, _box(Vector3(0.008, 0.003, 0.14)), blade, a * Vector3(0, 0.0015 * k + 0.002, 0.07), Vector3(0, k * deg_to_rad(9.0), 0))
		_add(scissors, _box(Vector3(0.008, 0.004, 0.06)), blade, a * Vector3(0, 0.0015 * k + 0.002, -0.04), Vector3(0, k * deg_to_rad(9.0), 0))
		var loop := TorusMesh.new()
		loop.inner_radius = 0.0125
		loop.outer_radius = 0.019
		loop.rings = 16
		loop.ring_segments = 6
		_add(scissors, loop, blade, a * Vector3(0, 0.0015 * k + 0.002, -0.095), Vector3(0, k * deg_to_rad(9.0), 0))
	_ball(scissors, Vector3(0, 0.006, 0.0), 0.006, gold)

	# The comb: a bone back with fine teeth.
	var comb := Node3D.new()
	comb.position = Vector3(0.14, top, 0.1)
	comb.rotation.y = deg_to_rad(-20.0)
	root.add_child(comb)
	var bone := _mat(Color(0.9, 0.86, 0.74), 0.55)
	_add(comb, _box(Vector3(0.12, 0.008, 0.026)), bone, Vector3(0, 0.004, 0))
	for k in 20:
		_add(comb, _box(Vector3(0.0022, 0.005, 0.022)), bone, Vector3(-0.057 + k * 0.006, 0.0025, 0.022))

	# The razor, folded open: a wooden grip and a steel blade.
	var razor := Node3D.new()
	razor.position = Vector3(-0.2, top, 0.1)
	razor.rotation.y = deg_to_rad(18.0)
	root.add_child(razor)
	_add(razor, _box(Vector3(0.1, 0.014, 0.02)), _mat(Color(0.18, 0.1, 0.06), 0.45), Vector3(-0.07, 0.007, 0))
	_add(razor, _box(Vector3(0.09, 0.004, 0.017)), steel(), Vector3(0.045, 0.006, 0.0))
	_ball(razor, Vector3(-0.02, 0.008, 0.0), 0.006, gold)

	# The shaving bowl: white glazed ceramic with a heap of foam and a brush leaning on it.
	var bowl := Node3D.new()
	bowl.position = Vector3(0.0, top, 0.1)
	root.add_child(bowl)
	_add(bowl, _cyl(0.065, 0.05, 20, 0.045), _mat(Color(0.93, 0.93, 0.9), 0.12), Vector3(0, 0.025, 0))
	var foam := _mat(Color(0.98, 0.98, 0.97), 0.9)
	_add(bowl, pad(Vector3(0.12, 0.07, 0.12), 2.2, 8, 14), foam, Vector3(0, 0.055, 0))
	_add(bowl, _cyl(0.005, 0.1, 8), _mat(Color(0.34, 0.2, 0.11), 0.5), Vector3(0.07, 0.07, 0.0), Vector3(0, 0, deg_to_rad(-38.0)))
	_add(bowl, _cyl(0.012, 0.04, 8, 0.008), _mat(Color(0.8, 0.72, 0.55), 0.95), Vector3(0.034, 0.108, 0.0), Vector3(0, 0, deg_to_rad(-38.0)))

	# A tonic bottle of green glass with a cork and a paper label.
	var bottle := Node3D.new()
	bottle.position = Vector3(-0.22, top, -0.1)
	root.add_child(bottle)
	var glassy := _mat(Color(0.12, 0.38, 0.2, 0.82), 0.08, 0.1)
	glassy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add(bottle, _cyl(0.032, 0.095, 14), glassy, Vector3(0, 0.0475, 0))
	_add(bottle, _cyl(0.012, 0.045, 10, 0.011), glassy, Vector3(0, 0.12, 0))
	_add(bottle, _cyl(0.012, 0.016, 8, 0.012), _mat(Color(0.62, 0.45, 0.28), 0.9), Vector3(0, 0.152, 0))
	_add(bottle, _cyl(0.0335, 0.04, 14), _mat(Color(0.93, 0.88, 0.72), 0.9), Vector3(0, 0.045, 0))

	# A folded towel of woven linen with a stripe, on the shelf below, and a spare one on the table.
	var linen := CosyBed.wool(Color(0.92, 0.9, 0.84), 0.15)
	_add(root, pad(Vector3(0.3, 0.07, 0.2), 4.0, 8, 16), linen, Vector3(0.04, 0.265, 0.0))
	_add(root, pad(Vector3(0.28, 0.06, 0.19), 4.0, 8, 16), CosyBed.wool(Color(0.55, 0.65, 0.8), 0.15), Vector3(0.05, 0.325, 0.0))
	return root
