class_name StoneLook
## The natural stonework of every stone wall (shaders/masonry.gdshaderinc): the
## village's buildings (AgedStone), the hero's houses, garden and cellar walls
## (HouseLooks) and the dungeon walls (Level). Stones of differing size are laid
## in courses of differing height, with rounded corners, and the hard outer edges
## of a building are rounded off.
##
## The rounding is in the light, not the outline: edge_data() writes into each
## mesh how far its triangles lie from the outer edges near them (CUSTOM0), and
## the shader bends the normal towards an edge as it nears, so the edge catches
## the light like a rounded one.

## The looks to choose from (STYLE picks one): how high a course of stones stands
## (metres), how rough the stone is (0 tidy cut stone, 1 rough field stone), and
## how round the edges of a building are (metres). "old" is the look before: the
## kit's trim sheet of even blocks and hard edges.
const STYLES := {
	"old": {"masonry": 0.0, "course": 0.3, "irregular": 0.0, "edge": 0.0},
	"dressed": {"masonry": 1.0, "course": 0.3, "irregular": 0.15, "edge": 0.12},
	"rustic": {"masonry": 1.0, "course": 0.26, "irregular": 0.7, "edge": 0.22},
}
const STYLE := "dressed"

## The widest an edge is ever rounded (metres): how far edge_data looks for edges.
const REACH := 0.35
## Two faces meeting at more than this (degrees) make a hard edge.
const SHARP := 25.0
## How many edges a triangle keeps (the four floats of CUSTOM0), and the distance
## written into an unused slot.
const SLOTS := 4
const FAR := 1000.0

## The look in use; screenshots set it from the STONE_STYLE environment variable.
static var style := ""
static var _rounded := {}


static func settings() -> Dictionary:
	if style == "":
		var asked := OS.get_environment("STONE_STYLE")
		style = asked if STYLES.has(asked) else STYLE
	return STYLES[style]


## Sets the stonework's shader parameters on a material made with masonry.
static func apply(mat: ShaderMaterial) -> void:
	var s := settings()
	mat.set_shader_parameter("masonry", s["masonry"])
	mat.set_shader_parameter("course", s["course"])
	mat.set_shader_parameter("irregular", s["irregular"])
	mat.set_shader_parameter("edge_round", s["edge"])


## The format flag for CUSTOM0 holding four floats.
static func custom_format() -> int:
	return Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT


## A copy of `mesh` whose triangles carry the distances to their rounded edges in
## CUSTOM0, one surface per surface of the mesh. With `shared`, it is made once
## per mesh and kept (for a model placed many times); a mesh built for one house
## is not kept.
static func rounded_mesh(mesh: Mesh, shared := true) -> Mesh:
	if mesh == null:
		return mesh
	var key := mesh.get_instance_id()
	if shared and _rounded.has(key):
		return _rounded[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var mat := mesh.surface_get_material(s)
		var kind := Mesh.PRIMITIVE_TRIANGLES if mesh is PrimitiveMesh else (mesh as ArrayMesh).surface_get_primitive_type(s)
		if kind != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_BONES] != null:
			out.add_surface_from_arrays(kind, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mat)
			continue
		var flat := unindexed(arrays)
		flat[Mesh.ARRAY_CUSTOM0] = edge_data(flat[Mesh.ARRAY_VERTEX])
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat, [], {}, custom_format())
		out.surface_set_material(out.get_surface_count() - 1, mat)
	if mesh is ArrayMesh:
		out.resource_name = mesh.resource_name
	if shared:
		_rounded[key] = out
	return out


## A box `size` big with its outer edges rounded off (see rounded_mesh), made once
## per size and shared. The edges round the faces facing one of `hidden` stay
## sharp: those faces lie against the next wall piece or the ground, and a rounded
## edge there would show as a groove between two pieces.
static func rounded_box(size: Vector3, hidden: Array = []) -> Mesh:
	var key := "box_%.3f_%.3f_%.3f_%s" % [size.x, size.y, size.z, str(hidden)]
	if not _rounded.has(key):
		var box := BoxMesh.new()
		box.size = size
		var out := ArrayMesh.new()
		var flat := unindexed(box.surface_get_arrays(0))
		flat[Mesh.ARRAY_CUSTOM0] = edge_data(flat[Mesh.ARRAY_VERTEX], hidden)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat, [], {}, custom_format())
		_rounded[key] = out
	return _rounded[key]


## A surface's arrays with every triangle on its own three vertices (no index).
static func unindexed(arrays: Array) -> Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var flat := []
	flat.resize(Mesh.ARRAY_MAX)
	if idx.is_empty():
		for i in Mesh.ARRAY_MAX:
			if i != Mesh.ARRAY_CUSTOM0 and i != Mesh.ARRAY_BONES and i != Mesh.ARRAY_WEIGHTS:
				flat[i] = arrays[i]
		return flat
	var count := idx.size()
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
		if arrays[slot] != null:
			var src: PackedVector3Array = arrays[slot]
			var dst := PackedVector3Array()
			dst.resize(count)
			for i in count:
				dst[i] = src[idx[i]]
			flat[slot] = dst
	for slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[slot] != null:
			var src2: PackedVector2Array = arrays[slot]
			var dst2 := PackedVector2Array()
			dst2.resize(count)
			for i in count:
				dst2[i] = src2[idx[i]]
			flat[slot] = dst2
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tan: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var t2 := PackedFloat32Array()
		t2.resize(count * 4)
		for i in count:
			for k in 4:
				t2[i * 4 + k] = tan[idx[i] * 4 + k]
		flat[Mesh.ARRAY_TANGENT] = t2
	if arrays[Mesh.ARRAY_COLOR] != null:
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var c2 := PackedColorArray()
		c2.resize(count)
		for i in count:
			c2[i] = cols[idx[i]]
		flat[Mesh.ARRAY_COLOR] = c2
	return flat


## For a list of triangles (three vertices each, no index): at every vertex, its
## distance (metres, in the triangle's plane) to each of the up to SLOTS outer
## edges nearest its triangle, four floats per vertex (CUSTOM0). An outer edge is
## where two faces meet at more than SHARP degrees and the corner sticks out (a
## building's corner, the top of a wall); edges in a hollow stay sharp.
## The edges of faces facing one of `hidden` (unit vectors) stay sharp.
static func edge_data(pos: PackedVector3Array, hidden: Array = []) -> PackedFloat32Array:
	var tris := pos.size() / 3
	var out := PackedFloat32Array()
	out.resize(tris * 3 * SLOTS)
	out.fill(FAR)
	var normals := PackedVector3Array()
	normals.resize(tris)
	for t in tris:
		normals[t] = (pos[t * 3 + 2] - pos[t * 3]).cross(pos[t * 3 + 1] - pos[t * 3]).normalized()
	# The triangles on each edge, found by the edge's two ends.
	var edges := {}
	for t in tris:
		if normals[t] == Vector3.ZERO:
			continue
		for k in 3:
			var a := pos[t * 3 + k]
			var b := pos[t * 3 + (k + 1) % 3]
			var key := _edge_key(a, b)
			if not edges.has(key):
				edges[key] = [a, b, []]
			(edges[key][2] as Array).append(t)
	# The outer edges, kept with the plane of each face beside them.
	var cos_sharp := cos(deg_to_rad(SHARP))
	var by_plane := {}
	for key: String in edges:
		var e: Array = edges[key]
		var on: Array = e[2]
		if on.size() != 2:
			continue
		var t1: int = on[0]
		var t2: int = on[1]
		if normals[t1].dot(normals[t2]) > cos_sharp:
			continue
		if _faces_one(normals[t1], hidden) or _faces_one(normals[t2], hidden):
			continue
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		# It sticks out where each face lies behind the other's front.
		if (_centre(pos, t2) - a).dot(normals[t1]) > -0.001 or (_centre(pos, t1) - a).dot(normals[t2]) > -0.001:
			continue
		for t: int in [t1, t2]:
			var along := (b - a).normalized()
			var inward := normals[t].cross(along).normalized()
			if (_centre(pos, t) - a).dot(inward) < 0.0:
				inward = -inward
			var plane := _plane_key(normals[t], a)
			if not by_plane.has(plane):
				by_plane[plane] = []
			(by_plane[plane] as Array).append([a, b, inward])
	# Each triangle takes the outer edges of its own plane that come within REACH.
	for t in tris:
		if normals[t] == Vector3.ZERO:
			continue
		var plane := _plane_key(normals[t], pos[t * 3])
		if not by_plane.has(plane):
			continue
		var near := []
		for e: Array in by_plane[plane]:
			var gap := _gap(pos, t, e[0], e[1])
			if gap < REACH:
				near.append([gap, e])
		if near.is_empty():
			continue
		near.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		for slot in mini(near.size(), SLOTS):
			var e: Array = near[slot][1]
			for k in 3:
				out[(t * 3 + k) * SLOTS + slot] = (pos[t * 3 + k] - (e[0] as Vector3)).dot(e[2])
	return out


static func _faces_one(n: Vector3, hidden: Array) -> bool:
	for h: Vector3 in hidden:
		if n.dot(h) > 0.99:
			return true
	return false


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var qa := Vector3i((a * 1000.0).round())
	var qb := Vector3i((b * 1000.0).round())
	if qa.x > qb.x or (qa.x == qb.x and (qa.y > qb.y or (qa.y == qb.y and qa.z > qb.z))):
		var s := qa
		qa = qb
		qb = s
	return "%d,%d,%d,%d,%d,%d" % [qa.x, qa.y, qa.z, qb.x, qb.y, qb.z]


static func _plane_key(n: Vector3, p: Vector3) -> String:
	var q := Vector3i((n * 50.0).round())
	return "%d,%d,%d,%d" % [q.x, q.y, q.z, roundi(n.dot(p) * 100.0)]


static func _centre(pos: PackedVector3Array, t: int) -> Vector3:
	return (pos[t * 3] + pos[t * 3 + 1] + pos[t * 3 + 2]) / 3.0


## How near (metres) the edge from a to b comes to triangle t.
static func _gap(pos: PackedVector3Array, t: int, a: Vector3, b: Vector3) -> float:
	var best := INF
	for i in 9:
		var p := a.lerp(b, i / 8.0)
		best = minf(best, p.distance_to(_closest_on_triangle(p, pos[t * 3], pos[t * 3 + 1], pos[t * 3 + 2])))
	return best


## The point of triangle abc nearest p (Ericson, Real-Time Collision Detection).
static func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
