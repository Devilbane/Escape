class_name BodyLook
extends RefCounted
## The hero's body: male or female, for characters built on the Rogue model.
##
## The model comes as a man. The woman is cut from the same meshes, vertex
## by vertex, in the rest pose: the shoulders and the waist come in and the
## tunic rounds out over the chest, the arms and the legs are slimmer, and
## she is a little shorter. Her face is her own too: a narrower jaw and
## chin, larger eyes with lashes, a rosy mouth, and her hair falls to the
## shoulders at the back and the sides. The skinning stays as it is, so every
## animation, every hair style (see HairLook), hat, helmet and piece of
## armour fits both.
##
## A body is named by one of SEXES. Every reshaped mesh keeps the material
## of its source, so GearLook and the villagers' dyes work on it unchanged.

const SEXES := ["male", "female"]
const DEFAULT := "male"
## How tall the woman is next to the man.
const FEMALE_SCALE := 0.95

## The meshes that change shape.
const PARTS := ["Rogue_Body", "Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_LegLeft", "Rogue_LegRight", "Rogue_Head"]

## The torso's width, by height: (y, x factor, z factor). Shoulders, chest
## and waist come in; the belt and the hem stay nearly as they are.
const TORSO := [
	[0.40, 1.0, 1.0], [0.55, 0.95, 0.97], [0.78, 0.84, 0.9], [0.95, 0.9, 0.95], [1.12, 0.92, 0.95], [1.25, 0.9, 0.95],
]
## The bust: how far the tunic comes out, at what height, how far apart the
## two mounds sit and how wide each is. Each mound slopes gently up from the
## collarbone and rounds off more quickly underneath.
const BUST_OUT := 0.085
const BUST_HEIGHT := 0.98
const BUST_SIDE := 0.13
const BUST_WIDE := 0.085
const BUST_ABOVE := 0.1
const BUST_BELOW := 0.06
## The model's chest has only a few vertices, too few to round a bust: the
## triangles in this box (in the body mesh's space) are split into finer ones
## first, this many times over.
const CHEST_BOX := AABB(Vector3(-0.36, 0.8, 0.0), Vector3(0.72, 0.42, 0.5))
const CHEST_REFINE := 2
## Arms and legs: how slim, about their own axis.
const LIMB_SLIM := 0.9
const ARM_AXIS := Vector3(0.0, 1.107, 0.0)
const LEG_AXIS := Vector3(0.171, 0.0, 0.0)

## The eyes, in the head mesh's space (see Player's eyelids too).
const EYE_CENTRE := Vector3(0.207, 1.607, 0.41)
const EYE_GROW := 0.1
const EYE_REACH := 0.15
## The jaw: narrowed from this height downwards, most at the chin.
const JAW_TOP := 1.52
const JAW_NARROW := 0.86
## The hair: how far it grows down at the back, and how it flares out.
const HAIR_LONGER := 0.18
const HAIR_FLARE := 0.035
## The skin colour of the head texture and the mouth's own colour.
const LIP_COLOR := Color(0.78, 0.3, 0.32)
## Where the mouth sits: under the nose, on the front of the face.
const LIP_HEIGHT := 1.432
const LIP_FRONT := 0.428
const LASH_COLOR := Color(0.14, 0.07, 0.05)

## Female meshes by source mesh: built once.
static var _shaped := {}


## Gives a Rogue model a body. Call it before anything else dresses the
## model: the meshes are swapped for reshaped ones and keep their source in
## the "body_source" meta, so the look can change back and forth.
static func apply(model: Node3D, sex: String) -> void:
	sex = checked(sex)
	for part in PARTS:
		var mi := model.find_child(part, true, false) as MeshInstance3D
		if mi == null:
			continue
		if not mi.has_meta("body_source"):
			mi.set_meta("body_source", mi.mesh)
		var source: Mesh = mi.get_meta("body_source")
		mi.mesh = _female(part, source) if sex == "female" else source
		if part == "Rogue_Head":
			# The hair is cut from whichever head is worn (see HairLook).
			mi.set_meta("hair_source", mi.mesh)
	model.set_meta("sex", sex) # HairLook ties her hair in a knot.
	_face(model, sex == "female")


## The woman is a little shorter: the model's scale for a body.
static func scale_of(sex: String) -> float:
	return FEMALE_SCALE if checked(sex) == "female" else 1.0


## A valid body name; anything else is the man.
static func checked(sex) -> String:
	return sex if sex is String and sex in SEXES else DEFAULT


## Closed eyes hide the lashes (the lids have a lash line of their own).
static func blink(model: Node3D, closed: bool) -> void:
	var slot := HairLook.head_slot(model)
	if slot == null:
		return
	var lashes := slot.get_node_or_null("Lashes") as Node3D
	if lashes:
		lashes.visible = lashes.get_meta("wanted", false) and not closed


## The lashes and the mouth hang from the head bone, like the mohawk's crest;
## they are built once and shown for a woman only.
static func _face(model: Node3D, female: bool) -> void:
	var slot := HairLook.head_slot(model)
	if slot == null:
		return
	var head := model.find_child("Rogue_Head", true, false) as MeshInstance3D
	var lashes := slot.get_node_or_null("Lashes") as MeshInstance3D
	if lashes == null:
		var bind: Transform3D = slot.get_meta("bind")
		var verts: PackedVector3Array = _female("Rogue_Head", head.get_meta("body_source")).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		lashes = _lashes(verts)
		lashes.name = "Lashes"
		lashes.transform = bind
		slot.add_child(lashes)
		var lips := _lips()
		lips.name = "Lips"
		lips.transform = bind
		slot.add_child(lips)
	lashes.set_meta("wanted", female)
	lashes.visible = female
	slot.get_node("Lips").visible = female


## The reshaped mesh of a part.
static func _female(part: String, source: Mesh) -> Mesh:
	if _shaped.has(source):
		return _shaped[source]
	var arrays := source.surface_get_arrays(0)
	if part == "Rogue_Body":
		for i in CHEST_REFINE:
			arrays = _refined(arrays, CHEST_BOX)
	var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	for v in verts.size():
		var p := verts[v]
		match part:
			"Rogue_Body":
				normals[v] = _bust_normal(p, normals[v])
				p = _torso(p)
			"Rogue_ArmLeft", "Rogue_ArmRight":
				p = _slim(p, ARM_AXIS, Vector3(1.0, LIMB_SLIM, LIMB_SLIM))
			"Rogue_LegLeft", "Rogue_LegRight":
				p = _slim(p, LEG_AXIS * signf(p.x), Vector3(LIMB_SLIM, 1.0, LIMB_SLIM))
			"Rogue_Head":
				p = _head(p, HairLook.HAIR_UV.has_point(uvs[v]))
		verts[v] = p
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	# The normals stay the model's own: the changes are gentle, and its
	# smooth shading is what makes the round shapes look round. Normals
	# worked out afresh from the moved triangles give flat, bright facets.
	# Only the bust tilts them, by the slope of its own smooth shape.
	var flags := 0
	if source is ArrayMesh and (source as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, source.surface_get_material(0))
	_shaped[source] = mesh
	return mesh


## Shoulders, waist and bust of the torso.
static func _torso(p: Vector3) -> Vector3:
	var sx := 1.0
	var sz := 1.0
	for i in TORSO.size() - 1:
		var a: Array = TORSO[i]
		var b: Array = TORSO[i + 1]
		if p.y >= a[0] and p.y <= b[0]:
			var t := smoothstep(a[0], b[0], p.y)
			sx = lerpf(a[1], b[1], t)
			sz = lerpf(a[2], b[2], t)
	if p.y > TORSO[-1][0]:
		sx = TORSO[-1][1]
		sz = TORSO[-1][2]
	var q := Vector3(p.x * sx, p.y, p.z * sz)
	q.z += _bust(p)
	return q


## How far the bust brings the front of the torso out at a point (in the
## model's own shape, before the torso is narrowed): two soft mounds side by
## side. It depends on the position alone, so vertices that share a position
## (along the texture's seams) move together and no gap opens.
static func _bust(p: Vector3) -> float:
	if p.z <= 0.05:
		return 0.0
	var dy := p.y - BUST_HEIGHT
	var height := exp(-pow(dy / (BUST_ABOVE if dy > 0.0 else BUST_BELOW), 2.0))
	var side := exp(-pow((absf(p.x) - BUST_SIDE) / BUST_WIDE, 2.0))
	return BUST_OUT * height * side * smoothstep(0.05, 0.2, p.z)


## A front-facing normal tilted by the slope of the bust, so the mounds catch
## the light like the round shapes they are.
static func _bust_normal(p: Vector3, n: Vector3) -> Vector3:
	if n.z < 0.2:
		return n
	var e := 0.005
	var dx := (_bust(p + Vector3(e, 0, 0)) - _bust(p - Vector3(e, 0, 0))) / (2.0 * e)
	var dy := (_bust(p + Vector3(0, e, 0)) - _bust(p - Vector3(0, e, 0))) / (2.0 * e)
	if dx == 0.0 and dy == 0.0:
		return n
	return (n / n.z - Vector3(dx, dy, 0.0)).normalized()


## A copy of a mesh's arrays whose triangles inside a box are split in finer
## ones: every edge whose middle lies in the box gets a new vertex there, and
## each triangle is cut along its split edges, so no edge is split on one side
## and whole on the other. The new vertices take the middle of everything
## (position, normal, texture, skinning), so they follow every animation.
static func _refined(arrays: Array, box: AABB) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per := bones.size() / verts.size()
	# The edges to split, each named by its two vertices, lower first.
	var mids := {}
	for t in range(0, index.size(), 3):
		for k in 3:
			var a := index[t + k]
			var b := index[t + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not mids.has(key) and box.has_point((verts[a] + verts[b]) * 0.5):
				mids[key] = -1
	for key: Vector2i in mids:
		var a := key.x
		var b := key.y
		mids[key] = verts.size()
		verts.append((verts[a] + verts[b]) * 0.5)
		normals.append((normals[a] + normals[b]).normalized())
		uvs.append((uvs[a] + uvs[b]) * 0.5)
		if not tangents.is_empty():
			var tan := Vector3(tangents[a * 4] + tangents[b * 4], tangents[a * 4 + 1] + tangents[b * 4 + 1], tangents[a * 4 + 2] + tangents[b * 4 + 2]).normalized()
			tangents.append_array([tan.x, tan.y, tan.z, tangents[a * 4 + 3]])
		if per > 0:
			# Both ends' bones, half each; the strongest few are kept.
			var pull := {}
			for end in [a, b]:
				for j in per:
					var bone := bones[end * per + j]
					pull[bone] = pull.get(bone, 0.0) + weights[end * per + j] * 0.5
			var order := pull.keys()
			order.sort_custom(func(x, y): return pull[x] > pull[y])
			var total := 0.0
			for j in per:
				total += pull[order[j]] if j < order.size() else 0.0
			for j in per:
				bones.append(order[j] if j < order.size() else 0)
				weights.append(pull[order[j]] / total if j < order.size() and total > 0.0 else 0.0)
	var cut := PackedInt32Array()
	for t in range(0, index.size(), 3):
		var tri := [index[t], index[t + 1], index[t + 2]]
		var mid := []
		var count := 0
		for k in 3:
			var a: int = tri[k]
			var b: int = tri[(k + 1) % 3]
			mid.append(mids.get(Vector2i(mini(a, b), maxi(a, b)), -1))
			count += 1 if mid[k] >= 0 else 0
		# Turn the triangle so its split edges come first.
		var turn := 0
		if count == 1:
			turn = mid.find(mid.filter(func(m): return m >= 0)[0])
		elif count == 2:
			turn = (mid.find(-1) + 1) % 3
		tri = [tri[turn], tri[(turn + 1) % 3], tri[(turn + 2) % 3]]
		mid = [mid[turn], mid[(turn + 1) % 3], mid[(turn + 2) % 3]]
		match count:
			0:
				cut.append_array(tri)
			1:
				cut.append_array([tri[0], mid[0], tri[2], mid[0], tri[1], tri[2]])
			2:
				cut.append_array([mid[0], tri[1], mid[1], tri[0], mid[0], mid[1], tri[0], mid[1], tri[2]])
			3:
				cut.append_array([tri[0], mid[0], mid[2], mid[0], tri[1], mid[1], mid[2], mid[1], tri[2], mid[0], mid[1], mid[2]])
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	if not tangents.is_empty():
		out[Mesh.ARRAY_TANGENT] = tangents
	if per > 0:
		out[Mesh.ARRAY_BONES] = bones
		out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_INDEX] = cut
	return out


## Pulls a limb in towards its own axis.
static func _slim(p: Vector3, axis: Vector3, factor: Vector3) -> Vector3:
	return axis + (p - axis) * factor


## A narrower jaw, larger eyes and longer hair.
static func _head(p: Vector3, hair: bool) -> Vector3:
	var q := p
	if hair:
		# The back and the sides grow down to the shoulders and flare out a
		# little; the fringe at the front stays.
		var down := smoothstep(1.62, 1.2, p.y) * smoothstep(0.25, -0.05, p.z)
		var out := Vector2(p.x - HairLook.SKULL_CENTER.x, p.z - HairLook.SKULL_CENTER.z).normalized()
		q.y -= HAIR_LONGER * down
		q.x += out.x * HAIR_FLARE * down
		q.z += out.y * HAIR_FLARE * down
	else:
		var narrow := lerpf(1.0, JAW_NARROW, smoothstep(JAW_TOP, JAW_TOP - 0.28, p.y))
		q.x *= narrow
		q.z = HairLook.SKULL_CENTER.z + (p.z - HairLook.SKULL_CENTER.z) * lerpf(1.0, 0.96, (1.0 - narrow) / (1.0 - JAW_NARROW))
	for side: float in [-1.0, 1.0]:
		var centre := Vector3(EYE_CENTRE.x * side, EYE_CENTRE.y, EYE_CENTRE.z)
		var d := p.distance_to(centre)
		if d < EYE_REACH:
			q += (p - centre) * EYE_GROW * smoothstep(EYE_REACH, 0.0, d)
	return q


## The face's surface in front of a point: the furthest forward vertex near
## it, so lashes and lips sit on the skin wherever the face curves.
static func _surface_z(verts: PackedVector3Array, x: float, y: float, reach := 0.07) -> float:
	var best := -INF
	for v in verts:
		if absf(v.x - x) < reach and absf(v.y - y) < reach:
			best = maxf(best, v.z)
	return best if best > -INF else EYE_CENTRE.z


## Dark lashes along the upper edge of each eye, with a flick at the outer corner.
static func _lashes(verts: PackedVector3Array) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LASH_COLOR
	mat.roughness = 1.0
	var segments := []
	var rx := 0.0635 * (1.0 + EYE_GROW) + 0.012
	var ry := 0.0635 * (1.0 + EYE_GROW) + 0.01
	for side: float in [-1.0, 1.0]:
		var cx := EYE_CENTRE.x * side
		var points := []
		for k in 11:
			var a := lerpf(PI * 0.12, PI * 0.88, k / 10.0)
			var x := cx + cos(a) * rx * side
			var y := EYE_CENTRE.y + sin(a) * ry
			points.append(Vector3(x, y, _surface_z(verts, x, y) + 0.008))
		for k in points.size() - 1:
			segments.append([points[k], points[k + 1]])
		# Three short strokes sweeping up and out at the outer corner.
		for k in 3:
			var a := lerpf(PI * 0.14, PI * 0.34, k / 2.0)
			var from := Vector3(cx + cos(a) * rx * side, EYE_CENTRE.y + sin(a) * ry, 0.0)
			from.z = _surface_z(verts, from.x, from.y) + 0.008
			var to := from + Vector3(cos(a - 0.3) * side, sin(a + 0.2), 0.0).normalized() * 0.032
			to.z = from.z - 0.004
			segments.append([from, to])
	var lashes := MeshInstance3D.new()
	lashes.mesh = Effects.cord_mesh(segments, 0.011, mat)
	lashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lashes


## A small rosy mouth under the nose, a touch fuller in the middle.
static func _lips() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LIP_COLOR
	mat.roughness = 0.6
	var segments := []
	var y := LIP_HEIGHT
	var points := []
	for k in 9:
		var t := k / 8.0
		var x := lerpf(-0.07, 0.07, t)
		# The corners turn up a little: a quiet smile.
		var py := y + 0.012 * pow(absf(x) / 0.07, 2.0)
		# The face is nearly flat here, just under the nose, and curves back
		# a touch towards the corners of the mouth.
		points.append(Vector3(x, py, LIP_FRONT - 0.8 * x * x))
	for k in points.size() - 1:
		segments.append([points[k], points[k + 1]])
	var lips := MeshInstance3D.new()
	lips.mesh = Effects.cord_mesh(segments, 0.016, mat)
	lips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lips
