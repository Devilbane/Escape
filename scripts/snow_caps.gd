class_name SnowCaps
extends RefCounted
## Snow with a body: thick caps on the roofs, ledges and window tops of a building, a rounded
## roll of snow that hangs over their open edges, and icicles under the eaves and the windows.
##
## The overlay (SnowCover) only paints surfaces; these caps are real geometry built once from a
## building's own triangles (see AgedStone.triangles). Every surface that faces the sky and is
## open above gets a slab, deep enough on a roof to bury the vines lying on it. Along each open
## edge of those surfaces runs a lumpy roll that sticks out past the edge, most of all at the
## eaves, where icicles of many lengths hang under it. Each vertex is stored on the surface it
## covers with the way to its full place (CUSTOM0, CUSTOM1 for the icicles), so the shaders grow
## the snow out of the roof as it deepens and let it sink back as it melts (snow_caps.gdshader,
## icicles.gdshader). Everything of a building is one mesh with two surfaces: one draw each.

const CAP_SHADER := preload("res://shaders/snow_caps.gdshader")
const ICE_SHADER := preload("res://shaders/icicles.gdshader")
const GROUP := "snow_caps"

## How deep the snow lies on a wide roof at full cover (metres). A narrow ledge holds less.
const DEEP := 0.22
## The least a ledge holds, so a window's top still wears a ridge of snow.
const SHALLOW := 0.07
## From how steep a surface no more snow stays on it (the y of its normal).
const STEEPEST := 0.42
## How far above the ground a surface must be to count (no caps on the doorstep or plinth).
const LOWEST := 0.6
## The length of one piece of a roll (metres) and the sides round it.
const ROLL_STEP := 0.22
const ROLL_SIDES := 8
## The gap between two icicles under the eaves, and their length.
const ICICLE_GAP := Vector2(0.12, 0.34)
const ICICLE_LONG := Vector2(0.07, 0.42)
## How thick an icicle is at its root.
const ICICLE_THICK := Vector2(0.018, 0.04)

static var _cap_mat: ShaderMaterial
static var _ice_mat: ShaderMaterial


## The shared material of the caps, and of the icicles.
static func cap_material() -> ShaderMaterial:
	if _cap_mat == null:
		_cap_mat = ShaderMaterial.new()
		_cap_mat.shader = CAP_SHADER
	return _cap_mat


static func ice_material() -> ShaderMaterial:
	if _ice_mat == null:
		_ice_mat = ShaderMaterial.new()
		_ice_mat.shader = ICE_SHADER
	return _ice_mat


## The caps shown in the world under `root`.
static func in_world(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root.is_inside_tree():
		for n in root.get_tree().get_nodes_in_group(GROUP):
			if root.is_ancestor_of(n):
				out.append(n)
	else:
		for n in root.find_children("*", "MeshInstance3D", true, false):
			if n.is_in_group(GROUP):
				out.append(n)
	return out


## Both materials, so SnowCover can tell them how much snow lies and where fires burn.
static func materials() -> Array[ShaderMaterial]:
	return [cap_material(), ice_material()]


## The node that shows a building's caps (hidden until snow lies, see SnowCover), or null.
static func node_for(mesh: ArrayMesh) -> MeshInstance3D:
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "SnowCaps"
	mi.mesh = mesh
	mi.set_meta("no_snow", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.add_to_group(GROUP)
	return mi


## The caps of one building from its triangles (world space, see AgedStone.triangles), its
## ground height and its windows: each {"top": where an icicle hangs from, "out": the way the
## window looks, "wide": how wide it is}. The mesh is moved by `shift` (into the level's own
## frame). Null when nothing on it faces the sky.
static func build(tris: Array, ground: float, windows: Array, rng: RandomNumberGenerator, shift := Vector3.ZERO) -> ArrayMesh:
	var tops := _open_tops(tris, ground)
	var caps := _Surface.new()
	var ice := _Surface.new()
	if not tops.is_empty():
		var edges := _open_edges(tops)
		var depth := _depths(tops)
		for t: Dictionary in tops:
			_slab(caps, t, depth)
		for e: Dictionary in edges:
			_roll(caps, ice, e, depth, rng)
	for w: Dictionary in windows:
		_window_icicles(ice, w, rng)
	if caps.empty() and ice.empty():
		return null
	var mesh := ArrayMesh.new()
	if not caps.empty():
		caps.commit(mesh, cap_material(), shift)
	if not ice.empty():
		ice.commit(mesh, ice_material(), shift)
	return mesh


## The windows of a building for `build`: those the house builder noted (pane centres and the
## way they face, the lintel half a metre over the pane), or else the panes found by the colour
## of their glass in the kit's palette (see AgedStone.window_panes).
static func windows_of(node: Node3D, tris: Array, window_uv: Vector2) -> Array:
	var out: Array = []
	var panes: Array = node.get_meta("windows", [])
	var outs: Array = node.get_meta("window_outs", [])
	if not panes.is_empty() and panes.size() == outs.size():
		var xf := node.global_transform
		for i in panes.size():
			var look: Vector3 = (xf.basis * (outs[i] as Vector3)).normalized()
			var at: Vector3 = xf * (panes[i] as Vector3)
			out.append({"top": at + look * 0.13 + Vector3.UP * 0.44, "out": look, "wide": 0.95})
		return out
	# Kit buildings: the pane triangles, grouped by where they lie.
	var groups: Array = []
	for t: Dictionary in tris:
		if not t.has("uv") or (t.uv as Vector2).distance_to(window_uv) > 0.03:
			continue
		var n: Vector3 = t.n
		if absf(n.y) > 0.4:
			continue
		var box := AABB(t.a, Vector3.ZERO).expand(t.b).expand(t.c)
		var joined := false
		for g: Dictionary in groups:
			if (g.box as AABB).grow(0.15).intersects(box) and (g.n as Vector3).dot(n) > 0.8:
				g.box = (g.box as AABB).merge(box)
				joined = true
				break
		if not joined:
			groups.append({"box": box, "n": Vector3(n.x, 0, n.z).normalized()})
	for g: Dictionary in groups:
		var box: AABB = g.box
		var look: Vector3 = g.n
		var side := Vector3.UP.cross(look)
		var wide := absf((box.size).dot(side))
		if wide < 0.25 or box.size.y < 0.25:
			continue
		var mid := box.get_center()
		out.append({"top": Vector3(mid.x, box.end.y, mid.z) + look * 0.06, "out": look, "wide": wide})
	return out


## The triangles that face the sky with nothing of the building over them, high enough off
## the ground: each with its points, normal, and how wide it is across (see _depths).
static func _open_tops(tris: Array, ground: float) -> Array:
	var ups: Array = []
	for t: Dictionary in tris:
		var n: Vector3 = t.n
		if n.y < STEEPEST or t.has("glass"):
			continue
		var a: Vector3 = t.a
		var b: Vector3 = t.b
		var c: Vector3 = t.c
		if minf(a.y, minf(b.y, c.y)) < ground + LOWEST:
			continue
		ups.append({"a": a, "b": b, "c": c, "n": n, "mid": (a + b + c) / 3.0, "area": t.area})
	var open: Array = []
	for t: Dictionary in ups:
		var mid: Vector3 = t.mid
		var covered := false
		for o: Dictionary in ups:
			if o == t or (o.mid as Vector3).y < mid.y + 0.25:
				continue
			var over := _height_over(o, mid)
			if not is_nan(over) and over > mid.y + 0.25:
				covered = true
				break
		if not covered:
			open.append(t)
	return open


## The height of triangle `t` straight over (or under) `p`, or NAN when `p` is not under it.
static func _height_over(t: Dictionary, p: Vector3) -> float:
	var a: Vector3 = t.a
	var b: Vector3 = t.b
	var c: Vector3 = t.c
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(p.x - a.x, p.z - a.z)
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 0.000001:
		return NAN
	var u := (v2.x * v1.y - v1.x * v2.y) / den
	var v := (v0.x * v2.y - v2.x * v0.y) / den
	if u < 0.0 or v < 0.0 or u + v > 1.0:
		return NAN
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)


static func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 50.0), roundi(p.y * 50.0), roundi(p.z * 50.0))


## The open edges of the tops: those that only one top has and with no other top just beyond
## them (a roof built of separate pieces has seams, which are not edges). Each edge knows its
## ends, the way out over it (level), and whether it is an eave (the roof falls away over it).
static func _open_edges(tops: Array) -> Array:
	var count := {}
	for t: Dictionary in tops:
		for pair: Array in [[t.a, t.b], [t.b, t.c], [t.c, t.a]]:
			var ka := _key(pair[0])
			var kb := _key(pair[1])
			var k := [ka, kb] if str(ka) < str(kb) else [kb, ka]
			count[k] = count.get(k, 0) + 1
	var edges: Array = []
	for t: Dictionary in tops:
		for pair: Array in [[t.a, t.b], [t.b, t.c], [t.c, t.a]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var ka := _key(a)
			var kb := _key(b)
			var k := [ka, kb] if str(ka) < str(kb) else [kb, ka]
			if count[k] > 1 or a.distance_to(b) < 0.08:
				continue
			var along := (b - a).normalized()
			var mid: Vector3 = (a + b) * 0.5
			var out := Vector3(along.z, 0, -along.x)
			if out.length() < 0.01:
				continue
			out = out.normalized()
			var inside := (t.mid as Vector3) - mid
			if Vector2(out.x, out.z).dot(Vector2(inside.x, inside.z)) > 0.0:
				out = -out
			# A seam: another top carries on just beyond.
			var beyond := mid + out * 0.12
			var seam := false
			for o: Dictionary in tops:
				if o == t:
					continue
				var h := _height_over(o, beyond)
				if not is_nan(h) and absf(h - mid.y) < 0.35:
					seam = true
					break
			if seam:
				continue
			var n: Vector3 = t.n
			# Across the top, how far it reaches from this edge (twice its area over the edge).
			var across: float = 2.0 * float(t.area) / a.distance_to(b)
			var eave: bool = Vector2(n.x, n.z).dot(Vector2(out.x, out.z)) > 0.25 and absf(a.y - b.y) < 0.2 * a.distance_to(b)
			edges.append({"a": a, "b": b, "out": out, "n": n, "across": across, "eave": eave})
	return edges


## How deep the snow lies at each corner of the tops: deep on a wide roof, less on a narrow
## ledge, and the same wherever two tops meet, so the slab has no steps.
static func _depths(tops: Array) -> Dictionary:
	var depth := {}
	for t: Dictionary in tops:
		var a: Vector3 = t.a
		var b: Vector3 = t.b
		var c: Vector3 = t.c
		var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
		var narrow: float = 2.0 * float(t.area) / maxf(longest, 0.01)
		var d := clampf(narrow * 0.6, SHALLOW, DEEP)
		for p: Vector3 in [a, b, c]:
			var k := _key(p)
			depth[k] = minf(depth.get(k, DEEP), d)
	return depth


## A little wobble of the snow's depth that is the same at a shared corner.
static func _wobble(p: Vector3) -> float:
	return 0.8 + 0.4 * fposmod(sin(p.x * 12.9898 + p.z * 78.233 + p.y * 37.719) * 43758.5453, 1.0)


## The slab over one top: its corners lifted straight up by the depth there.
static func _slab(s: _Surface, t: Dictionary, depth: Dictionary) -> void:
	var pts: Array[Vector3] = [t.a, t.b, t.c]
	var lifts: Array[Vector3] = []
	for p in pts:
		lifts.append(Vector3.UP * float(depth.get(_key(p), DEEP)) * _wobble(p))
	var full: Array[Vector3] = [pts[0] + lifts[0], pts[1] + lifts[1], pts[2] + lifts[2]]
	var n := (full[1] - full[0]).cross(full[2] - full[0]).normalized()
	if n.y < 0.0:
		n = -n
	var first := s.size()
	for i in 3:
		s.add(pts[i], n, lifts[i])
	s.tri(first, first + 1, first + 2)


## The roll of snow along one open edge: round, lumpy, a little thinner towards its ends, and
## leaning out over the edge, furthest at an eave. Icicles hang under an eave's roll.
static func _roll(s: _Surface, ice: _Surface, e: Dictionary, depth: Dictionary, rng: RandomNumberGenerator) -> void:
	var a: Vector3 = e.a
	var b: Vector3 = e.b
	var out: Vector3 = e.out
	var eave: bool = e.eave
	var length := a.distance_to(b)
	var along := (b - a) / length
	var deep := minf(float(depth.get(_key(a), DEEP)), float(depth.get(_key(b), DEEP)))
	var r := minf(deep * 0.62, float(e.across) * 0.45)
	if r < 0.02:
		return
	# The plane of the ring: out over the edge and up, square to the edge.
	var side := out - along * out.dot(along)
	side = side.normalized()
	var lift := along.cross(side).normalized()
	if lift.y < 0.0:
		lift = -lift
	var lean := r * (0.75 if eave else 0.3)
	var rise := deep * 0.5 - (r * 0.25 if eave else 0.0)
	var pieces := maxi(2, ceili(length / ROLL_STEP))
	var rings: Array[int] = []
	for i in pieces + 1:
		var f := float(i) / pieces
		var at := a.lerp(b, f)
		# Rounded ends, and lumps.
		var end := clampf(minf(f, 1.0 - f) * length / maxf(r * 1.6, 0.05), 0.0, 1.0)
		var radius := r * sqrt(end) * (0.85 + 0.3 * _wobble(at + Vector3(0.3, 0, 0.7)) - 0.15)
		var centre := side * lean + Vector3.UP * rise
		rings.append(s.size())
		for k in ROLL_SIDES:
			var ang := TAU * float(k) / ROLL_SIDES
			var dir := side * cos(ang) + lift * sin(ang)
			s.add(at, dir, centre + dir * radius)
	for i in pieces:
		for k in ROLL_SIDES:
			var k2 := (k + 1) % ROLL_SIDES
			s.quad(rings[i] + k, rings[i] + k2, rings[i + 1] + k2, rings[i + 1] + k)
	if not eave:
		return
	# Icicles under the roll, here and there, of many lengths.
	var spot := rng.randf_range(0.05, ICICLE_GAP.y)
	while spot < length - 0.05:
		if rng.randf() < 0.8:
			var at := a + along * spot
			var hang := side * (lean + r * 0.35) + Vector3.UP * (rise - r * 0.75)
			var long := rng.randf_range(ICICLE_LONG.x, ICICLE_LONG.y)
			if rng.randf() < 0.2:
				long *= 1.6
			_icicle(ice, at, hang, long, rng.randf_range(ICICLE_THICK.x, ICICLE_THICK.y), rng)
		spot += rng.randf_range(ICICLE_GAP.x, ICICLE_GAP.y)


## Icicles under a window's top, shorter than those of the eaves.
static func _window_icicles(ice: _Surface, w: Dictionary, rng: RandomNumberGenerator) -> void:
	var look: Vector3 = w.out
	var side := Vector3.UP.cross(look).normalized()
	var wide: float = w.wide
	var count := rng.randi_range(2, 5)
	for i in count:
		var at: Vector3 = (w.top as Vector3) + side * rng.randf_range(-0.45, 0.45) * wide
		var long := rng.randf_range(0.05, 0.24)
		_icicle(ice, at, Vector3.ZERO, long, rng.randf_range(0.012, 0.026), rng)


## One icicle hanging from `root`: it rides on the snow (`hang`, how far the snow carries its
## root out at full cover) and grows down to `long`, a thin cone with a slight bend.
static func _icicle(ice: _Surface, root: Vector3, hang: Vector3, long: float, thick: float, rng: RandomNumberGenerator) -> void:
	const SIDES := 5
	var bend := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12)) * long
	var levels := [[0.0, 1.0], [0.4, 0.55], [0.75, 0.25]]
	var turn := rng.randf() * TAU
	var rings: Array[int] = []
	for lv: Array in levels:
		var down: float = lv[0]
		var radius: float = thick * float(lv[1])
		var centre := Vector3.DOWN * long * down + bend * down * down
		rings.append(ice.size())
		for k in SIDES:
			var ang := turn + TAU * float(k) / SIDES
			var dir := Vector3(cos(ang), 0.25, sin(ang)).normalized()
			ice.add2(root, dir, hang, centre + Vector3(cos(ang), 0, sin(ang)) * radius)
	var tip := ice.size()
	ice.add2(root, Vector3.DOWN, hang, Vector3.DOWN * long + bend)
	for i in levels.size() - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			ice.quad(rings[i] + k, rings[i] + k2, rings[i + 1] + k2, rings[i + 1] + k)
	var last := rings[rings.size() - 1]
	for k in SIDES:
		ice.tri(last + k, last + (k + 1) % SIDES, tip)


## The arrays of one surface while it is built.
class _Surface:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var grow := PackedFloat32Array()
	var grow2 := PackedFloat32Array()
	var index := PackedInt32Array()
	var two := false

	func size() -> int:
		return verts.size()

	func empty() -> bool:
		return index.is_empty()

	## A vertex on the surface at `at`, pushed out by `push` at full cover.
	func add(at: Vector3, n: Vector3, push: Vector3) -> void:
		verts.append(at)
		normals.append(n)
		grow.append_array([push.x, push.y, push.z, 0.0])
		grow2.append_array([0.0, 0.0, 0.0, 0.0])

	## A vertex that rides on the snow (`push`) and grows on its own (`extra`, an icicle).
	func add2(at: Vector3, n: Vector3, push: Vector3, extra: Vector3) -> void:
		two = true
		verts.append(at)
		normals.append(n)
		grow.append_array([push.x, push.y, push.z, 0.0])
		grow2.append_array([extra.x, extra.y, extra.z, 0.0])

	func _full(i: int) -> Vector3:
		return verts[i] + Vector3(grow[i * 4], grow[i * 4 + 1], grow[i * 4 + 2]) \
				+ Vector3(grow2[i * 4], grow2[i * 4 + 1], grow2[i * 4 + 2])

	## A triangle, wound so its front faces the way its normals point (Godot's front faces
	## run clockwise).
	func tri(i0: int, i1: int, i2: int) -> void:
		var p0 := _full(i0)
		var cr := (_full(i1) - p0).cross(_full(i2) - p0)
		if cr.length_squared() < 1e-12:
			return
		if -cr.dot(normals[i0] + normals[i1] + normals[i2]) < 0.0:
			index.append_array([i0, i2, i1])
		else:
			index.append_array([i0, i1, i2])

	func quad(i0: int, i1: int, i2: int, i3: int) -> void:
		tri(i0, i1, i2)
		tri(i0, i2, i3)

	func commit(mesh: ArrayMesh, mat: Material, shift: Vector3) -> void:
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in verts.size():
			moved[i] = verts[i] + shift
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = moved
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_CUSTOM0] = grow
		arrays[Mesh.ARRAY_INDEX] = index
		var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if two:
			arrays[Mesh.ARRAY_CUSTOM1] = grow2
			flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
