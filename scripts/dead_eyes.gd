class_name DeadEyes
## The eyes of a dead person, cartoon style: each eye is shut under a lid of
## skin and marked with a small red cross. Fallen bandits wear them until
## their face rots away (see Corpse), and so does a fallen hero until they
## rise again. Animals and monsters keep their own eyes.
##
## All the adventurer models (Rogue, Barbarian, Knight, Mage) share one head
## mesh, so the eyes sit in the same place on each (BodyLook.EYE_CENTRE, in
## the head mesh's space). The crosses follow the lids' curve.

const NAME := "DeadEyes"
## A deep red that reads on pale skin and in the dark alike.
const RED := Color(0.86, 0.05, 0.04)
## Half the length of a cross arm, across and up the face.
const ARM := 0.05
## How thick a cross arm is.
const THICK := 0.016
## A lid is a squashed ball, a little taller than the eye and deep enough to
## cover it (like the hero's sleeping lids).
const LID_RADIUS := 0.08
const LID_SCALE := Vector3(1.0, 1.15, 0.75)
const SKIN := Color8(246, 192, 156)


## Shuts the eyes of `model` and marks them with red crosses. `rot` is laid
## over the lids (a corpse's darkening), so the skin rots with the face while
## the crosses stay red. Returns the holder, or null for a model without a
## human head. Doing it twice changes nothing.
static func put_on(model: Node3D, rot: Material = null) -> Node3D:
	var have := on(model)
	if have != null:
		return have
	var head := _head(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null or head.skin == null:
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
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	skin.roughness = 0.95
	var lid_mesh := SphereMesh.new()
	lid_mesh.radius = LID_RADIUS
	lid_mesh.height = LID_RADIUS * 2.0
	lid_mesh.radial_segments = 24
	lid_mesh.rings = 12
	var segments := []
	for side: float in [-1.0, 1.0]:
		var centre := Vector3(BodyLook.EYE_CENTRE.x * side, BodyLook.EYE_CENTRE.y, BodyLook.EYE_CENTRE.z)
		var lid := MeshInstance3D.new()
		lid.mesh = lid_mesh
		lid.material_override = skin
		lid.material_overlay = rot
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lid.position = centre
		lid.scale = LID_SCALE
		holder.add_child(lid)
		# Two strokes corner to corner, each in a few pieces that follow the
		# lid's rounded surface (the arms stay well inside its rim).
		for diagonal: float in [-1.0, 1.0]:
			var points := []
			for k in 7:
				var t := lerpf(-1.0, 1.0, k / 6.0)
				var x := centre.x + t * ARM
				var y := centre.y + t * ARM * diagonal
				points.append(Vector3(x, y, _surface(centre, x, y)))
			for k in points.size() - 1:
				segments.append([points[k], points[k + 1]])
	var red := StandardMaterial3D.new()
	# Unshaded, so the cross stays red in a dark dungeon and on a rotting face.
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.albedo_color = RED
	# The cord's faces do not all wind one way: show both sides.
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crosses := MeshInstance3D.new()
	crosses.name = "Crosses"
	crosses.mesh = Effects.cord_mesh(segments, THICK, red)
	crosses.material_override = red
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


## Fades the red crosses out (0 gone, 1 full), as the face rots away.
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


## How far forward the lid reaches at (x, y), a little above its surface so
## the cross never dips into the ball's flat facets.
static func _surface(centre: Vector3, x: float, y: float) -> float:
	var u := (x - centre.x) / (LID_RADIUS * LID_SCALE.x)
	var v := (y - centre.y) / (LID_RADIUS * LID_SCALE.y)
	return centre.z + LID_RADIUS * LID_SCALE.z * sqrt(maxf(0.0, 1.0 - u * u - v * v)) + 0.008
