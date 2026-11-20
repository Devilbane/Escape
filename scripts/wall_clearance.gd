class_name WallClearance
extends RefCounted
## Keeps the hero's drawn body and gear out of walls. The collision capsule (Player.radius)
## is thinner than what is drawn: the head and a hat, the shoulders, a cape, a swollen belly,
## a shield or an axe in hand reach up to a metre or more from the body's middle, and a
## running hero leans the head forward. Rather than a fatter capsule, which would no longer
## fit through a doorway, the model is drawn back from any wall that a part of it would sink
## into, a little each physics tick. The body itself walks where it always did, so doorways
## and narrow ways stay as passable as before; in a gap too narrow for the gear, the pushes
## from both sides even out.
##
## Each tick the reach of the current pose is taken from probe points: for every bone of the
## skinned body, the farthest points of the vertices that hang on it (in the bone's own space,
## so they follow the bone however it turns), and the corners of every mesh worn on a bone
## (hats, hair, cape, held weapon and shield). In each height band a ray is cast in each of
## DIRECTIONS directions as far as the farthest probe reaches that way; where it meets a
## wall, the band's farthest probe straight at the wall gives how deep it would sink.

## Directions round the hero, and the height bands above the feet (m) they are cast in.
const DIRECTIONS := 8
const BANDS := [Vector2(0.25, 0.95), Vector2(0.95, 1.6), Vector2(1.6, 3.0)]
## Air kept between the drawn hero and the wall.
const MARGIN := 0.03
## Only faces this close to upright count as walls: floors, ramps and stairs do not push.
const WALL_NORMAL_Y := 0.45
## The furthest the model is drawn back from the body, and how quickly it eases there.
const MAX_SHIFT := 0.75
const EASE := 18.0

## The twelve edges of a box, by the corner numbers of AABB.get_endpoint.
const BOX_EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]

## Per mesh: bone index -> its farthest points in the bone's space (see _bone_points).
static var _cache := {}

## How far round the hero to look for walls before probing: further than any gear reaches.
const NEAR := 1.6

var shift := Vector3.ZERO
var _near_shape: CylinderShape3D


## One physics tick: eases `pivot` (between `body`, the hero, and its `model`) back from
## the walls, or home again when `active` is false (seated, lying, climbing, dead).
func tick(body: Node3D, pivot: Node3D, model: Node3D, delta: float, active: bool) -> void:
	var wanted := push_of(body, model) if active and body.is_inside_tree() and _walls_near(body) else Vector3.ZERO
	shift = shift.lerp(wanted, 1.0 - exp(-EASE * delta))
	if shift.length_squared() < 1e-6 and wanted == Vector3.ZERO:
		shift = Vector3.ZERO
	# The shift is in the world's directions; the pivot sits in the body's space.
	var local := body.global_basis.inverse() * shift
	pivot.position = Vector3(local.x, 0.0, local.z)


## Whether anything solid stands within reach of the hero above their feet: out in the
## open the probes are not needed.
func _walls_near(body: Node3D) -> bool:
	if _near_shape == null:
		_near_shape = CylinderShape3D.new()
		_near_shape.radius = NEAR
		_near_shape.height = BANDS[-1].y - BANDS[0].x
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _near_shape
	query.transform = Transform3D(Basis(), body.global_position + Vector3(0, (BANDS[0].x + BANDS[-1].y) * 0.5, 0))
	if body is CollisionObject3D:
		query.exclude = [(body as CollisionObject3D).get_rid()]
	for hit in body.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider is StaticBody3D:
			return true
	return false


## The push (world, horizontal) that takes the drawn hero out of every wall around them.
func push_of(body: Node3D, model: Node3D) -> Vector3:
	var bands := band_points(body, model)
	var space := body.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if body is CollisionObject3D:
		exclude.append((body as CollisionObject3D).get_rid())
	# The deepest sinking per wall face, so that two rays into one wall do not count twice.
	var deepest := {}
	var normals := {}
	for b in bands.size():
		var points: PackedVector3Array = bands[b]
		if points.is_empty():
			continue
		var height := clampf(_middle_height(points), BANDS[b].x + 0.05, BANDS[b].y - 0.05)
		var from := body.global_position + Vector3(0, height, 0)
		for d in DIRECTIONS:
			var dir := _direction(d)
			var reach := _extent(points, dir)
			if reach <= 0.0:
				continue
			var query := PhysicsRayQueryParameters3D.create(from, from + dir * (reach + MARGIN))
			query.exclude = exclude
			var hit := space.intersect_ray(query)
			if hit.is_empty() or not hit.collider is StaticBody3D:
				continue
			var n: Vector3 = hit.normal
			if absf(n.y) > WALL_NORMAL_Y:
				continue
			n = Vector3(n.x, 0, n.z).normalized()
			# How far the farthest part of this band sinks past the wall's face, measured
			# straight at the wall.
			var face: float = (hit.position - from).dot(-n)
			var depth: float = _extent(points, -n) + MARGIN - face
			if depth <= 0.0:
				continue
			var key := Vector3i(roundi(n.x * 8.0), 0, roundi(n.z * 8.0))
			if depth > deepest.get(key, 0.0):
				deepest[key] = depth
				normals[key] = n
	var push := Vector3.ZERO
	for key in deepest:
		push += normals[key] * deepest[key]
	return push.limit_length(MAX_SHIFT)


## The probe points in each height band (see BANDS), relative to the body's feet, in the
## world's directions, without the shift itself: the reach of the hero standing where the
## body stands.
func band_points(body: Node3D, model: Node3D) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	for i in BANDS.size():
		out.append(PackedVector3Array())
	var feet := body.global_position + shift
	for p in probe_points(model):
		var q := p - feet
		for i in BANDS.size():
			if q.y >= BANDS[i].x and q.y < BANDS[i].y:
				out[i].append(q)
				break
	return out


## How far `points` reach along the horizontal direction `dir`.
static func _extent(points: PackedVector3Array, dir: Vector3) -> float:
	var most := -1e9
	for q in points:
		most = maxf(most, q.x * dir.x + q.z * dir.z)
	return most


static func _middle_height(points: PackedVector3Array) -> float:
	var low := 1e9
	var high := -1e9
	for q in points:
		low = minf(low, q.y)
		high = maxf(high, q.y)
	return (low + high) * 0.5


## The probe points of `model` as drawn now, in world space.
static func probe_points(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null or not _shown_in(mesh_inst, model):
			continue
		var sk := mesh_inst.get_node_or_null(mesh_inst.skeleton) as Skeleton3D if mesh_inst.skin != null else null
		if sk != null:
			var bones := _bone_points(mesh_inst, sk)
			for bone in bones:
				var at := sk.global_transform * sk.get_bone_global_pose(bone)
				for p in bones[bone]:
					out.append(at * p)
		else:
			# The corners of its box, and points along the edges between them: a tilted box
			# (a cape hanging from the shoulders) reaches out at every height between them.
			var box := mesh_inst.get_aabb()
			var t := mesh_inst.global_transform
			var corners: Array[Vector3] = []
			for c in 8:
				corners.append(t * box.get_endpoint(c))
			out.append_array(corners)
			for e in BOX_EDGES:
				out.append((corners[e[0]] + corners[e[1]]) * 0.5)
	return out


## The farthest points of the vertices of `mi` that hang mostly on each bone, in that
## bone's space: the six ends along its axes and the eight diagonal corners. Kept per
## mesh, as the bind pose never changes (a swollen belly is a mesh of its own).
static func _bone_points(mi: MeshInstance3D, sk: Skeleton3D) -> Dictionary:
	var key := mi.mesh.get_rid()
	if _cache.has(key):
		return _cache[key]
	var dirs: Array[Vector3] = []
	for v in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		dirs.append(v)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				dirs.append(Vector3(x, y, z).normalized())
	var best := {}
	for surface in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or points.is_empty():
			continue
		var per: int = bones.size() / points.size()
		for i in points.size():
			var top := -1
			var heaviest := 0.0
			for k in per:
				var w: float = weights[i * per + k]
				if w > heaviest:
					heaviest = w
					top = bones[i * per + k]
			if top < 0:
				continue
			var bone := mi.skin.get_bind_bone(top)
			if bone < 0:
				bone = sk.find_bone(mi.skin.get_bind_name(top))
			if bone < 0:
				continue
			var p := mi.skin.get_bind_pose(top) * points[i]
			if not best.has(bone):
				var fresh := []
				for d in dirs.size():
					fresh.append([-1e9, p])
				best[bone] = fresh
			var slots: Array = best[bone]
			for d in dirs.size():
				var s := p.dot(dirs[d])
				if s > slots[d][0]:
					slots[d] = [s, p]
	var out := {}
	for bone in best:
		var pts := PackedVector3Array()
		for slot in best[bone]:
			if not pts.has(slot[1]):
				pts.append(slot[1])
		out[bone] = pts
	_cache[key] = out
	return out


## Whether `node` is drawn as part of `model`. The model as a whole may blink (a hero
## just hit), which does not take the parts out of the wall.
static func _shown_in(node: Node, model: Node3D) -> bool:
	while node != null and node != model:
		if node is Node3D and not (node as Node3D).visible:
			return false
		node = node.get_parent()
	return true


static func _direction(d: int) -> Vector3:
	var a := TAU * d / DIRECTIONS
	return Vector3(sin(a), 0, cos(a))
