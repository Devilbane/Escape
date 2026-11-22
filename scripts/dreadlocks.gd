class_name Dreadlocks
extends RefCounted
## Guild Master Ragna's dreadlocks: long, thick, rope-like locks that grow from
## the top, back and sides of the head, fall over the shoulders and down the
## back, and leave the face free. Each lock is a chunky tube, knotted into
## segments that swell and pinch along its length, and some carry a bronze or
## iron ring or two. A dark cap of matted hair covers the scalp between the
## roots. Built in code, in the low-poly shapes of the KayKit people, and hung
## from the head bone like the mohawk's crest (see HairLook.head_slot), so
## they move with the head. Worn by a villager whose role has "locks": "dread".

const HAIR := Color(0.16, 0.115, 0.085)
const TIP := Color(0.3, 0.21, 0.14)
const RING_COLORS := [Color(0.62, 0.42, 0.18), Color(0.5, 0.52, 0.55)]

## The middle of the skull, in the head mesh's space (the face looks towards
## +z, the top of the head is at about y 2.19). How far out the scalp is in a
## direction is measured from the head mesh itself (see _scalp).
const SKULL_CENTER := Vector3(0.0, 1.74, -0.02)
## The locks keep this far off the scalp, and the cap sits this far out.
const CLEAR := 0.07
const CAP_OUT := 0.025
## The shoulders and back the locks drape over, as an upright elliptic
## cylinder below the chin.
const BODY_TOP := 1.36
const BODY_CENTER_Z := -0.06
const BODY_RADII := Vector2(0.5, 0.48)

## How thick a lock is at its root, the length of one knotted segment, and
## the number of sides of the tube.
const THICK := 0.085
const KNOT := 0.1
const SIDES := 7
## How far down (in the head mesh's space) the locks reach: the ones at the
## back longest, the ones over the shoulders shorter.
const BACK_END := 0.72
const SIDE_END := 0.98

static var _mesh: ArrayMesh = null
## The head mesh's vertices around the skull's middle, for _scalp.
static var _skull := PackedVector3Array()


## Grows the locks on a model's head (once).
static func grow(model: Node3D) -> void:
	if model.find_child("Dreadlocks", true, false):
		return
	var head := model.find_child("*_Head", true, false) as MeshInstance3D
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null or head.skin == null:
		return
	var slot := BoneAttachment3D.new()
	slot.name = "LockSlot"
	slot.bone_name = "head"
	skeleton.add_child(slot)
	var locks := MeshInstance3D.new()
	locks.name = "Dreadlocks"
	locks.mesh = mesh(head.mesh)
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			locks.transform = head.skin.get_bind_pose(i)
	slot.add_child(locks)


## All the locks and the cap, one mesh with their colours in the vertices,
## fitted to the head mesh.
static func mesh(head: Mesh) -> ArrayMesh:
	if _mesh:
		return _mesh
	_skull = PackedVector3Array()
	for v: Vector3 in head.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		# The skull only: no beard, chin or ears.
		if v.y > 1.62 or (v.y > 1.4 and v.z < 0.0 and absf(v.x) < 0.5):
			_skull.append(v - SKULL_CENTER)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cap(st)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for root in roots():
		_lock(st, root, rng)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.roughness = 0.8
	# The cap is seen from inside where it dips under a lock.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


## Whether hair grows in a direction from the skull's middle: everywhere
## above the hairline, which runs over the brow, behind the ears and round
## the nape.
static func grows(dir: Vector3) -> bool:
	if dir.y > 0.42:
		return true
	if dir.y < -0.05:
		return dir.z < -0.35 and dir.y > -0.45
	return dir.z < -0.05 + 0.4 * dir.y


## The directions (from the skull's middle) the locks grow out of: rings of
## roots from the crown down to the nape.
static func roots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	# Rings by height: the sine of the angle above the skull's middle, and
	# how many locks share the ring.
	var rings := [[0.82, 6], [0.58, 11], [0.32, 13], [0.06, 13], [-0.22, 10]]
	for r in rings.size():
		var up: float = rings[r][0]
		var n: int = rings[r][1]
		var flat := sqrt(1.0 - up * up)
		for i in n:
			var a := TAU * (i + 0.5 * (r % 2)) / n
			var dir := Vector3(sin(a) * flat, up, cos(a) * flat)
			# The front of the hairline is only the cap: a lock there would
			# stand out over the brow.
			if grows(dir) and dir.z < 0.5:
				out.append(dir)
	return out


## How far out of the skull's middle the scalp is in a direction.
static func _scalp(dir: Vector3) -> float:
	var far := 0.0
	for v in _skull:
		var d := v.length()
		if d > far and v.dot(dir) > d * 0.97:
			far = d
	return far if far > 0.0 else 0.46


## The dark cap of matted hair over the scalp, within the hairline.
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
			row.append(SKULL_CENTER + dir * (_scalp(dir) + CAP_OUT) if grows(dir) else null)
		points.append(row)
	st.set_color(HAIR)
	for i in lat:
		for j in lon:
			var a = points[i][j]
			var b = points[i][j + 1]
			var c = points[i + 1][j + 1]
			var d = points[i + 1][j]
			if a == null or b == null or c == null or d == null:
				continue
			for p in [a, d, c, a, c, b]:
				st.add_vertex(p)


## One lock: its path from the root, lying along the scalp towards the back
## and then hanging down, around the skull and over the shoulders; then a
## knotted tube along it.
static func _lock(st: SurfaceTool, dir: Vector3, rng: RandomNumberGenerator) -> void:
	var p := SKULL_CENTER + dir * (_scalp(dir) + CAP_OUT)
	# It starts off along the scalp, down and back, lifted a little off it.
	var pull := Vector3(0, -0.35, -1)
	var heading := (pull - dir * pull.dot(dir)).normalized() + dir * 0.15
	heading.z = minf(heading.z, -0.3)
	heading.y = minf(heading.y, 0.0)
	var back := clampf(-dir.z, 0.0, 1.0)
	var end_y := lerpf(SIDE_END, BACK_END, back) + rng.randf_range(-0.07, 0.07)
	var step := KNOT / 3.0
	var path: Array[Vector3] = [p]
	for i in 120:
		# Combed back over the top of the head, it only falls once behind it.
		var behind := clampf((SKULL_CENTER.z + 0.1 - p.z) / 0.3, 0.04, 1.0)
		heading = (heading.normalized() + Vector3(0, -0.25 * behind, -0.04)).normalized()
		p = _clear(p + heading * step)
		path.append(p)
		if p.y < end_y:
			break
	var thick := THICK * rng.randf_range(0.88, 1.12)
	var rings := []
	if path.size() > 18 and rng.randf() < 0.4:
		var at := rng.randi_range(3, path.size() / 3 - 2) * 3 + 1
		rings.append_array([at, at + 1])
		if rng.randf() < 0.5:
			rings.append_array([at + 3, at + 4])
	var ring_color: Color = RING_COLORS[rng.randi() % RING_COLORS.size()]
	var twist := rng.randf() * TAU
	var prev: PackedVector3Array
	var prev_color := HAIR
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		var along := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		# Knotted: a pinch every third point, and a rounded swelling between.
		var r := thick * (0.78 if i % 3 == 0 else 1.0) * lerpf(1.0, 0.8, t)
		var color := HAIR.lerp(TIP, t * t)
		if i in rings:
			r = thick * 1.18
			color = ring_color
		if i == path.size() - 1:
			r *= 0.6
		var ring := _circle(path[i], along, r, twist)
		if i > 0:
			_band(st, prev, ring, prev_color, color)
		prev = ring
		prev_color = color
	# A blunt, rounded end.
	var tip := path[path.size() - 1] + (path[path.size() - 1] - path[path.size() - 2]).normalized() * thick * 0.45
	st.set_color(prev_color)
	for k in SIDES:
		st.add_vertex(prev[k])
		st.add_vertex(prev[(k + 1) % SIDES])
		st.add_vertex(tip)


## Pushes a point of a lock off the scalp and out of the body.
static func _clear(p: Vector3) -> Vector3:
	var rel := p - SKULL_CENTER
	var dir := rel.normalized()
	var keep := _scalp(dir) + CLEAR
	if rel.length() < keep:
		p = SKULL_CENTER + dir * keep
	if p.y < BODY_TOP:
		var flat := Vector2(p.x / BODY_RADII.x, (p.z - BODY_CENTER_Z) / BODY_RADII.y)
		if flat.length() < 1.0:
			flat = flat.normalized()
			p.x = flat.x * BODY_RADII.x
			p.z = BODY_CENTER_Z + flat.y * BODY_RADII.y
	return p


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


static func _band(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array, ca: Color, cb: Color) -> void:
	for k in SIDES:
		var k2 := (k + 1) % SIDES
		st.set_color(ca)
		st.add_vertex(a[k])
		st.set_color(cb)
		st.add_vertex(b[k])
		st.add_vertex(b[k2])
		st.set_color(ca)
		st.add_vertex(a[k])
		st.set_color(cb)
		st.add_vertex(b[k2])
		st.set_color(ca)
		st.add_vertex(a[k2])
