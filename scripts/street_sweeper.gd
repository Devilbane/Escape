class_name StreetSweeper
extends RefCounted
## Matthes, the village's street sweeper: he keeps the walkways passable. In autumn he sweeps the fallen
## leaves off them (see LeafSweep) and heaps them up at their edges, in winter he sweeps the snow off (see
## SnowSweep), both with a birch broom, on two rounds a day (SnowSweep.SHIFTS). The swept strip slowly
## fills in again, with leaves blown back or with fresh snow, so he never runs out of work.
##
## He is no map letter: Outdoor puts him up on a walkway near the square (see home_cell), like Pippi beside
## Pip. Out of autumn and winter he keeps to his spot, leaning on his broom.
##
## His clothes follow the seasons: a wide straw hat and a leather apron over a rough tunic from spring
## to autumn (built here, in the chunky shapes of the KayKit people, with a woven texture), and the village's
## winter clothes in winter (see WinterWear), when the hat and the apron stay in the chest.

const ROLE := "sweeper"
## The tag the straw hat and the apron carry, and where each hangs.
const HAT := "StrawHat"
const APRON := "SweeperApron"
## How far from the herald's spot (tiles) his spot is looked for.
const NEAR_TILES := 14

const STRAW := Color(0.86, 0.72, 0.4)
const STRAW_DARK := Color(0.62, 0.47, 0.22)
const RIBBON := Color(0.5, 0.2, 0.14)
const LEATHER := Color(0.45, 0.29, 0.16)
const LEATHER_DARK := Color(0.28, 0.17, 0.09)

## The straw hat in the head mesh's space (see PostCap: the Rogue's head, the face towards +z).
const CROWN_FOOT := 1.84
const CROWN_TOP := 2.34
const CROWN_RADIUS := 0.56
const BRIM_Y := 1.88
const BRIM_RADIUS := 0.95
const BRIM_DROOP := 0.16
const SIDES := 16

static var _hat_mesh: ArrayMesh
static var _apron_mesh: ArrayMesh
static var _straw_texture: ImageTexture
static var _leather_texture: ImageTexture


# --- The marked route -----------------------------------------------------------------------

## The way the village wants swept first, marked on the map by hand: a loop round the paved square, with the
## road west to the gate, spurs north and east, a branch to the south-west and another south. Each stretch is a list of cells (dx, dy) from the
## fountain's tile (the "F" of the map). He sweeps them in this order, out and back, before any other
## walkway; when the map has no fountain or a cell is not open ground, he goes by the walkways alone.
const MARKED := [
	# The road west of the gate and the top row of the square, east to the corner.
	[[-12, -4], [-11, -4], [-10, -4], [-9, -4], [-8, -4], [-7, -4], [-6, -4], [-5, -4], [-4, -4], [-3, -4], [-2, -4], [-1, -4], [0, -4], [1, -4], [2, -4], [3, -4], [4, -4], [5, -4]],
	# Down the east side and along the bottom, westward.
	[[5, -4], [5, -3], [5, -2], [5, -1], [5, 0], [5, 1], [5, 2], [5, 3], [5, 4], [4, 4], [3, 4], [2, 4], [1, 4], [0, 4], [-1, 4], [-2, 4], [-3, 4], [-4, 4]],
	# The bottom row on to the south-west corner.
	[[-4, 4], [-5, 4], [-6, 4], [-7, 4], [-8, 4], [-9, 4]],
	# Up the west side to the top row (the dots step in at the fountain's west).
	[[-5, -4], [-5, -3], [-5, -2], [-5, -1], [-5, 0], [-5, 1], [-6, 1], [-6, 2], [-6, 3]],
	# The branch to the south-west: down the path, then back east to the square's west side.
	[[-9, 1], [-9, 2], [-9, 3], [-8, 3], [-7, 3], [-6, 3]],
	# Short spurs north from the top row to the doors of the temple, the office and the guild.
	[[-2, -4], [-2, -5]],
	[[2, -4], [2, -5]],
	[[4, -4], [4, -5]],
	# A spur east by the house on the east side.
	[[5, -1], [6, -1]],
	# The new branch south from the square past the two houses, then east along the path.
	[[0, 4], [0, 5], [0, 6], [0, 7], [0, 8], [0, 9], [1, 9], [2, 9], [3, 9], [4, 9], [5, 9], [6, 9]],
]

## Game hours a marked stretch is left alone after he has swept it, so a stretch that cannot be made clean
## (a heap he cannot reach) does not keep him from the rest. By stretch: the world hour it was last started.
const MARKED_REST := 1.0
static var rested := {}
static var _marked_for := 0
static var _marked_cache: Array = []
static var _marked_cells := {}


## The marked stretches as lists of map cells (empty when the map does not fit them, see MARKED).
static func marked(level: Node) -> Array:
	if level == null or not (level is Outdoor):
		return []
	if _marked_for == level.get_instance_id():
		return _marked_cache
	_marked_for = level.get_instance_id()
	_marked_cache = []
	_marked_cells = {}
	rested = {}
	var f := Vector2i(-1, -1)
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == "F":
				f = Vector2i(x, y)
	if f.x < 0:
		return _marked_cache
	var stretches: Array = []
	for stretch: Array in MARKED:
		# The open cells of the stretch; where one is blocked (a lantern post, a stall) he walks round it.
		var cells: Array[Vector2i] = []
		for d: Array in stretch:
			var c := f + Vector2i(d[0], d[1])
			if not level.is_open(c):
				continue
			if not cells.is_empty() and (cells.back() - c).abs() != Vector2i(1, 0) and (cells.back() - c).abs() != Vector2i(0, 1):
				var around: Array = level.grid_path(cells.back(), c)
				if around.size() < 2 or around.size() > 6:
					cells = []
					break
				for a: Vector2i in around.slice(1):
					cells.append(a)
				continue
			cells.append(c)
		if cells.size() >= 2:
			stretches.append(cells)
			for c in cells:
				_marked_cells[c] = true
	_marked_cache = stretches
	return _marked_cache


## Whether `c` lies on the marked route.
static func is_marked(level: Node, c: Vector2i) -> bool:
	marked(level)
	return _marked_for == level.get_instance_id() and _marked_cells.has(c)


## The tile he waits on between his rounds: the open walkway tile nearest to the herald, but not beside
## anyone else's spot. (-1, -1) when there is no walkway.
static func home_cell(level: Outdoor) -> Vector2i:
	var from := Vector2i(level.width / 2, level.height / 2)
	for v: Villager in level.villagers:
		if v.role == "K":
			from = v.home
	var taken: Array[Vector2i] = []
	for v: Villager in level.villagers:
		taken.append(v.home)
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for dy in range(-NEAR_TILES, NEAR_TILES + 1):
		for dx in range(-NEAR_TILES, NEAR_TILES + 1):
			var c := from + Vector2i(dx, dy)
			var d := float(dx * dx + dy * dy)
			if d >= best_d or d < 9.0:
				continue
			var ch: String = level.cell_char(c)
			if ch == "" or not SurfaceLife.PATH.contains(ch) or not level.is_open(c):
				continue
			if taken.any(func(t: Vector2i) -> bool: return absi(t.x - c.x) + absi(t.y - c.y) < 3):
				continue
			best = c
			best_d = d
	return best


# --- Gear -------------------------------------------------------------------------------------

## Puts the straw hat and the apron on a model (once). They are shown or hidden with the clothes of the
## season (see show_gear).
static func put_on(model: Node3D) -> void:
	var slot := HairLook.head_slot(model)
	if slot != null and slot.get_node_or_null(HAT) == null:
		var hat := MeshInstance3D.new()
		hat.name = HAT
		hat.mesh = hat_mesh()
		hat.transform = slot.get_meta("bind")
		slot.add_child(hat)
		HairLook.cover(model, true)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null and skeleton.find_child(APRON, true, false) == null:
		var bone := skeleton.find_bone("chest")
		if bone >= 0:
			var attach := BoneAttachment3D.new()
			attach.name = APRON + "Slot"
			attach.bone_name = "chest"
			attach.set_meta("bind", skeleton.get_bone_global_rest(bone).affine_inverse())
			skeleton.add_child(attach)
			var apron := MeshInstance3D.new()
			apron.name = APRON
			apron.mesh = apron_mesh()
			apron.transform = attach.get_meta("bind")
			attach.add_child(apron)


## Shows the summer clothes (the hat and the apron) or hides them (in winter the winter clothes replace them).
static func show_gear(model: Node3D, shown: bool) -> void:
	var hat := model.find_child(HAT, true, false) as Node3D
	if hat != null:
		hat.visible = shown
		HairLook.cover(model, shown)
	var apron := model.find_child(APRON, true, false) as Node3D
	if apron != null:
		apron.visible = shown


static func hat_mesh() -> ArrayMesh:
	if _hat_mesh != null:
		return _hat_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# The brim: a wide, slightly drooping disc of woven straw, seen from above and from below, with a
	# dark binding round its rim. u runs round it, v out from the crown, so the weave follows the circle.
	var rings := 4
	for k in rings:
		var r0 := lerpf(CROWN_RADIUS - 0.04, BRIM_RADIUS, float(k) / rings)
		var r1 := lerpf(CROWN_RADIUS - 0.04, BRIM_RADIUS, float(k + 1) / rings)
		var y0 := BRIM_Y - BRIM_DROOP * pow(float(k) / rings, 2.0)
		var y1 := BRIM_Y - BRIM_DROOP * pow(float(k + 1) / rings, 2.0)
		_band(st, y0, r0, y1, r1, Color(1, 1, 1), float(k) / rings * 2.0, float(k + 1) / rings * 2.0, true)
	# The binding on the rim.
	_band(st, BRIM_Y - BRIM_DROOP, BRIM_RADIUS, BRIM_Y - BRIM_DROOP + 0.03, BRIM_RADIUS + 0.012, STRAW_DARK * 0.9, 0.0, 0.1, false)
	# The crown: straight sides, a flat dome on top.
	_band(st, CROWN_FOOT, CROWN_RADIUS, CROWN_TOP - 0.08, CROWN_RADIUS - 0.03, Color(1, 1, 1), 0.0, 1.0, false)
	_band(st, CROWN_TOP - 0.08, CROWN_RADIUS - 0.03, CROWN_TOP, CROWN_RADIUS - 0.2, Color(1, 1, 1), 1.0, 1.3, false)
	_cap(st, CROWN_TOP, CROWN_RADIUS - 0.2)
	# The ribbon round the crown's foot, with a small knot and two tails at the back.
	_band(st, CROWN_FOOT + 0.04, CROWN_RADIUS + 0.012, CROWN_FOOT + 0.2, CROWN_RADIUS + 0.004, RIBBON, 0.0, 0.1, false)
	st.set_color(RIBBON)
	st.set_uv(Vector2(0.05, 0.05))
	for tail in [-1.0, 1.0]:
		var base := Vector3(sin(PI + 0.1 * tail) * (CROWN_RADIUS + 0.02), CROWN_FOOT + 0.04, cos(PI + 0.1 * tail) * (CROWN_RADIUS + 0.02))
		var tip := base + Vector3(0.12 * tail, -0.34, -0.1)
		var wide := Vector3(0.05, 0, 0)
		for p in [base - wide, base + wide, tip, base - wide, tip, base + wide]:
			st.add_vertex(p)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = straw_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_hat_mesh = st.commit()
	return _hat_mesh


## A band of quads from (y0, r0) to (y1, r1) round the head, with u 0..1 round it and v from `v0` to `v1`.
static func _band(st: SurfaceTool, y0: float, r0: float, y1: float, r1: float, colour: Color, v0: float, v1: float, flat: bool) -> void:
	st.set_color(colour)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var u0 := float(i) / SIDES * 3.0
		var u1 := float(i + 1) / SIDES * 3.0
		var b0 := Vector3(sin(a0) * r0, y0, cos(a0) * r0)
		var b1 := Vector3(sin(a1) * r0, y0, cos(a1) * r0)
		var t0 := Vector3(sin(a0) * r1, y1, cos(a0) * r1)
		var t1 := Vector3(sin(a1) * r1, y1, cos(a1) * r1)
		var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)]
		var pts := [b0, b1, t1, b0, t1, t0]
		for k in 6:
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])


static func _cap(st: SurfaceTool, y: float, r: float) -> void:
	st.set_color(Color(0.95, 0.95, 0.95))
	var mid := Vector3(0, y + 0.03, 0)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		st.set_uv(Vector2(float(i + 1) / SIDES * 3.0, 1.3))
		st.add_vertex(Vector3(sin(a1) * r, y, cos(a1) * r))
		st.set_uv(Vector2(float(i) / SIDES * 3.0, 1.3))
		st.add_vertex(Vector3(sin(a0) * r, y, cos(a0) * r))
		st.set_uv(Vector2(0.5, 1.4))
		st.add_vertex(mid)


## The woven straw: bands of plaited straw running round, each plait a row of slanted stalks, with a few
## darker and paler stalks and fine grain.
static func straw_texture() -> ImageTexture:
	if _straw_texture != null:
		return _straw_texture
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var stalk := PackedFloat32Array()
	for i in size:
		stalk.append(rng.randf_range(-0.12, 0.12))
	for y in size:
		var plait := y / 8
		for x in size:
			var slant := float((x + y * 2) % 8) / 8.0
			var shade := 0.82 + 0.18 * absf(slant - 0.5) * 2.0
			# Every plait row a touch different, the seam between two darker.
			shade *= 1.0 - 0.07 * float(plait % 3)
			if y % 8 == 0:
				shade *= 0.72
			shade += stalk[(x * 7 + y * 3) % size] + rng.randf_range(-0.05, 0.05)
			var col := STRAW.lerp(STRAW_DARK, clampf(1.0 - shade, 0.0, 1.0) * 1.4)
			col = col * clampf(shade, 0.6, 1.1)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	img.generate_mipmaps()
	_straw_texture = ImageTexture.create_from_image(img)
	return _straw_texture


## The leather apron: a panel on the chest and belly, a strap round the neck, the waist ties and a patch
## pocket, in the chest bone's rest space (the front towards +z). The leather is grained and scuffed.
static func apron_mesh() -> ArrayMesh:
	if _apron_mesh != null:
		return _apron_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Panel: wider at the chest, hanging to the thigh; slightly bowed out.
	var top := 1.28
	var bottom := 0.52
	var front := 0.27
	var half_top := 0.22
	var half_bottom := 0.3
	var rows := 5
	for k in rows:
		var f0 := float(k) / rows
		var f1 := float(k + 1) / rows
		var y0 := lerpf(top, bottom, f0)
		var y1 := lerpf(top, bottom, f1)
		var w0 := lerpf(half_top, half_bottom, f0)
		var w1 := lerpf(half_top, half_bottom, f1)
		var z0 := front + 0.05 * sin(f0 * PI * 0.8)
		var z1 := front + 0.05 * sin(f1 * PI * 0.8)
		var a := Vector3(-w0, y0, z0)
		var b := Vector3(w0, y0, z0)
		var c := Vector3(w1, y1, z1)
		var d := Vector3(-w1, y1, z1)
		_quad(st, a, b, c, d, Color(1, 1, 1), Vector2(0, f0), Vector2(1, f1))
	# A patch pocket on the belly, a darker leather piece with a stitched rim.
	var pk := front + 0.058
	_quad(st, Vector3(-0.14, 0.95, pk), Vector3(0.14, 0.95, pk), Vector3(0.14, 0.72, pk + 0.002), Vector3(-0.14, 0.72, pk + 0.002), Color(0.7, 0.62, 0.55), Vector2(0, 0), Vector2(1, 1))
	# The neck strap and the waist ties running round to the back.
	for sx in [-1.0, 1.0]:
		_quad(st, Vector3(sx * 0.2, top, front - 0.01), Vector3(sx * 0.14, top, front - 0.01), Vector3(sx * 0.1, top + 0.22, 0.0), Vector3(sx * 0.16, top + 0.22, 0.0), Color(0.8, 0.7, 0.6), Vector2(0, 0), Vector2(0.2, 1))
		_quad(st, Vector3(sx * 0.3, 0.76, front - 0.02), Vector3(sx * 0.33, 0.7, front - 0.02), Vector3(sx * 0.25, 0.7, -0.25), Vector3(sx * 0.22, 0.76, -0.25), Color(0.8, 0.7, 0.6), Vector2(0, 0), Vector2(0.2, 1))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = leather_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_apron_mesh = st.commit()
	return _apron_mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, uv0: Vector2, uv1: Vector2) -> void:
	st.set_color(colour)
	var uvs := [Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y)]
	var pts := [a, b, c, a, c, d]
	for k in 6:
		st.set_uv(uvs[k])
		st.add_vertex(pts[k])


## Grained, scuffed brown leather with darker creases and a few pale scratches.
static func leather_texture() -> ImageTexture:
	if _leather_texture != null:
		return _leather_texture
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.09
	var fine := FastNoiseLite.new()
	fine.seed = 78
	fine.frequency = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for y in size:
		for x in size:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var g := fine.get_noise_2d(x, y) * 0.5 + 0.5
			var col := LEATHER.lerp(LEATHER_DARK, clampf(n * 1.3 - 0.2, 0.0, 1.0)) * (0.85 + 0.3 * g)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	# Pale scratches and scuffs.
	for i in 22:
		var p := Vector2(rng.randf() * size, rng.randf() * size)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for s in rng.randi_range(5, 16):
			var q := p + dir * s
			var px := posmod(int(q.x), size)
			var py := posmod(int(q.y), size)
			var old := img.get_pixel(px, py)
			img.set_pixel(px, py, old.lerp(Color(0.72, 0.55, 0.38), 0.55))
	img.generate_mipmaps()
	_leather_texture = ImageTexture.create_from_image(img)
	return _leather_texture
