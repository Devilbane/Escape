class_name DeadEyes
## The eyes of a dead person, cartoon style: each eye is painted over in
## skin and marked with a small black cross. Fallen bandits wear them until
## their face rots away (see Corpse), and so does a fallen hero until they
## rise again. Animals and monsters keep their own eyes.
##
## All the adventurer models (Rogue, Barbarian, Knight, Mage) share one head
## mesh and one texture layout: the eyes are little bumps of the head mesh
## painted dark in the texture (EYE_UV). A copy of those bumps in plain skin,
## a hair in front of them, hides the eyes; the crosses lie on that copy.

const NAME := "DeadEyes"
## Black, like a cartoon's inked cross.
const INK := Color(0.03, 0.025, 0.025)
## Half the length of a cross arm, across and up the face.
const ARM := 0.045
## How thick a cross arm is.
const THICK := 0.014
## The skin of the head texture, around the eyes.
const SKIN := Color8(246, 192, 156)
## Where the eyes are painted in the head texture (u from, v from, size).
const EYE_UV := Rect2(0.28, 0.04, 0.04, 0.085)
## How far in front of the eye the skin and the crosses lie.
const SKIN_LIFT := 0.002
const INK_LIFT := 0.008


## Covers the eyes of `model` in skin and marks them with black crosses.
## `rot` is laid over the skin (a corpse's darkening), so it rots with the
## face. Returns the holder, or null for a model without a human head. Doing
## it twice changes nothing.
static func put_on(model: Node3D, rot: Material = null) -> Node3D:
	var have := on(model)
	if have != null:
		return have
	var head := _head(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null or head.skin == null:
		return null
	var eyes := _eye_triangles(head.mesh)
	if eyes.is_empty():
		return null
	# The eyes are part of the head mesh, skinned to the head bone: work in
	# mesh space and carry it over into that bone's space.
	var bind := Transform3D.IDENTITY
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			bind = head.skin.get_bind_pose(i)
	var slot := BoneAttachment3D.new()
	slot.name = NAME
	slot.bone_name = "head"
	skeleton.add_child(slot)
	var holder := Node3D.new()
	holder.transform = bind
	slot.add_child(holder)
	# The eye bumps again, in skin: the eyes are gone, their shape stays.
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	skin.roughness = 0.95
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in eyes:
		for k in 3:
			st.set_normal(tri[3 + k])
			st.add_vertex(tri[k] + tri[3 + k] * SKIN_LIFT)
	var lids := MeshInstance3D.new()
	lids.name = "Lids"
	lids.mesh = st.commit()
	lids.material_override = skin
	lids.material_overlay = rot
	lids.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(lids)
	# Two strokes corner to corner over each eye, in a few pieces that follow
	# the bump's curve.
	var segments := []
	for side: float in [-1.0, 1.0]:
		var centre := Vector3(BodyLook.EYE_CENTRE.x * side, BodyLook.EYE_CENTRE.y, BodyLook.EYE_CENTRE.z)
		for diagonal: float in [-1.0, 1.0]:
			var points := []
			for k in 7:
				var t := lerpf(-1.0, 1.0, k / 6.0)
				var x := centre.x + t * ARM
				var y := centre.y + t * ARM * diagonal
				points.append(Vector3(x, y, _front(eyes, x, y, centre.z) + INK_LIFT))
			for k in points.size() - 1:
				segments.append([points[k], points[k + 1]])
	var ink := StandardMaterial3D.new()
	# Unshaded, so the ink stays black whatever light falls on it.
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.albedo_color = INK
	# The cord's faces do not all wind one way: show both sides.
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crosses := MeshInstance3D.new()
	crosses.name = "Crosses"
	crosses.mesh = Effects.cord_mesh(segments, THICK, ink)
	crosses.material_override = ink
	crosses.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(crosses)
	return slot


## Opens the eyes again (a fallen hero rising).
static func take_off(model: Node3D) -> void:
	var have := on(model)
	if have != null:
		have.get_parent().remove_child(have)
		have.queue_free()


## The dead eyes on `model`, or null.
static func on(model: Node3D) -> Node3D:
	if model == null:
		return null
	return model.find_child(NAME, true, false) as Node3D


## Fades the crosses out (0 gone, 1 full), as the face rots away.
static func fade(model: Node3D, alpha: float) -> void:
	var have := on(model)
	if have == null:
		return
	var crosses := have.find_child("Crosses", true, false) as MeshInstance3D
	(crosses.material_override as StandardMaterial3D).albedo_color.a = alpha


## The head of an adventurer model (Rogue_Head, Knight_Head, ...).
static func _head(model: Node3D) -> MeshInstance3D:
	for mesh: MeshInstance3D in model.find_children("*_Head", "MeshInstance3D", true, false):
		return mesh
	return null


## The head mesh's triangles painted as eyes, each as [a, b, c, na, nb, nc]
## (corners and their normals, in mesh space).
static func _eye_triangles(mesh: Mesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.is_empty():
		index.resize(verts.size())
		for i in verts.size():
			index[i] = i
	var out := []
	for t in range(0, index.size() - 2, 3):
		var ids := [index[t], index[t + 1], index[t + 2]]
		if ids.all(func(i: int) -> bool: return EYE_UV.has_point(uvs[i])):
			out.append([verts[ids[0]], verts[ids[1]], verts[ids[2]], normals[ids[0]], normals[ids[1]], normals[ids[2]]])
	return out


## How far forward the eye bump reaches at (x, y): the front-most of its
## triangles over that point, or `fallback` beside them.
static func _front(eyes: Array, x: float, y: float, fallback: float) -> float:
	var best := -INF
	var p := Vector2(x, y)
	for tri: Array in eyes:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var v0 := Vector2(b.x - a.x, b.y - a.y)
		var v1 := Vector2(c.x - a.x, c.y - a.y)
		var v2 := p - Vector2(a.x, a.y)
		var den := v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-9:
			continue
		var s := (v2.x * v1.y - v1.x * v2.y) / den
		var r := (v0.x * v2.y - v2.x * v0.y) / den
		if s >= -0.01 and r >= -0.01 and s + r <= 1.02:
			best = maxf(best, a.z + s * (b.z - a.z) + r * (c.z - a.z))
	return best if best > -INF else fallback
