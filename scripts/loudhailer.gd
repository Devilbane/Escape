class_name Loudhailer
extends RefCounted
## The herald's loudhailer: a brass speaking horn, a long cone flaring from a small mouthpiece to a wide bell,
## with a beaded rim, two engraved bands and a leather-wrapped grip under it. Built along +z (the mouthpiece at
## z 0, the bell at z LENGTH), about the size of a forearm and a half. The brass is brushed along its length
## and tarnished in patches (a generated texture).

const LENGTH := 0.62
const MOUTH_R := 0.034
const BELL_R := 0.2
const SIDES := 24
const RINGS := 20
const BRASS := Color(0.92, 0.7, 0.26)
const LEATHER := Color(0.34, 0.2, 0.1)

static var _mesh: ArrayMesh
static var _grip: ArrayMesh
static var _brass_texture: ImageTexture


## The radius of the horn at `t` (0 at the mouthpiece, 1 at the bell): a narrow throat that flares late.
static func radius(t: float) -> float:
	return MOUTH_R + (BELL_R - MOUTH_R) * pow(t, 2.3)


## The finished node: the horn and its grip, the mouthpiece at the node's origin, the bell towards +z.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Loudhailer"
	var horn := MeshInstance3D.new()
	horn.name = "Horn"
	horn.mesh = mesh()
	root.add_child(horn)
	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	grip.mesh = grip_mesh()
	root.add_child(grip)
	return root


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	# The mouthpiece cup: a short, wider ring before the throat.
	_lathe(st, [[-0.05, 0.05], [-0.045, 0.058], [-0.02, 0.05], [0.0, 0.036]], Color(0.96, 0.8, 0.34), 0.0, 0.1)
	# The horn itself, in rings from the throat to the bell.
	var profile := []
	for k in RINGS + 1:
		var t := float(k) / RINGS
		profile.append([LENGTH * t, radius(t)])
	_lathe(st, profile, BRASS * 1.1, 0.1, 1.0)
	# The bands: slightly fatter rings in a darker brass, and the rolled rim of the bell.
	for band in [0.32, 0.62]:
		_lathe(st, [[LENGTH * band - 0.012, radius(band - 0.02) + 0.004], [LENGTH * band - 0.006, radius(band) + 0.014],
				[LENGTH * band + 0.006, radius(band) + 0.014], [LENGTH * band + 0.012, radius(band + 0.02) + 0.004]],
				BRASS * 0.72, 0.1, 0.14)
	_lathe(st, [[LENGTH - 0.02, BELL_R - 0.006], [LENGTH - 0.004, BELL_R + 0.018], [LENGTH + 0.012, BELL_R + 0.012], [LENGTH + 0.018, BELL_R - 0.012]],
			Color(0.97, 0.78, 0.32), 0.1, 0.14)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = brass_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.metallic = 0.25
	mat.metallic_specular = 0.8
	mat.roughness = 0.42
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


## A surface of revolution about the z axis through (z, r) points, each with its own colour pass;
## v runs from `v0` to `v1` along it.
static func _lathe(st: SurfaceTool, points: Array, colour: Color, v0: float, v1: float) -> void:
	st.set_color(colour)
	for k in points.size() - 1:
		var a: Array = points[k]
		var b: Array = points[k + 1]
		var va := lerpf(v0, v1, float(k) / (points.size() - 1))
		var vb := lerpf(v0, v1, float(k + 1) / (points.size() - 1))
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			var p00 := Vector3(cos(a0) * a[1], sin(a0) * a[1], a[0])
			var p10 := Vector3(cos(a1) * a[1], sin(a1) * a[1], a[0])
			var p01 := Vector3(cos(a0) * b[1], sin(a0) * b[1], b[0])
			var p11 := Vector3(cos(a1) * b[1], sin(a1) * b[1], b[0])
			var u0 := float(i) / SIDES
			var u1 := float(i + 1) / SIDES
			var n00 := Vector3(cos(a0), sin(a0), 0)
			var n10 := Vector3(cos(a1), sin(a1), 0)
			for q in [[p00, u0, va, n00], [p10, u1, va, n10], [p11, u1, vb, n10], [p00, u0, va, n00], [p11, u1, vb, n10], [p01, u0, vb, n00]]:
				st.set_uv(Vector2(q[1], q[2]))
				st.set_normal(q[3])
				st.add_vertex(q[0])


## The grip: a leather-wrapped handle under the horn at a third of its length, with a brass collar and cap.
static func grip_mesh() -> ArrayMesh:
	if _grip != null:
		return _grip
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := LENGTH * 0.38
	var top := -radius(0.38) + 0.01
	var sides := 12
	var steps := [[0.0, 0.038], [-0.02, 0.03], [-0.06, 0.03], [-0.1, 0.033], [-0.13, 0.03], [-0.16, 0.036]]
	for k in steps.size() - 1:
		var y0: float = top + steps[k][0]
		var y1: float = top + steps[k + 1][0]
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var colour: Color = BRASS * 0.9 if k == 0 or k == steps.size() - 2 else LEATHER * (1.15 if k % 2 == 0 else 0.9)
			st.set_color(colour)
			var r0: float = steps[k][1]
			var r1: float = steps[k + 1][1]
			var pts := [Vector3(cos(a0) * r0, y0, z + sin(a0) * r0), Vector3(cos(a1) * r0, y0, z + sin(a1) * r0),
					Vector3(cos(a1) * r1, y1, z + sin(a1) * r1), Vector3(cos(a0) * r0, y0, z + sin(a0) * r0),
					Vector3(cos(a1) * r1, y1, z + sin(a1) * r1), Vector3(cos(a0) * r1, y1, z + sin(a0) * r1)]
			for p: Vector3 in pts:
				st.set_uv(Vector2((p.x + p.z) * 8.0, p.y * 20.0))
				st.add_vertex(p)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_texture = brass_texture()
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_grip = st.commit()
	return _grip


## Brass brushed along its length (u across, v along), with greener tarnish in patches and a few scratches.
static func brass_texture() -> ImageTexture:
	if _brass_texture != null:
		return _brass_texture
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var brush := FastNoiseLite.new()
	brush.seed = 61
	brush.frequency = 0.9
	var patches := FastNoiseLite.new()
	patches.seed = 62
	patches.frequency = 0.045
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	for y in size:
		for x in size:
			# Brushing: noise that changes fast across the horn and slowly along it.
			var streak := brush.get_noise_2d(x * 3.0, y * 0.2) * 0.5 + 0.5
			var tarnish := clampf(patches.get_noise_2d(x, y) * 1.6 - 0.35, 0.0, 1.0)
			var v := 0.82 + 0.2 * streak
			var col := Color(v, v * 0.94, v * 0.8).lerp(Color(0.55, 0.62, 0.48) * v, tarnish * 0.5)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	for i in 18:
		var x := rng.randi_range(0, size - 1)
		var y := rng.randi_range(0, size - 1)
		for s in rng.randi_range(6, 20):
			var px := posmod(x + int(s * 0.3), size)
			var py := posmod(y + s, size)
			img.set_pixel(px, py, img.get_pixel(px, py).lightened(0.3))
	img.generate_mipmaps()
	_brass_texture = ImageTexture.create_from_image(img)
	return _brass_texture
