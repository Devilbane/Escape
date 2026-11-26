class_name FrogModel
extends RefCounted
## The look of a pond frog (see PondFrogs): a green frog built from smooth ellipsoids, about a metre long in
## its own units (the node scales it down to a hand's length). The meshes are built once and shared by all
## frogs:
##
## * body_mesh: skin surface (body, head, snout, dorsal folds, front legs, ear discs, mouth line) and an eye
##   surface (gold eyes with a black bar pupil and a glossy shine),
## * leg_mesh: one folded hind leg with its long webbed foot, for the left (+1) or the right (-1) side, hanging
##   from its own hip so the legs can kick while the frog swims,
## * sac_mesh: the vocal sac under the chin, which swells and shrinks while the frog croaks.
##
## The skin is a seamless mottled texture (see skin_material) mapped triplanar in the model's own space, so
## it runs on over the joins between the parts, with a bump map for the warty skin; the colour (green back,
## cream belly) is in the vertices, and each frog takes one of the VARIANTS tints.

## Skin tints, multiplied over the vertex colours: pond green, olive-brown and a bright leaf green.
const VARIANTS := [Color(1.0, 1.0, 1.0), Color(0.86, 0.8, 0.52), Color(0.82, 1.08, 0.7)]
const BACK := Color(0.34, 0.5, 0.17)
const BACK_DARK := Color(0.24, 0.36, 0.12)
const BELLY := Color(0.86, 0.84, 0.62)
const FOLD := Color(0.62, 0.66, 0.34)
const MOUTH := Color(0.12, 0.1, 0.06)
const EAR := Color(0.5, 0.52, 0.26)
const GOLD := Color(0.86, 0.62, 0.12)
const SAC := Color(0.88, 0.84, 0.56)
const TEX_SIZE := 160

static var _skin := {}
static var _eye_mat: StandardMaterial3D
static var _body: ArrayMesh
static var _legs := {}
static var _sac: ArrayMesh


## The skin of tint `variant` (an index into VARIANTS), one material per tint, shared by all frogs.
static func skin_material(variant: int) -> StandardMaterial3D:
	variant = clampi(variant, 0, VARIANTS.size() - 1)
	if not _skin.has(variant):
		var tex := _skin_textures()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		m.albedo_color = VARIANTS[variant]
		m.albedo_texture = tex[0]
		m.normal_enabled = true
		m.normal_texture = tex[1]
		m.normal_scale = 0.9
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(2.2, 2.2, 2.2)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Wet skin: a glossy sheen over the matt mottling.
		m.roughness = 0.38
		m.metallic_specular = 0.7
		_skin[variant] = m
	return _skin[variant]


## The gold, glossy eyes.
static func eye_material() -> StandardMaterial3D:
	if _eye_mat == null:
		_eye_mat = StandardMaterial3D.new()
		_eye_mat.vertex_color_use_as_albedo = true
		_eye_mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
		_eye_mat.roughness = 0.08
		_eye_mat.metallic_specular = 1.0
	return _eye_mat


## Seamless [albedo, normal map] of mottled skin: pale ground, dark blotches, fine speckle and warts. Grey
## values only, the colour comes from the vertices.
static func _skin_textures() -> Array:
	var broad := FastNoiseLite.new()
	broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad.frequency = 0.035
	broad.fractal_octaves = 3
	broad.seed = 11
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fine.frequency = 0.22
	fine.seed = 23
	var warts := FastNoiseLite.new()
	warts.noise_type = FastNoiseLite.TYPE_CELLULAR
	warts.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	warts.frequency = 0.09
	warts.seed = 5
	var b := broad.get_seamless_image(TEX_SIZE, TEX_SIZE, false, false, 0.2)
	var f := fine.get_seamless_image(TEX_SIZE, TEX_SIZE, false, false, 0.2)
	var w := warts.get_seamless_image(TEX_SIZE, TEX_SIZE, false, false, 0.2)
	var albedo := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_L8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var bv := b.get_pixel(x, y).r
			var fv := f.get_pixel(x, y).r
			var wv := w.get_pixel(x, y).r
			# Dark blotches where the broad noise is low, a paler ground elsewhere.
			var blotch := 1.0 - smoothstep(0.38, 0.58, bv)
			var v := 0.92 - blotch * 0.5 + (fv - 0.5) * 0.22
			# Each wart is a slightly paler dome with a darker rim.
			var dome := 1.0 - smoothstep(0.0, 0.5, wv)
			v += dome * 0.1 - smoothstep(0.5, 0.7, wv) * 0.04
			v = clampf(v, 0.18, 1.0)
			albedo.set_pixel(x, y, Color(v, v * 0.98, v * 0.92))
			height.set_pixel(x, y, Color(clampf(dome * 0.8 + (fv - 0.5) * 0.3 + 0.2, 0.0, 1.0), 0, 0))
	albedo.generate_mipmaps()
	height.bump_map_to_normal_map(5.0)
	height.generate_mipmaps()
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(height)]


## The body, head, front legs and eyes: surface 0 is skin (see skin_material), surface 1 the eyes.
static func body_mesh() -> ArrayMesh:
	if _body != null:
		return _body
	var skin := _Blobs.new()
	var eyes := _Blobs.new()
	# Body, a little tilted: rump up, chest down.
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-9.0))
	skin.blob(Vector3(0, 0.27, -0.1), Vector3(0.31, 0.25, 0.42), tilt, BACK, BELLY)
	# A pale chest under the chin and a saddle of darker back.
	skin.blob(Vector3(0, 0.38, -0.12), Vector3(0.24, 0.16, 0.3), tilt, BACK_DARK, BACK)
	# The head, flat and wide, with the snout in front of it.
	skin.blob(Vector3(0, 0.33, 0.36), Vector3(0.27, 0.15, 0.25), Basis.IDENTITY, BACK, BELLY)
	skin.blob(Vector3(0, 0.3, 0.53), Vector3(0.18, 0.1, 0.17), Basis.IDENTITY, BACK, BELLY)
	# Nostrils.
	for sx in [-1.0, 1.0]:
		skin.blob(Vector3(sx * 0.055, 0.35, 0.68), Vector3(0.016, 0.01, 0.016), Basis.IDENTITY, MOUTH, MOUTH, 6, 8)
	# The mouth line along each side of the jaw.
	for sx in [-1.0, 1.0]:
		skin.blob(Vector3(sx * 0.158, 0.29, 0.5), Vector3(0.01, 0.008, 0.12), Basis(Vector3.UP, sx * 0.3), MOUTH, MOUTH, 6, 10)
	# The two pale folds that run from the eyes along the back.
	for sx in [-1.0, 1.0]:
		skin.blob(Vector3(sx * 0.15, 0.455, -0.02), Vector3(0.022, 0.02, 0.3), Basis(Vector3.UP, -sx * 0.06) * tilt, FOLD, FOLD, 8, 12)
	# The round ear discs behind the eyes.
	for sx in [-1.0, 1.0]:
		skin.blob(Vector3(sx * 0.255, 0.37, 0.2), Vector3(0.022, 0.065, 0.065), Basis.IDENTITY, EAR, EAR, 8, 12)
	# Eye sockets that bulge from the head, and the eyes themselves.
	for sx in [-1.0, 1.0]:
		skin.blob(Vector3(sx * 0.15, 0.47, 0.32), Vector3(0.1, 0.085, 0.1), Basis.IDENTITY, BACK, BACK_DARK)
		var globe := Vector3(sx * 0.16, 0.5, 0.35)
		eyes.blob(globe, Vector3(0.062, 0.062, 0.062), Basis.IDENTITY, GOLD, GOLD * 0.8)
		# The black bar pupil on the front of the eye.
		var look := Vector3(sx * 0.45, 0.12, 0.88).normalized()
		eyes.blob(globe + look * 0.053, Vector3(0.034, 0.013, 0.013), _facing(look, Vector3.UP, Vector3.RIGHT), Color(0.02, 0.02, 0.02), Color(0.02, 0.02, 0.02), 8, 12)
	# Front legs: upper arm, forearm, hand with four short fingers.
	for sx in [-1.0, 1.0]:
		skin.segment(Vector3(sx * 0.2, 0.3, 0.2), Vector3(sx * 0.26, 0.14, 0.27), 0.062, BACK, BACK_DARK)
		skin.segment(Vector3(sx * 0.26, 0.14, 0.27), Vector3(sx * 0.2, 0.03, 0.42), 0.048, BACK, BELLY)
		skin.blob(Vector3(sx * 0.2, 0.022, 0.46), Vector3(0.07, 0.022, 0.06), Basis.IDENTITY, BACK, BELLY, 8, 12)
		for k in 4:
			var spread := (k - 1.5) * 0.045
			skin.segment(Vector3(sx * 0.2 + spread * 0.5, 0.02, 0.48), Vector3(sx * 0.2 + spread * 1.5, 0.014, 0.57), 0.013, BELLY, BELLY, 6, 8)
	_body = ArrayMesh.new()
	skin.commit(_body)
	eyes.commit(_body)
	_body.surface_set_material(0, skin_material(0))
	_body.surface_set_material(1, eye_material())
	return _body


## One folded hind leg hanging from the hip at the origin: thigh forward, shin back, then the long foot with
## its webbed toes. `side` is +1 for the frog's left (+x) and -1 for its right.
static func leg_mesh(side: int) -> ArrayMesh:
	if _legs.has(side):
		return _legs[side]
	var b := _Blobs.new()
	var sx := float(side)
	var knee := Vector3(sx * 0.17, -0.07, 0.4)
	var ankle := Vector3(sx * 0.2, -0.17, -0.03)
	var foot := Vector3(sx * 0.3, -0.19, 0.4)
	b.blob(Vector3.ZERO, Vector3(0.12, 0.12, 0.13), Basis.IDENTITY, BACK, BACK_DARK)
	b.segment(Vector3.ZERO, knee, 0.115, BACK, BACK_DARK)
	b.segment(knee, ankle, 0.06, BACK, BELLY)
	b.segment(ankle, foot, 0.04, BACK, BELLY)
	# Five long toes, fanned, with a web of skin between them.
	for k in 5:
		var fan := (k - 2.0) * 0.5
		var tip := foot + Vector3(sx * sin(fan) * 0.15, -0.015, cos(fan) * 0.19)
		b.segment(foot, tip, 0.016, BELLY, BELLY, 6, 8)
	b.blob(foot + Vector3(sx * 0.02, -0.022, 0.13), Vector3(0.11, 0.008, 0.1), Basis.IDENTITY, FOLD, FOLD, 6, 14)
	_legs[side] = ArrayMesh.new()
	b.commit(_legs[side])
	_legs[side].surface_set_material(0, skin_material(0))
	return _legs[side]


## The vocal sac: a pale, glossy bubble under the chin (hidden inside the head until it swells).
static func sac_mesh() -> ArrayMesh:
	if _sac == null:
		var b := _Blobs.new()
		b.blob(Vector3(0, 0.0, 0.0), Vector3(0.2, 0.15, 0.2), Basis.IDENTITY, SAC, SAC * 0.9, 16, 22)
		_sac = ArrayMesh.new()
		b.commit(_sac)
		_sac.surface_set_material(0, skin_material(0))
	return _sac


## A basis whose z axis looks along `dir`, its x axis along `right` as far as it can.
static func _facing(dir: Vector3, up: Vector3, right: Vector3) -> Basis:
	var z := dir.normalized()
	var x := up.cross(z)
	if x.length() < 0.01:
		x = right
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## Collects ellipsoids into one indexed triangle list with per-vertex colours.
class _Blobs:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	## An ellipsoid of radii `r` at `c`, turned by `basis`. Its colour runs from `top` to `bottom` over the
	## underside.
	func blob(c: Vector3, r: Vector3, basis: Basis, top: Color, bottom: Color, rings := 14, segs := 22) -> void:
		var first := verts.size()
		for i in rings + 1:
			var theta := PI * float(i) / rings
			for j in segs + 1:
				var phi := TAU * float(j) / segs
				var u := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
				verts.append(c + basis * (u * r))
				normals.append((basis * Vector3(u.x / r.x, u.y / r.y, u.z / r.z)).normalized())
				colours.append(top.lerp(bottom, smoothstep(-0.1, -0.7, u.y)))
				uvs.append(Vector2(float(j) / segs, float(i) / rings))
		for i in rings:
			for j in segs:
				var a := first + i * (segs + 1) + j
				var bb := a + 1
				var cc := a + segs + 1
				var dd := cc + 1
				indices.append_array([a, bb, cc, bb, dd, cc])

	## A tapered ellipsoid lying from `a` to `b`, `radius` thick.
	func segment(a: Vector3, b: Vector3, radius: float, top: Color, bottom: Color, rings := 10, segs := 14) -> void:
		var d := b - a
		var basis := FrogModel._facing(d, Vector3.UP, Vector3.RIGHT)
		blob((a + b) * 0.5, Vector3(radius, radius * 0.92, d.length() * 0.58), basis, top, bottom, rings, segs)

	func commit(mesh: ArrayMesh) -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
