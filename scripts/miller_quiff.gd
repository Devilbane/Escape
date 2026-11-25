class_name MillerQuiff
extends RefCounted
## Miller Korbinian's haircut: a swept-up quiff in burnished copper. A dark
## cap of roots covers the scalp; over it lie several hundred fine strands, each
## a thin tapering tube with its own shade (dark copper at the root, bright
## copper to gold at the tip). At the front they rise into a tall wave that
## sweeps to one side and curls back, the sides are combed back and tidy over the
## ears, and the back lies short to the nape. The strands carry streak texture
## coordinates, so the hair is grooved and glossy and never one flat colour.
## Built in code and hung from the head bone like the dreadlocks (see
## Dreadlocks, HairLook.head_slot), so it moves with the head. Worn by a
## villager whose role has "locks": "quiff".

const ROOT := Color(0.46, 0.2, 0.09)
const MID := Color(0.8, 0.45, 0.2)
const TIP := Color(0.96, 0.64, 0.32)
const GOLD := Color(1.0, 0.82, 0.48)

## The middle of the skull in the head mesh's space (see Dreadlocks).
const SKULL_CENTER := Vector3(0.0, 1.74, -0.02)
## The cap sits this far out of the scalp.
const CAP_OUT := 0.02
## Strand counts: the front wave, the combed-back sides (each side) and the back.
const WAVE := 150
const SIDE := 55
const BACK := 60
## Points along a strand, and sides of its tube.
const POINTS := 14
const SIDES := 4
## How far the wave rises, and how far it sweeps sideways (towards +x).
const RISE := 0.24
const SWEEP := 0.4

static var _mesh: ArrayMesh = null
static var _material: StandardMaterial3D = null
static var _skull := PackedVector3Array()


## Gives a model the quiff (once).
static func grow(model: Node3D) -> void:
	if model.find_child("Quiff", true, false):
		return
	var head := model.find_child("*_Head", true, false) as MeshInstance3D
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null or head.skin == null:
		return
	var slot := BoneAttachment3D.new()
	slot.name = "QuiffSlot"
	slot.bone_name = "head"
	skeleton.add_child(slot)
	var hair := MeshInstance3D.new()
	hair.name = "Quiff"
	hair.mesh = mesh(head.mesh)
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			hair.transform = head.skin.get_bind_pose(i)
	slot.add_child(hair)


## The cap and all strands as one mesh, fitted to the head mesh.
static func mesh(head: Mesh) -> ArrayMesh:
	if _mesh:
		return _mesh
	_skull = PackedVector3Array()
	for v: Vector3 in head.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y > 1.62 or (v.y > 1.4 and v.z < 0.0 and absf(v.x) < 0.5):
			_skull.append(v - SKULL_CENTER)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cap(st)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in WAVE:
		_strand(st, _wave_path(float(i) / (WAVE - 1), rng), rng, 0.034, i % 7 == 0)
	for side in [-1.0, 1.0]:
		for i in SIDE:
			_strand(st, _side_path(side, float(i) / (SIDE - 1), rng), rng, 0.03, false)
	for i in BACK:
		_strand(st, _back_path(float(i) / (BACK - 1), rng), rng, 0.03, false)
	st.generate_normals()
	st.set_material(material())
	_mesh = st.commit()
	return _mesh


## Glossy hair with fine streaks along every strand.
static func material() -> StandardMaterial3D:
	if _material:
		return _material
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	_material.albedo_texture = _streaks()
	_material.roughness = 0.7
	_material.metallic_specular = 0.2
	# A little warmth of its own, so the hair never goes black in shadow.
	_material.emission_enabled = true
	_material.emission = Color(0.2, 0.08, 0.03)
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


## A light streak texture: u runs across a strand, v along it; fine bright and
## dark lines multiply the strand colour.
static func _streaks() -> ImageTexture:
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lines := []
	for x in 32:
		lines.append(rng.randf_range(0.78, 1.12))
	for y in 64:
		for x in 32:
			var edge := 1.0 - 0.28 * pow(absf(float(x) / 31.0 * 2.0 - 1.0), 2.0)
			var wobble := 1.0 + 0.06 * sin(float(y) * 0.5 + float(x))
			var v := clampf(lines[x] * edge * wobble, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## How far out of the skull's middle the scalp is in a direction.
static func _scalp(dir: Vector3) -> float:
	var far := 0.0
	for v in _skull:
		var d := v.length()
		if d > far and v.dot(dir) > d * 0.97:
			far = d
	return far if far > 0.0 else 0.46


static func _at(dir: Vector3, lift: float) -> Vector3:
	var d := dir.normalized()
	return SKULL_CENTER + d * (_scalp(d) + CAP_OUT + lift)


## The cap of dark roots over the scalp, within the hairline (see Dreadlocks.grows).
static func _cap(st: SurfaceTool) -> void:
	var lat := 14
	var lon := 28
	var points := []
	for i in lat + 1:
		var row := []
		var up := 1.0 - 1.6 * float(i) / lat
		var flat := sqrt(maxf(0.0, 1.0 - up * up))
		for j in lon + 1:
			var a := TAU * j / lon
			var dir := Vector3(sin(a) * flat, up, cos(a) * flat).normalized()
			row.append(SKULL_CENTER + dir * (_scalp(dir) + CAP_OUT * 0.5) if Dreadlocks.grows(dir) else null)
		points.append(row)
	st.set_color(ROOT if Graphics.vertex_colours_srgb() else ROOT.srgb_to_linear())
	for i in lat:
		for j in lon:
			var a = points[i][j]
			var b = points[i][j + 1]
			var c = points[i + 1][j + 1]
			var d = points[i + 1][j]
			if a == null or b == null or c == null or d == null:
				continue
			for p in [a, b, c, a, c, d]:
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(p)


## A strand of the front wave: it starts along the front hairline, rises into a
## tall swell over the forehead, sweeps sideways and lies back over the crown with
## its tip curling up. s runs across the front (0 and 1 are the temples).
static func _wave_path(s: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var across := lerpf(-1.0, 1.0, s) + rng.randf_range(-0.03, 0.03)
	var start := Vector3(across * 0.62, 0.5 + rng.randf_range(0.0, 0.1) - 0.1 * absf(across), 0.78 - 0.25 * absf(across))
	var finish := Vector3(across * 0.3 + SWEEP, 0.72, -0.5 - rng.randf_range(0.0, 0.25))
	# Strands in the middle rise highest; the ones at the temples lie flatter.
	var height := RISE * (1.0 - 0.55 * absf(across)) * rng.randf_range(0.85, 1.12)
	var out: Array[Vector3] = []
	for i in POINTS:
		var t := float(i) / (POINTS - 1)
		var dir := start.normalized().slerp(finish.normalized(), t)
		# The swell stands at the front and settles over the crown; the tip flicks up.
		var lift := height * pow(sin(PI * minf(t * 1.25, 1.0)), 0.8) * (1.0 - 0.45 * t) + 0.05 * pow(t, 4.0)
		var p := _at(dir, lift)
		# The front of the wave leans forward and over to the swept side.
		p.z += 0.14 * height / RISE * maxf(0.0, 1.0 - t / 0.4) * (1.0 - 0.4 * absf(across))
		p.x += 0.1 * sin(PI * t) * (1.0 + across * 0.4)
		out.append(p)
	return out


## A strand of a side: from the temple, back over the ear and down to the nape,
## lying close to the head.
static func _side_path(side: float, s: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var start := Vector3(side * 0.95, lerpf(0.55, 0.02, s) + rng.randf_range(-0.02, 0.02), lerpf(0.3, 0.1, s))
	var finish := Vector3(side * 0.55, lerpf(0.5, -0.12, s), -0.85)
	var out: Array[Vector3] = []
	for i in POINTS:
		var t := float(i) / (POINTS - 1)
		var dir := start.normalized().slerp(finish.normalized(), t)
		out.append(_at(dir, 0.03 + 0.035 * sin(PI * t)))
	return out


## A strand of the back: from the crown down to the nape, lying short.
static func _back_path(s: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var across := lerpf(-1.0, 1.0, s) + rng.randf_range(-0.04, 0.04)
	var start := Vector3(across * 0.5, 0.9, -0.2)
	var finish := Vector3(across * 0.55, -0.2, -0.85)
	var out: Array[Vector3] = []
	for i in POINTS:
		var t := float(i) / (POINTS - 1)
		var dir := start.normalized().slerp(finish.normalized(), t)
		out.append(_at(dir, 0.035 + 0.03 * sin(PI * t)))
	return out


## One strand: a thin tube along the path, thick at 30 percent and tapering to a
## point, with its own shade; a few strands are bright, sun-bleached gold.
static func _strand(st: SurfaceTool, path: Array[Vector3], rng: RandomNumberGenerator, thick: float, bright: bool) -> void:
	var shade := rng.randf_range(0.82, 1.15)
	var twist := rng.randf() * TAU
	var prev := PackedVector3Array()
	var prev_color := ROOT
	var prev_v := 0.0
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		var along := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var r := thick * (0.5 + 0.5 * minf(t / 0.3, 1.0)) * (1.0 - 0.8 * pow(t, 2.5))
		var tip := GOLD if bright else TIP
		var color := (ROOT.lerp(MID, minf(t * 2.0, 1.0)) if t < 0.5 else MID.lerp(tip, (t - 0.5) * 2.0)) * shade
		color.a = 1.0
		# The compatibility renderer reads vertex colours as linear.
		if not Graphics.vertex_colours_srgb():
			color = color.srgb_to_linear()
		var ring := _circle(path[i], along, r, twist)
		if i > 0:
			_band(st, prev, ring, prev_color, color, prev_v, t)
		prev = ring
		prev_color = color
		prev_v = t


static func _circle(at: Vector3, along: Vector3, r: float, twist: float) -> PackedVector3Array:
	var side := along.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(along).normalized()
	var out := PackedVector3Array()
	for k in SIDES:
		var a := twist + TAU * k / SIDES
		out.append(at + (side * cos(a) + up * sin(a)) * r)
	return out


static func _band(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array, ca: Color, cb: Color, va: float, vb: float) -> void:
	for k in SIDES:
		var k2 := (k + 1) % SIDES
		var u1 := float(k) / SIDES
		var u2 := float(k + 1) / SIDES
		for v in [[ca, a[k], u1, va], [cb, b[k], u1, vb], [cb, b[k2], u2, vb], [ca, a[k], u1, va], [cb, b[k2], u2, vb], [ca, a[k2], u2, va]]:
			st.set_color(v[0])
			st.set_uv(Vector2(v[2], v[3]))
			st.add_vertex(v[1])
