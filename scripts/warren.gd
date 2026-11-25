class_name Warren
extends RefCounted
## A rabbit warren on a meadow: a burrow in the ground with a huddle of baby rabbits (the "€" of the
## map, see Animal kind "kit") hopping about its mouth. When the hero comes near they dive into the
## burrow and come out again once he is well away. The burrow is only a picture: it blocks nobody.

## How many kits live at one burrow.
const KITS := 5
## How far from the burrow's mouth a kit starts (metres).
const START_RADIUS := 1.1


## The loose earth the burrow is dug into, as a texture and as bumps; stones; bark for the roots;
## the streaks of the grass blades (built once, see _textures).
static var _soil: NoiseTexture2D
static var _soil_bumps: NoiseTexture2D
static var _rock: NoiseTexture2D
static var _rock_bumps: NoiseTexture2D
static var _wood: NoiseTexture2D
static var _blades: NoiseTexture2D

## The mouth: an irregular, slightly oval opening (half-axes in metres, turned by MOUTH_TURN).
const MOUTH_A := 0.31
const MOUTH_B := 0.2
const MOUTH_TURN := 0.35
## How far the mound of dug-out soil reaches round the mouth (in front, and added behind it).
const MOUND_FRONT := 0.58
const MOUND_BACK := 0.4
## How deep the tunnel drops (metres) and how far it runs back under the mound.
const TUNNEL_DEPTH := 0.34
const TUNNEL_BACK := 0.16
## The grass blades' colours (grey, tinted by the season) and the autumn leaves' colours.
const GRASS_GREEN := Color(0.4, 0.58, 0.2)
const GRASS_SPRING := Color(0.46, 0.66, 0.24)
const GRASS_STRAW := Color(0.68, 0.58, 0.34)
const WINTER_LOW := 0.55
const LEAVES := [Color(0.7, 0.28, 0.1), Color(0.82, 0.55, 0.14), Color(0.55, 0.3, 0.12), Color(0.62, 0.2, 0.1)]


## The burrow: a slightly oval mouth in the ground, angled in under a mound of dug-out soil that lies
## on one side (the mouth faces +z, the soil heaps up behind it), loose earth and pebbles scattered
## round it, grass and roots hanging over the rim and a dark, earthy tunnel inside. `seed_value`
## makes each burrow its own. Snow settles on the mound and the stones, not down the hole (see
## SnowCover), and the grass and fallen leaves follow the seasons (see dress).
static func burrow(seed_value := 0) -> Node3D:
	_textures()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + seed_value * 7919
	var shape := _shape(rng)
	var root := Node3D.new()
	root.name = "Burrow"
	root.set_meta("shape", shape)
	root.add_child(_mesh("Mound", _mound(shape), _earth(0.7)))
	var inside := _mesh("Tunnel", _tunnel(shape, rng), _earth(0.8))
	inside.set_meta("no_snow", true)
	root.add_child(inside)
	root.add_child(_mesh("Clods", _clods(shape, rng), _earth(0.6)))
	root.add_child(_mesh("Pebbles", _pebbles(shape, rng), _stone()))
	root.add_child(_mesh("Roots", _roots(shape, rng), _wood_material()))
	var grass := _mesh("Grass", _grass(shape, rng), _grass_material())
	grass.set_meta("no_snow", true)
	root.add_child(grass)
	var leaves := _mesh("Leaves", _leaves(shape, rng), _leaf_material())
	leaves.set_meta("no_snow", true)
	root.add_child(leaves)
	return root


## Dresses a burrow for season day `day` (see Seasons): green grass in summer, fresher in spring,
## straw in autumn with fallen leaves lying by the mouth, pale and flattened (and the leaves gone
## under the snow) in winter.
static func dress(burrow_node: Node3D, day: int) -> void:
	if burrow_node == null:
		return
	var at := IvySeasons.stage(day)
	if int(burrow_node.get_meta("season_stage", -1)) == at:
		return
	burrow_node.set_meta("season_stage", at)
	var grass := burrow_node.get_node_or_null("Grass") as MeshInstance3D
	var leaves := burrow_node.get_node_or_null("Leaves") as MeshInstance3D
	if grass != null:
		var c := GRASS_GREEN
		var low := 1.0
		if at == IvySeasons.SPRING:
			c = GRASS_SPRING
		elif at == IvySeasons.WINTER:
			c = GRASS_STRAW.lerp(Color(0.8, 0.78, 0.7), 0.4)
			low = WINTER_LOW
		elif at != IvySeasons.SUMMER:
			c = GRASS_GREEN.lerp(GRASS_STRAW, IvySeasons.turned(at))
		(grass.material_override as StandardMaterial3D).albedo_color = c
		grass.scale = Vector3(1.15 if low < 1.0 else 1.0, low, 1.15 if low < 1.0 else 1.0)
	if leaves != null:
		leaves.visible = Weather.is_autumn(day) and at != IvySeasons.WINTER


## The kinds of shape of this burrow: phases that make its mouth and mound irregular.
static func _shape(rng: RandomNumberGenerator) -> Dictionary:
	var ph: Array[float] = []
	for i in 8:
		ph.append(rng.randf() * TAU)
	return {"ph": ph, "side": 1.0 if rng.randf() < 0.5 else -1.0}


## Unit direction (x, z) for angle `a`: 0 faces the front (+z).
static func _dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


## The mouth's radius at angle `a`: an oval, turned, with a lumpy rim.
static func _rim(shape: Dictionary, a: float) -> float:
	var ph: Array = shape.ph
	var u := _dir(a).rotated(MOUTH_TURN)
	var r := MOUTH_A * MOUTH_B / sqrt(pow(MOUTH_B * u.x, 2) + pow(MOUTH_A * u.y, 2))
	return r * (1.0 + 0.1 * sin(3.0 * a + ph[0]) + 0.06 * sin(5.0 * a + ph[1]) + 0.03 * sin(9.0 * a + ph[2]))


## How far behind the mouth angle `a` points (0 in front, 1 straight behind).
static func _back(a: float) -> float:
	return (1.0 - cos(a)) * 0.5


## Where the mound ends at angle `a`: little in front, a heap behind and to one side.
static func _outer(shape: Dictionary, a: float) -> float:
	var ph: Array = shape.ph
	var side: float = shape.side
	var r := MOUND_FRONT + MOUND_BACK * pow(_back(a), 1.2) + 0.12 * maxf(0.0, sin(a) * side) * _back(a)
	return r * (1.0 + 0.1 * sin(2.0 * a + ph[3]) + 0.07 * sin(5.0 * a + ph[4]))


## The height of the lip of the mouth at angle `a`: soil heaped up behind it, nearly flat in front.
static func _lip(shape: Dictionary, a: float) -> float:
	var side: float = shape.side
	return 0.035 + 0.23 * pow(_back(a), 1.5) + 0.07 * maxf(0.0, sin(a) * side) * _back(a)


## The height of the ground at (x, z) round the mouth, for putting stones and clods on it.
static func ground_at(shape: Dictionary, p: Vector2) -> float:
	var a := atan2(p.x, p.y)
	var rim := _rim(shape, a)
	var out := _outer(shape, a)
	var t := clampf((p.length() - rim) / (out - rim), 0.0, 1.0)
	return _lip(shape, a) * pow(1.0 - t, 1.7) - 0.02 * t


## The mound: rings from the mouth's rim out to the mound's edge, which sinks into the ground.
static func _mound(shape: Dictionary) -> ArrayMesh:
	var ph: Array = shape.ph
	var rings := 8
	var around := 44
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for k in rings + 1:
		var t := float(k) / float(rings)
		var row: Array = []
		for i in around:
			var a := TAU * float(i) / float(around)
			var rim := _rim(shape, a)
			var out := _outer(shape, a)
			var u := _dir(a)
			var r := lerpf(rim, out, t)
			var h := _lip(shape, a) * pow(1.0 - t, 1.7) - 0.02 * t
			h += 0.022 * sin(7.0 * a + ph[5]) * sin(t * PI) + 0.015 * sin(11.0 * a + 3.0 * t + ph[6]) * sin(t * PI)
			# A rolled lip of soil right at the rim.
			h += 0.03 * exp(-pow((t - 0.08) / 0.08, 2))
			var dry := Color(0.44, 0.33, 0.22)
			var moist := Color(0.27, 0.19, 0.12)
			var col := moist.lerp(dry, smoothstep(0.0, 0.8, t))
			col *= 0.88 + 0.24 * (0.5 + 0.5 * sin(13.0 * a + 5.0 * t + ph[7]))
			row.append([Vector3(u.x * r, h, u.y * r), col])
		grid.append(row)
	for k in rings:
		for i in around:
			var j := (i + 1) % around
			var q: Array = [grid[k][i], grid[k][j], grid[k + 1][j], grid[k + 1][i]]
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for n in tri:
					var v: Array = q[n]
					st.set_color(v[1])
					st.set_uv(Vector2(v[0].x, v[0].z) * 1.6)
					st.add_vertex(v[0])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## The tunnel: rings that shrink from the rim down and back into the dark. Earth at the rim, black
## far down; the front lip is low, so the way in slopes down and under the mound behind.
static func _tunnel(shape: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var steps := 6
	var around := 44
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	var wobble: Array[float] = []
	for i in around:
		wobble.append(0.9 + 0.2 * rng.randf())
	for k in steps + 1:
		var f := float(k) / float(steps)
		var row: Array = []
		for i in around:
			var a := TAU * float(i) / float(around)
			var rim := _rim(shape, a)
			var u := _dir(a)
			var rim_y := _lip(shape, a) + 0.03 * exp(-pow(0.08 / 0.08, 2))
			var s := lerpf(1.0, 0.18, pow(f, 0.8)) * lerpf(1.0, wobble[i], f)
			var y := lerpf(rim_y, -TUNNEL_DEPTH, pow(f, 0.9))
			# The ground is not cut open: at the front the way in stays a dark ramp at ground level,
			# only behind the mouth does it drop away.
			y = lerpf(y, maxf(y, 0.015), 1.0 - smoothstep(0.3, 0.6, _back(a)))
			var pos := Vector3(u.x * rim * s, y, u.y * rim * s - TUNNEL_BACK * f)
			var col := Color(0.15, 0.105, 0.065).lerp(Color(0.02, 0.015, 0.01), smoothstep(0.0, 0.5, f))
			row.append([pos, col])
		grid.append(row)
	for k in steps:
		for i in around:
			var j := (i + 1) % around
			var q: Array = [grid[k][i], grid[k][j], grid[k + 1][j], grid[k + 1][i]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for n in tri:
					var v: Array = q[n]
					st.set_color(v[1])
					st.set_uv(Vector2(v[0].x, v[0].y + v[0].z) * 2.0)
					st.add_vertex(v[0])
	# The bottom: a dark floor so no hole shows through.
	var centre := Vector3(0, -TUNNEL_DEPTH, -TUNNEL_BACK)
	for i in around:
		var j := (i + 1) % around
		for v in [centre, grid[steps][j][0], grid[steps][i][0]]:
			st.set_color(Color(0.02, 0.015, 0.01))
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## One roughly spherical lump (a clod of earth or a pebble) added to `st`: `r` its half-sizes,
## `rough` how uneven it is, `flat` whether its faces show (a stone) or blend (earth).
static func _lump(st: SurfaceTool, at: Vector3, r: Vector3, rng: RandomNumberGenerator, col: Color, rough: float, flat: bool) -> void:
	var lon := 8
	var lat := 5
	var pts: Array = []
	var yaw := rng.randf() * TAU
	for j in lat + 1:
		var row: Array = []
		var phi := PI * float(j) / float(lat)
		for i in lon:
			var th := TAU * float(i) / float(lon) + yaw
			var k := 1.0 + rough * (rng.randf() - 0.5) * (0.0 if j == 0 or j == lat else 1.0)
			row.append(at + Vector3(sin(phi) * cos(th) * r.x, -cos(phi) * r.y, sin(phi) * sin(th) * r.z) * k)
		pts.append(row)
	for j in lat:
		for i in lon:
			var n := (i + 1) % lon
			var q: Array = [pts[j][i], pts[j][n], pts[j + 1][n], pts[j + 1][i]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for m in tri:
					var v: Vector3 = q[m]
					st.set_smooth_group(-1 if flat else 0)
					st.set_color(col * (0.9 + 0.2 * rng.randf()))
					st.set_uv(Vector2(v.x, v.z) * 5.0 + Vector2(v.y, 0) * 3.0)
					st.add_vertex(v)


## Where a loose piece lies: `reach` times the mound's edge from the mouth, at angle `a`.
static func _spot(shape: Dictionary, a: float, reach: float) -> Vector3:
	var u := _dir(a)
	var p := u * (_outer(shape, a) * reach)
	return Vector3(p.x, maxf(ground_at(shape, p), -0.01), p.y)


## Crumbs and clods of dug-out earth over the mound and the ground beside it.
static func _clods(shape: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 26:
		var a := rng.randf() * TAU
		# Heavier at the back, where the soil was thrown.
		if rng.randf() > 0.35 + 0.65 * _back(a):
			a = fposmod(a + PI, TAU) if rng.randf() < 0.5 else a
		var at := _spot(shape, a, rng.randf_range(0.35, 1.25))
		var s := rng.randf_range(0.022, 0.06)
		var dark := rng.randf()
		var col := Color(0.34, 0.24, 0.15).lerp(Color(0.52, 0.4, 0.27), dark)
		_lump(st, at + Vector3(0, s * 0.3, 0), Vector3(s * 1.2, s * 0.7, s), rng, col, 0.5, false)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Pebbles: a few larger ones and a scatter of small, grey and brown, with faceted faces.
static func _pebbles(shape: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 11:
		var a := rng.randf() * TAU
		var at := _spot(shape, a, rng.randf_range(0.55, 1.35))
		var s := rng.randf_range(0.035, 0.07) if i < 3 else rng.randf_range(0.015, 0.035)
		var tone := rng.randf_range(0.45, 0.7)
		var col := Color(tone, tone * 0.97, tone * 0.9)
		_lump(st, at + Vector3(0, s * 0.4, 0), Vector3(s * rng.randf_range(1.0, 1.5), s * 0.7, s), rng, col, 0.45, true)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A tapered root along a bent path from `s` over `c` to `e`, `r` thick where it starts.
static func _root(st: SurfaceTool, s: Vector3, c: Vector3, e: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var segs := 7
	var sides := 5
	var prev: Array = []
	for k in segs + 1:
		var t := float(k) / float(segs)
		var p := s.lerp(c, t).lerp(c.lerp(e, t), t)
		p += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.008
		var rad := r * lerpf(1.0, 0.25, t)
		var ring: Array = []
		for i in sides:
			var th := TAU * float(i) / float(sides)
			ring.append(p + Vector3(cos(th), sin(th) * 0.9, 0.3 * cos(th + 1.0)) * rad)
		if k > 0:
			for i in sides:
				var n := (i + 1) % sides
				var q: Array = [prev[i], prev[n], ring[n], ring[i]]
				for tri in [[0, 1, 2], [0, 2, 3]]:
					for m in tri:
						var v: Vector3 = q[m]
						st.set_color(Color(0.42, 0.32, 0.22) * (0.8 + 0.3 * t))
						st.set_uv(Vector2(float(i) / float(sides) * 2.0, t * 3.0))
						st.add_vertex(v)
		prev = ring


## Roots that break out of the soil above the mouth and hang down over its back rim.
static func _roots(shape: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: float = shape.side
	for i in 4:
		var a := PI + rng.randf_range(-0.8, 0.8)
		var rim := _rim(shape, a)
		var u := _dir(a)
		var top := _lip(shape, a) + 0.02
		var s := Vector3(u.x * rim * 1.05, top - 0.04, u.y * rim * 1.05)
		var c := Vector3(u.x * rim * 0.78, top - 0.1, u.y * rim * 0.78)
		var e := Vector3(u.x * rim * 0.6, top * rng.randf_range(0.1, 0.35), u.y * rim * 0.6)
		_root(st, s, c, e, rng.randf_range(0.016, 0.026), rng)
	# One long root that runs over the mound beside it.
	var a0 := PI - 1.2 * side
	var u0 := _dir(a0)
	var s0 := Vector3(u0.x * 0.5, ground_at(shape, u0 * 0.5) + 0.02, u0.y * 0.5)
	_root(st, s0, s0.lerp(Vector3.ZERO, 0.5) + Vector3(0, 0.07, 0), Vector3(u0.x * 0.24, ground_at(shape, u0 * 0.24) + 0.03, u0.y * 0.24), 0.02, rng)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Grass leaning over the rim: bent blades round the back and sides of the mouth and along the
## mound's edge. Grey on the vertices (the season tints it, see dress), darker at the foot.
static func _grass(shape: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 70:
		var a := rng.randf() * TAU
		var on_rim := rng.randf() < 0.55
		var base_r := _rim(shape, a) + (0.02 if on_rim else 0.0)
		if not on_rim:
			base_r = _outer(shape, a) * rng.randf_range(0.8, 1.15)
		else:
			# Nothing grows in the way in, at the front of the mouth.
			if _back(a) < 0.18:
				continue
		var u := _dir(a)
		var foot := Vector3(u.x * base_r, maxf(ground_at(shape, u * base_r), -0.01), u.y * base_r)
		var h := rng.randf_range(0.1, 0.26) * (1.0 if on_rim else 0.8)
		var lean := (u if on_rim else _dir(rng.randf() * TAU)) * rng.randf_range(0.04, 0.13)
		var side := Vector3(-u.y, 0, u.x) * rng.randf_range(0.012, 0.022)
		var mid := foot + Vector3(lean.x * 0.4, h * 0.6, lean.y * 0.4)
		var tip := foot + Vector3(lean.x * 1.5, h * 0.75, lean.y * 1.5)
		var shade := rng.randf_range(0.85, 1.15)
		var v: Array = [
			[foot - side, 0.55], [foot + side, 0.55],
			[mid - side * 0.6, 0.8], [mid + side * 0.6, 0.8], [tip, 1.0],
		]
		for tri in [[0, 1, 3], [0, 3, 2], [2, 3, 4]]:
			for n in tri:
				var vv: Array = v[n]
				var g: float = vv[1] * shade
				st.set_color(Color(g, g, g))
				st.set_uv(Vector2(float(n % 2), 1.0 - float(vv[1])))
				st.add_vertex(vv[0])
	st.generate_normals()
	return st.commit()


## A few fallen leaves in the dirt by the mouth (shown in autumn, see dress).
static func _leaves(shape: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var a := rng.randf() * TAU
		var at := _spot(shape, a, rng.randf_range(0.5, 1.4))
		at.y += 0.012
		var yaw := rng.randf() * TAU
		var size := rng.randf_range(0.05, 0.085)
		var col: Color = LEAVES[rng.randi() % LEAVES.size()]
		var pts: Array = [Vector2(0, -1), Vector2(0.55, -0.2), Vector2(0.4, 0.55), Vector2(0, 1), Vector2(-0.4, 0.55), Vector2(-0.55, -0.2)]
		for n in 6:
			var p0: Vector2 = pts[n].rotated(yaw) * size
			var p1: Vector2 = pts[(n + 1) % 6].rotated(yaw) * size
			for v in [Vector3.ZERO, Vector3(p0.x, 0.004, p0.y), Vector3(p1.x, 0.004, p1.y)]:
				st.set_color(col * (0.9 + 0.2 * rng.randf()))
				st.set_uv(Vector2(v.x, v.z) * 8.0)
				st.add_vertex(at + v)
	st.generate_normals()
	return st.commit()


static func _mesh(node_name: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _earth(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = _soil
	m.normal_enabled = true
	m.normal_texture = _soil_bumps
	m.normal_scale = 1.2
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = _rock
	m.normal_enabled = true
	m.normal_texture = _rock_bumps
	m.roughness = 0.9
	return m


static func _wood_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = _wood
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _grass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_color = GRASS_GREEN
	m.albedo_texture = _blades
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _leaf_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	m.albedo_texture = _wood
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Builds the shared textures once.
static func _textures() -> void:
	if _soil != null:
		return
	_soil = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.09, 4, 0.62, false, 0.0, 128, 128)
	_soil_bumps = _noise(FastNoiseLite.TYPE_CELLULAR, 0.12, 3, 0.5, true, 5.0, 128, 128)
	_rock = _noise(FastNoiseLite.TYPE_CELLULAR, 0.07, 3, 0.5, false, 0.0, 128, 128, 0.6)
	_rock_bumps = _noise(FastNoiseLite.TYPE_CELLULAR, 0.07, 3, 0.5, true, 6.0, 128, 128)
	_wood = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 3, 0.5, false, 0.0, 64, 128, 0.55)
	_blades = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.12, 2, 0.5, false, 0.0, 32, 32, 0.7)


## A seamless noise texture: its grey runs from `low` to white (or as a normal map of `bump` strength).
static func _noise(kind: int, freq: float, octaves: int, gain: float, bumps: bool, bump: float, w: int, h: int, low := 0.62) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.seed = 17
	var t := NoiseTexture2D.new()
	t.width = w
	t.height = h
	t.seamless = true
	t.noise = n
	if bumps:
		t.as_normal_map = true
		t.bump_strength = bump
	else:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(low, low, low))
		ramp.set_color(1, Color(1, 1, 1))
		t.color_ramp = ramp
	return t


## Where kit number `i` of `KITS` starts, round the burrow at `centre`.
static func start_of(centre: Vector3, i: int) -> Vector3:
	var a := TAU * float(i) / float(KITS) + 0.4
	return centre + Vector3(sin(a), 0.0, cos(a)) * START_RADIUS
