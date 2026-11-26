class_name HiveModels
extends RefCounted
## The things of the apiary, built in code with textures of their own (see Apiary):
## - the straw skep: a bell of coiled straw bound with twine, a dark entrance arch, a knob on top, standing on a
##   round board on four legs under a flat stone;
## - the wooden box hive: a stand with a sloped landing board, two painted boxes and a honey super with corner
##   posts, hand slots and an entrance slot, and a gabled roof of weathered zinc under a stone;
## - the bee: a striped abdomen, a furry thorax, a head and two wings that blur when they beat;
## - the wild flowers of the bees' meadow (see Apiary): daisy-like heads of five colours, and lavender spikes.
## Every surface has a texture made here (planks with flaking paint, coiled straw, ribbed zinc, rough stone,
## bee fur), shared by all pieces. Sizes are in metres.

const SKEP_HEIGHT := 0.86
const SKEP_RADIUS := 0.44
const SKEP_COILS := 12
## The paints of the box hives, picked by the hive's number.
const PAINTS := [Color(0.93, 0.92, 0.86), Color(0.55, 0.72, 0.84), Color(0.93, 0.78, 0.38), Color(0.62, 0.78, 0.6)]
## The box hive's overall height: stand, two boxes, super, lid and roof.
const BOX_HEIGHT := 1.18

static var _tex := {}
static var _mats := {}
static var _meshes := {}


# --- Textures ---------------------------------------------------------------------------

static func _noise(seed_value: int, frequency: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n


static func _image_texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Planks laid across one another, painted in `paint`, with grain, seams and flaked patches of bare grey wood.
static func wood_texture(paint: Color) -> ImageTexture:
	var key := "wood_" + paint.to_html()
	if _tex.has(key):
		return _tex[key]
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var grain := _noise(11, 0.09)
	var wear := _noise(23, 0.035, 2)
	var bare := Color(0.5, 0.43, 0.34)
	for y in size:
		for x in size:
			var plank := y / 32
			var seam := y % 32
			var g := grain.get_noise_2d(x * 0.35 + plank * 17.0, y * 2.4)
			var c := paint * (0.93 + 0.1 * g)
			var w := wear.get_noise_2d(x + plank * 40.0, y)
			if w > 0.42:
				# Flaked paint: the bare, weathered wood shows, streaked along the grain.
				c = c.lerp(bare * (0.85 + 0.25 * g), clampf((w - 0.42) * 4.0, 0.0, 0.6))
			if seam < 2 or seam == 31:
				c *= 0.55
			elif seam == 2:
				c *= 0.85
			# Now and then a knot in the board.
			var kx := float((x + plank * 53) % 64) - 32.0
			var ky := float(seam) - 16.0
			if (kx * kx + ky * ky * 3.0) < 14.0 and plank % 2 == 0:
				c *= 0.62
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	_tex[key] = _image_texture(img)
	return _tex[key]


## Coiled straw: rows of rope as thick as a hand, stalk streaks along each, and a band of twine stitching
## across every fourth coil.
static func straw_texture() -> ImageTexture:
	if _tex.has("straw"):
		return _tex["straw"]
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var fibre := _noise(31, 0.5)
	var patches := _noise(37, 0.04, 2)
	var light := Color(0.86, 0.7, 0.34)
	var dark := Color(0.55, 0.4, 0.17)
	var twine := Color(0.33, 0.22, 0.12)
	for y in size:
		for x in size:
			var row := y / 16
			var t := float(y % 16) / 16.0
			var roll := pow(sin(PI * t), 0.55)
			var f := fibre.get_noise_2d(x * 0.9, y * 0.12 + row * 9.0)
			var c := dark.lerp(light, clampf(roll * 0.85 + f * 0.25, 0.0, 1.0))
			c *= 0.9 + 0.2 * patches.get_noise_2d(x, y)
			# The twine: a slanting stitch every few hand widths along every fourth coil.
			if row % 4 == 1 and t > 0.25 and t < 0.75 and int(x + y * 2) % 21 < 5:
				c = twine.lerp(c, 0.25 + 0.2 * f)
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	_tex["straw"] = _image_texture(img)
	return _tex["straw"]


## Ribbed zinc sheet, streaked where the rain runs off it and mossy in the damp corners.
static func zinc_texture() -> ImageTexture:
	if _tex.has("zinc"):
		return _tex["zinc"]
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var streak := _noise(41, 0.06)
	var moss := _noise(43, 0.05, 2)
	for y in size:
		for x in size:
			var rib := 0.5 + 0.5 * sin(x * TAU / 16.0)
			var c := Color(0.52, 0.55, 0.57) * (0.82 + 0.22 * rib)
			var s := streak.get_noise_2d(x * 2.0, y * 0.1)
			c *= 0.88 + 0.16 * s
			var m := moss.get_noise_2d(x, y)
			if m > 0.25:
				c = c.lerp(Color(0.32, 0.42, 0.22), clampf((m - 0.25) * 2.4, 0.0, 0.75))
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	_tex["zinc"] = _image_texture(img)
	return _tex["zinc"]


## A rough grey stone with lichen.
static func stone_texture() -> ImageTexture:
	if _tex.has("stone"):
		return _tex["stone"]
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var rough := _noise(51, 0.12, 4)
	var lichen := _noise(53, 0.07)
	for y in size:
		for x in size:
			var c := Color(0.62, 0.6, 0.56) * (0.8 + 0.3 * rough.get_noise_2d(x, y))
			if lichen.get_noise_2d(x, y) > 0.3:
				c = c.lerp(Color(0.62, 0.66, 0.4), 0.5)
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	_tex["stone"] = _image_texture(img)
	return _tex["stone"]


## Bee fur: yellow and black bands along the u axis of the abdomen, fuzz in both.
static func bee_texture() -> ImageTexture:
	if _tex.has("bee"):
		return _tex["bee"]
	var size := 32
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var fuzz := _noise(61, 0.7, 2)
	for y in size:
		for x in size:
			var band := int(x / 4) % 2
			var c := Color(0.95, 0.72, 0.1) if band == 0 else Color(0.09, 0.07, 0.05)
			c *= 0.88 + 0.24 * (0.5 + 0.5 * fuzz.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	_tex["bee"] = _image_texture(img)
	return _tex["bee"]


## The fur of the thorax: soft brown and gold with fuzz.
static func fur_texture() -> ImageTexture:
	if _tex.has("fur"):
		return _tex["fur"]
	var size := 32
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var fuzz := _noise(67, 0.8, 2)
	for y in size:
		for x in size:
			var c := Color(0.62, 0.42, 0.12).lerp(Color(0.86, 0.62, 0.2), 0.5 + 0.5 * fuzz.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	_tex["fur"] = _image_texture(img)
	return _tex["fur"]


# --- Materials --------------------------------------------------------------------------

static func _material(key: String, texture: Texture2D, tint := Color.WHITE, scale := 1.5, rough := 0.9) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


static func wood_material(paint: Color) -> StandardMaterial3D:
	return _material("wood_" + paint.to_html(), wood_texture(paint), Color.WHITE, 1.6)


static func raw_wood_material() -> StandardMaterial3D:
	return _material("raw", wood_texture(Color(0.55, 0.42, 0.28)), Color(0.92, 0.86, 0.8), 2.0)


static func dark_wood_material() -> StandardMaterial3D:
	return _material("dark", wood_texture(Color(0.3, 0.22, 0.15)), Color.WHITE, 2.0)


static func zinc_material() -> StandardMaterial3D:
	return _material("zinc", zinc_texture(), Color.WHITE, 1.8, 0.55)


static func stone_material() -> StandardMaterial3D:
	return _material("stone", stone_texture(), Color.WHITE, 3.0)


## Plain straw: not triplanar, the coil texture follows the bell's own uv (see _dome).
static func straw_material() -> StandardMaterial3D:
	if _mats.has("straw"):
		return _mats["straw"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = straw_texture()
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats["straw"] = m
	return m


static func _dark_material() -> StandardMaterial3D:
	if _mats.has("hole"):
		return _mats["hole"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.03, 0.025)
	m.roughness = 1.0
	_mats["hole"] = m
	return m


# --- Pieces -----------------------------------------------------------------------------

static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, turn := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = turn
	parent.add_child(mi)
	return mi


static func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, top_radius := -1.0, sides := 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## A bell: the surface of revolution of a rounded profile, bulged a little by every coil, with the uv running
## round the bell (three times, to match the straw's width) and up it, one texture row per coil.
static func _dome(height: float, radius: float, rings: int, segs: int, coils: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var t := float(i) / rings
		var y := t * height
		var r := radius * pow(maxf(1.0 - pow(t, 2.3), 0.0), 0.5)
		# Each coil is a rope laid on the last: round on top, a pinch between.
		r *= 1.0 + 0.03 * sin(t * coils * TAU - PI * 0.5) - 0.012
		for j in segs + 1:
			var a := TAU * j / segs
			st.set_uv(Vector2(float(j) / segs * 3.0, 1.0 - t * coils / 8.0))
			st.add_vertex(Vector3(cos(a) * r, y, sin(a) * r))
	for i in rings:
		for j in segs:
			var a := i * (segs + 1) + j
			var b := a + segs + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	st.generate_normals()
	return st.commit()


## The radius of the skep at a height, for the entrance (see skep).
static func skep_radius_at(y: float) -> float:
	var t := clampf(y / SKEP_HEIGHT, 0.0, 1.0)
	var r := SKEP_RADIUS * pow(maxf(1.0 - pow(t, 2.3), 0.0), 0.5)
	return r * (1.0 + 0.03 * sin(t * SKEP_COILS * TAU - PI * 0.5) - 0.012)


## A straw skep on its stand, its entrance towards +z.
static func skep() -> Node3D:
	var root := Node3D.new()
	root.name = "Skep"
	var wood := raw_wood_material()
	# The stand: four splayed legs and a round board.
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var leg := _box(root, Vector3(0.06, 0.34, 0.06), Vector3(cos(a) * 0.3, 0.17, sin(a) * 0.3), wood, Vector3(sin(a) * 0.09, 0, -cos(a) * 0.09))
		leg.name = "Leg%d" % k
	_cylinder(root, 0.5, 0.045, Vector3(0, 0.36, 0), wood, 0.49, 24).name = "Board"
	var bell := MeshInstance3D.new()
	bell.name = "Bell"
	bell.mesh = _dome(SKEP_HEIGHT, SKEP_RADIUS, 48, 40, SKEP_COILS)
	bell.material_override = straw_material()
	bell.position = Vector3(0, 0.385, 0)
	root.add_child(bell)
	# The knob at the top: a twisted plug of straw.
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.09
	knob.mesh = sphere
	knob.material_override = straw_material()
	knob.position = Vector3(0, 0.385 + SKEP_HEIGHT - 0.02, 0)
	knob.name = "Knob"
	root.add_child(knob)
	# A flat stone on top keeps the lid on in the wind.
	var stone := _cylinder(root, 0.09, 0.05, Vector3(0.0, 0.385 + SKEP_HEIGHT + 0.03, 0), stone_material(), 0.07, 9)
	stone.name = "Stone"
	stone.rotation.y = 0.4
	# The entrance: a low dark arch at the foot, with a worn lip of board before it.
	var hole := MeshInstance3D.new()
	hole.name = "Entrance"
	var arch := _arch(0.2, 0.15)
	hole.mesh = arch
	hole.material_override = _dark_material()
	hole.position = Vector3(0, 0.385, skep_radius_at(0.05) + 0.045)
	root.add_child(hole)
	return root


## A flat arch (a half disc on its chord), facing +z.
static func _arch(width: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	for i in steps:
		var a0 := PI * i / steps
		var a1 := PI * (i + 1) / steps
		var p0 := Vector3(cos(a0) * width * 0.5, sin(a0) * height, 0)
		var p1 := Vector3(cos(a1) * width * 0.5, sin(a1) * height, 0)
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.BACK)
		st.add_vertex(p0)
		st.set_normal(Vector3.BACK)
		st.add_vertex(p1)
	return st.commit()


## A painted box hive on its stand, its entrance towards +z. `number` picks the paint and the little
## differences between two hives.
static func box_hive(number := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "BoxHive"
	var paint: Color = PAINTS[posmod(number, PAINTS.size())]
	var painted := wood_material(paint)
	var trim := wood_material(paint.lerp(Color(1, 1, 1), 0.35))
	var raw := raw_wood_material()
	var w := 0.54
	var d := 0.44
	# The stand: four legs, and the bottom board with the landing board sloping down in front.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(root, Vector3(0.06, 0.3, 0.06), Vector3(sx * (w * 0.5 - 0.04), 0.15, sz * (d * 0.5 - 0.04)), raw)
	_box(root, Vector3(w - 0.04, 0.035, d - 0.02), Vector3(0, 0.3175, 0), raw).name = "BottomBoard"
	_box(root, Vector3(w - 0.08, 0.025, 0.2), Vector3(0, 0.27, d * 0.5 + 0.07), raw, Vector3(0.38, 0, 0)).name = "Landing"
	# Two brood boxes and a honey super (shallower), each with corner posts, a lip and hand slots.
	var heights := [0.26, 0.26, 0.17]
	var y := 0.335
	for b in heights.size():
		var h: float = heights[b]
		var shell := _box(root, Vector3(w, h, d), Vector3(0, y + h * 0.5, 0), painted)
		shell.name = "Box%d" % b
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(root, Vector3(0.028, h + 0.004, 0.028), Vector3(sx * (w * 0.5 - 0.004), y + h * 0.5, sz * (d * 0.5 - 0.004)), trim)
		# The lip where one box sits on the next.
		_box(root, Vector3(w + 0.012, 0.014, d + 0.012), Vector3(0, y + h - 0.007, 0), trim)
		# Hand slots in the two ends.
		for sx in [-1, 1]:
			_box(root, Vector3(0.012, 0.035, 0.16), Vector3(sx * (w * 0.5 + 0.001), y + h * 0.62, 0), _dark_material())
		y += h
	# The entrance: a slot along the foot of the lowest box, shaded by a short reducer block at one side.
	_box(root, Vector3(0.24, 0.022, 0.012), Vector3(0.0, 0.346, d * 0.5 + 0.002), _dark_material()).name = "Entrance"
	_box(root, Vector3(0.07, 0.024, 0.018), Vector3(-0.2, 0.347, d * 0.5 + 0.004), raw)
	# The lid: an inner cover, and the roof, a zinc gable with a stone against the wind.
	_box(root, Vector3(w + 0.03, 0.03, d + 0.03), Vector3(0, y + 0.015, 0), raw).name = "InnerCover"
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.16, 0.14, d + 0.14)
	prism.left_to_right = 0.5
	roof.mesh = prism
	roof.material_override = zinc_material()
	roof.position = Vector3(0, y + 0.03 + 0.07, 0)
	root.add_child(roof)
	_box(root, Vector3(w + 0.18, 0.012, 0.014), Vector3(0, y + 0.036, d * 0.5 + 0.07), dark_wood_material()).name = "RoofEdge"
	var stone := _cylinder(root, 0.07, 0.045, Vector3(0.1, y + 0.03 + 0.14, 0.0), stone_material(), 0.055, 8)
	stone.rotation = Vector3(0.0, 0.7, 0.18)
	return root


# --- Bees -------------------------------------------------------------------------------

## A bee, about six centimetres long (a little more than life, so one can be seen from the camera), flying
## towards -z. Its two wings are the children named WingL and WingR, turned by Apiary to beat.
static func bee() -> Node3D:
	var root := Node3D.new()
	root.name = "Bee"
	var fur := StandardMaterial3D.new()
	fur.albedo_texture = fur_texture()
	fur.roughness = 1.0
	var stripes := StandardMaterial3D.new()
	stripes.albedo_texture = bee_texture()
	stripes.roughness = 0.85
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.07, 0.06, 0.05)
	black.roughness = 0.8
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 1.0, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.2
	var body := func(r: float, scale: Vector3, at: Vector3, mat: Material, name: String) -> void:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		mi.mesh = sphere
		mi.scale = scale
		mi.position = at
		mi.material_override = mat
		mi.name = name
		root.add_child(mi)
	body.call(0.017, Vector3(1.0, 0.95, 1.1), Vector3(0, 0, 0), fur, "Thorax")
	body.call(0.016, Vector3(0.9, 0.85, 2.0), Vector3(0, -0.002, 0.036), stripes, "Abdomen")
	body.call(0.012, Vector3(1.0, 0.95, 0.9), Vector3(0, 0.001, -0.026), black, "Head")
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if side < 0.0 else "WingR"
		pivot.position = Vector3(side * 0.008, 0.014, -0.004)
		root.add_child(pivot)
		var wing := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.045, 0.02)
		quad.orientation = PlaneMesh.FACE_Y
		wing.mesh = quad
		wing.material_override = glass
		wing.position = Vector3(side * 0.024, 0, 0.004)
		wing.rotation.y = side * -0.35
		pivot.add_child(wing)
	return root


# --- Flowers ----------------------------------------------------------------------------

## The colours of the meadow's daisy-like flowers: white clover, buttercup, cornflower, poppy, pink campion.
const FLOWER_COLOURS := [Color(0.97, 0.96, 0.9), Color(0.98, 0.84, 0.15), Color(0.35, 0.5, 0.95), Color(0.9, 0.2, 0.15), Color(0.9, 0.5, 0.75)]
## The lavender's spike.
const LAVENDER := Color(0.55, 0.38, 0.8)


## One flower on its stem, 25 cm tall (a spike: 35), made of vertex-coloured triangles with a leaf texture for
## the grain: a stem, two leaves, a ring of petals in `petal` and a gold heart (or a spike of buds).
static func flower_mesh(petal: Color, spike := false) -> ArrayMesh:
	var key := "flower_%s_%s" % [petal.to_html(), spike]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var add_tri := func(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		var n := (b - a).cross(c - a).normalized()
		for p in [a, b, c]:
			verts.append(p)
			cols.append(col)
			norms.append(n)
			uvs.append(Vector2(p.x * 8.0, p.y * 4.0))
	var green := Color(0.34, 0.55, 0.22)
	var h := 0.35 if spike else 0.25
	# The stem, a thin blade facing two ways.
	for turn in [0.0, PI * 0.5]:
		var s := Vector3(cos(turn), 0, sin(turn)) * 0.006
		add_tri.call(-s, s, Vector3(0, h, 0) + s * 0.5, green)
		add_tri.call(-s, Vector3(0, h, 0) + s * 0.5, Vector3(0, h, 0) - s * 0.5, green)
	# Two leaves low on the stem.
	for turn in [0.4, 3.5]:
		var out := Vector3(cos(turn), 0, sin(turn))
		var side := out.cross(Vector3.UP) * 0.014
		add_tri.call(Vector3(0, 0.04, 0) - side, Vector3(0, 0.04, 0) + side, out * 0.07 + Vector3(0, 0.1, 0), green * 0.92)
	if spike:
		# A tapering spike of buds in rings.
		for k in 6:
			var y := h - 0.14 + k * 0.026
			var r := 0.022 - k * 0.002
			for j in 5:
				var a := TAU * j / 5.0 + k * 0.6
				var p := Vector3(cos(a) * r, y, sin(a) * r)
				add_tri.call(Vector3(0, y - 0.012, 0), p, Vector3(0, y + 0.016, 0), petal * (0.85 + 0.05 * k))
	else:
		# A ring of eight petals leaning up from the heart, and the heart.
		var top := Vector3(0, h, 0)
		for j in 8:
			var a := TAU * j / 8.0
			var a2 := a + TAU / 8.0 * 0.45
			var a1 := a - TAU / 8.0 * 0.45
			var tip := top + Vector3(cos(a) * 0.055, 0.018, sin(a) * 0.055)
			add_tri.call(top, top + Vector3(cos(a1) * 0.02, 0.004, sin(a1) * 0.02) + Vector3(cos(a1), 0, sin(a1)) * 0.02, tip, petal)
			add_tri.call(top, tip, top + Vector3(cos(a2) * 0.02, 0.004, sin(a2) * 0.02) + Vector3(cos(a2), 0, sin(a2)) * 0.02, petal * 0.94)
		for j in 6:
			var a := TAU * j / 6.0
			var b := TAU * (j + 1) / 6.0
			add_tri.call(top + Vector3(0, 0.012, 0), top + Vector3(cos(a) * 0.017, 0.004, sin(a) * 0.017), top + Vector3(cos(b) * 0.017, 0.004, sin(b) * 0.017), Color(0.95, 0.7, 0.1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = CropFields._leaf_texture_cached()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	_meshes[key] = mesh
	return mesh


## The height of a flower's head above the ground (metres, before it is scaled).
static func flower_head(spike := false) -> float:
	return 0.35 if spike else 0.25
