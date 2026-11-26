class_name BarberTent
extends RefCounted
## Benno's tent, built by hand: four round, slightly crooked poles of raw timber with rafters meeting
## over the chair, and a linen roof that sags between the poles, hangs in soft folds, has an uneven
## hem and a scalloped valance. Nothing in it is solid: one walks in under it (see BarberChair).

## Half the width between the poles, and the height of their tops.
const POLE_AT := 1.9
const POLE_TOP := 3.1
## The roof: its reach to the hem along an axis, its height at the poles, and how far it peaks above them.
const REACH := 2.45
const EAVE := 3.2
const PEAK := 1.7
const GRID := 44
const LINEN := Color(0.98, 0.92, 0.78)
const TIMBER := Color(0.55, 0.4, 0.27)
const ROPE := Color(0.62, 0.5, 0.33)

static var _cloth: StandardMaterial3D
static var _bark: StandardMaterial3D
static var _rope: StandardMaterial3D


## The whole tent, its middle at the origin of the node.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BarberTent"
	var peak := Vector3(0, EAVE + PEAK - 0.4, 0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var seed := int(sx * 3 + sz * 7 + 20)
			var foot := Vector3(sx * POLE_AT, 0, sz * POLE_AT)
			var top := Vector3(sx * POLE_AT, POLE_TOP, sz * POLE_AT)
			_add(root, pole(POLE_TOP, 0.105, 0.075, seed), bark(), foot)
			_cap(root, top, 0.085)
			_lash(root, top + Vector3(0, -0.22, 0), 0.095)
			# A rafter from the pole's top up to the peak, round like the poles.
			var run := peak - top
			var rafter := _add(root, pole(run.length(), 0.065, 0.05, seed + 11), bark(), top)
			rafter.basis = Basis(Quaternion(Vector3.UP, run.normalized()))
	_cap(root, peak, 0.09)
	_lash(root, peak - Vector3(0, 0.2, 0), 0.07)
	var cloth := _add(root, roof(), cloth_material(), Vector3.ZERO)
	cloth.name = "BarberRoof"
	return root


static func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func _cap(parent: Node3D, at: Vector3, r: float) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	_add(parent, s, bark(), at)


## A turn of rope round a pole: a thick, rough ring.
static func _lash(parent: Node3D, at: Vector3, r: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r
	t.outer_radius = r + 0.05
	t.rings = 14
	t.ring_segments = 6
	_add(parent, t, rope(), at)
	_add(parent, t, rope(), at + Vector3(0, -0.07, 0)).rotation.x = 0.08


# --- Timber ------------------------------------------------------------------------------------------

## A round pole along +y, `length` long, thick at its foot and thin at its top, a little crooked and
## lumpy like a trimmed young trunk. UVs wind round it (u) and run up it (v) so the bark runs lengthwise.
static func pole(length: float, r0: float, r1: float, seed: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rings := 14
	var segs := 14
	var grid: Array = []
	var phase := float(seed % 7)
	for i in rings + 1:
		var t := float(i) / rings
		var y := length * t
		var bend := Vector3(sin(t * 2.2 + phase) * 0.025, 0, cos(t * 1.7 + phase) * 0.025) * length * 0.3
		var base_r := lerpf(r0, r1, t) * (1.0 + 0.1 * noise.get_noise_1d(t * length * 2.0))
		var row: Array = []
		for j in segs + 1:
			var a := TAU * j / segs
			var bump := 1.0 + 0.06 * noise.get_noise_2d(cos(a) * 3.0 + t * 4.0, sin(a) * 3.0 + t * length * 2.0)
			var r := base_r * bump
			row.append([Vector3(cos(a) * r, y, sin(a) * r) + bend, Vector2(float(j) / segs * 2.0, t * length * 0.7)])
		grid.append(row)
	for i in rings:
		for j in segs:
			var q: Array = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_uv(q[k][1])
				st.add_vertex(q[k][0])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Raw timber: long, uneven streaks of darker bark over the brown, cracks and a rough surface.
static func bark() -> StandardMaterial3D:
	if _bark != null:
		return _bark
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_CELLULAR
	fine.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	fine.frequency = 0.05
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.42, 0.34, 0.27))
	ramp.set_color(1, Color(1.0, 0.95, 0.88))
	var albedo := NoiseTexture2D.new()
	albedo.width = 128
	albedo.height = 512
	albedo.seamless = true
	albedo.noise = noise
	albedo.color_ramp = ramp
	var bumps := NoiseTexture2D.new()
	bumps.width = 128
	bumps.height = 512
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 9.0
	bumps.noise = fine
	var m := StandardMaterial3D.new()
	m.albedo_color = TIMBER
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = bumps
	m.normal_scale = 1.2
	m.roughness = 0.95
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	_bark = m
	return m


static func rope() -> StandardMaterial3D:
	if _rope == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = ROPE
		m.roughness = 1.0
		_rope = m
	return _rope


# --- Linen -------------------------------------------------------------------------------------------

## Coarse linen: a visible weave of uneven threads (slubs), soft mottling, a rough surface, lit from
## behind a little so the cloth glows where the sun comes through it.
static func cloth_material() -> StandardMaterial3D:
	if _cloth != null:
		return _cloth
	var slub := FastNoiseLite.new()
	slub.noise_type = FastNoiseLite.TYPE_PERLIN
	slub.frequency = 0.35
	slub.fractal_octaves = 3
	var mottle := FastNoiseLite.new()
	mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mottle.frequency = 0.012
	mottle.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.74, 0.69, 0.58))
	ramp.set_color(1, Color(1.0, 0.99, 0.95))
	var albedo := NoiseTexture2D.new()
	albedo.width = 256
	albedo.height = 256
	albedo.seamless = true
	albedo.noise = mottle
	albedo.color_ramp = ramp
	var weave := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var warp: Array = []
	for i in 128:
		warp.append(rng.randf_range(0.82, 1.0))
	var weft: Array = []
	for i in 128:
		weft.append(rng.randf_range(0.82, 1.0))
	for y in 128:
		for x in 128:
			var over := (x / 2 + y / 2) % 2 == 0
			var h: float = (warp[x] if over else weft[y]) * (0.9 + 0.1 * sin(float(x if over else y) * PI))
			weave.set_pixel(x, y, Color(h, h, h))
	var weave_tex := ImageTexture.create_from_image(weave)
	var bumps := NoiseTexture2D.new()
	bumps.width = 256
	bumps.height = 256
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 6.0
	bumps.noise = slub
	var m := StandardMaterial3D.new()
	m.albedo_color = LINEN
	m.albedo_texture = albedo
	m.detail_enabled = true
	m.detail_albedo = weave_tex
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	m.normal_enabled = true
	m.normal_texture = bumps
	m.normal_scale = 0.9
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(0.35, 0.3, 0.2)
	m.uv1_scale = Vector3(2.0, 2.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cloth = m
	return m


## The roof cloth: a rounded pyramid over the poles that sags between them, with soft folds running
## down from the peak, an uneven hem and a scalloped valance hanging from the hem.
static func roof() -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.55
	n.fractal_octaves = 3
	var pts: Array = []
	var uvs: Array = []
	for i in GRID + 1:
		var row: Array = []
		var urow: Array = []
		for j in GRID + 1:
			var x := lerpf(-1.0, 1.0, float(i) / GRID)
			var z := lerpf(-1.0, 1.0, float(j) / GRID)
			row.append(_roof_point(x, z, n))
			urow.append(Vector2(x * REACH, z * REACH))
		pts.append(row)
		uvs.append(urow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in GRID:
		for j in GRID:
			var corners := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uvs[corners[k][0]][corners[k][1]] * 0.5)
				st.add_vertex(pts[corners[k][0]][corners[k][1]])
	# The valance: a strip hanging from the grid's outer ring, its lower edge in scallops.
	var ring: Array = []
	for i in GRID:
		ring.append([i, 0])
	for j in GRID:
		ring.append([GRID, j])
	for i in GRID:
		ring.append([GRID - i, GRID])
	for j in GRID:
		ring.append([0, GRID - j])
	var count := ring.size()
	var drops: Array = []
	for k in count + 1:
		var wave := absf(sin(float(k) / count * TAU * 14.0 * 0.5))
		drops.append(0.2 + 0.14 * wave + 0.09 * n.get_noise_1d(float(k) * 1.7))
	for k in count:
		var a: Array = ring[k]
		var b: Array = ring[(k + 1) % count]
		var pa: Vector3 = pts[a[0]][a[1]]
		var pb: Vector3 = pts[b[0]][b[1]]
		var out_a := Vector3(pa.x, 0, pa.z).normalized() * 0.03
		var out_b := Vector3(pb.x, 0, pb.z).normalized() * 0.03
		var la := pa - Vector3(0, drops[k], 0) + out_a
		var lb := pb - Vector3(0, drops[k + 1], 0) + out_b
		var ua := Vector2(float(k) / count * 18.0, 0.0)
		var ub := Vector2(float(k + 1) / count * 18.0, 0.0)
		for q in [[pa, ua], [pb, ub], [lb, ub + Vector2(0, 0.35)], [pa, ua], [lb, ub + Vector2(0, 0.35)], [la, ua + Vector2(0, 0.35)]]:
			st.set_uv(q[1])
			st.add_vertex(q[0])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## One point of the roof for a grid position (x, z in -1..1).
static func _roof_point(x: float, z: float, n: FastNoiseLite) -> Vector3:
	var p := 3.0
	var r := pow(pow(absf(x), p) + pow(absf(z), p), 1.0 / p)
	var edge := clampf(r, 0.0, 1.0)
	var a := atan2(z, x)
	# The hem is not a clean square: its distance wanders, and it is rounder than the poles' square.
	var wander := 1.0 + 0.035 * n.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0) * pow(edge, 3.0)
	var sx := x * REACH * wander
	var sz := z * REACH * wander
	var t := 1.0 - edge
	var y := EAVE + PEAK * pow(t, 1.0)
	# Sag between the poles: most at the middle of each side, none at the corners.
	var around := absf(absf(x) - absf(z)) / maxf(absf(x) + absf(z), 0.001)
	y -= 0.28 * around * pow(edge, 3.0)
	# Soft folds running down from the peak, and a slow billow.
	y += 0.06 * sin(a * 9.0 + 2.5 * n.get_noise_2d(x * 2.0, z * 2.0)) * smoothstep(0.1, 0.8, edge) * (1.0 - 0.3 * edge)
	y += 0.14 * n.get_noise_2d(x * 1.6 + 9.0, z * 1.6 + 3.0) * edge
	return Vector3(sx, y, sz)
