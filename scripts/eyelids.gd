class_name EyeLids
extends RefCounted
## Closed eyes for sleeping: a skin-coloured lid over each eye with a dark, gently curved lash line, put on the head
## of a Rogue-based body (the hero, the climber on the wall). Built once per body, hidden until it sleeps.

## A lid is a squashed ball, a little taller than the eye and deep enough to cover the pupil.
const LID_SCALE := Vector3(1.0, 1.15, 0.75)


## The lids on `model`'s head (null if it has no such head). Hidden; show them with `visible`.
static func build(model: Node3D) -> Node3D:
	var head := model.find_child("Rogue_Head", true, false) as MeshInstance3D
	var slot := model.find_child("HeadSlot", true, false) as Node3D
	if head == null or slot == null or head.skin == null:
		return null
	# The eyes are part of the head mesh, skinned to the head bone: work in
	# mesh space and carry it over into that bone's space.
	var bind := Transform3D.IDENTITY
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			bind = head.skin.get_bind_pose(i)
	var lids := Node3D.new()
	lids.name = "Eyelids"
	lids.transform = bind
	slot.add_child(lids)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color8(246, 192, 156)
	skin.roughness = 0.95
	var lash := StandardMaterial3D.new()
	lash.albedo_color = Color(0.16, 0.08, 0.06)
	lash.roughness = 1.0
	var lid_mesh := SphereMesh.new()
	lid_mesh.radius = 0.08
	lid_mesh.height = 0.16
	for side in [-1.0, 1.0]:
		var centre := Vector3(side * 0.207, 1.607, 0.41)
		var lid := MeshInstance3D.new()
		lid.mesh = lid_mesh
		lid.material_override = skin
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lid.position = centre
		lid.scale = LID_SCALE
		lids.add_child(lid)
		# A thin dark arc across the lid, curving down like a smile: the
		# closed eye. It follows the lid's rounded surface.
		var points := []
		for k in 9:
			var a := lerpf(PI * 1.12, PI * 1.88, k / 8.0)
			var p := Vector2(cos(a) * 0.062, sin(a) * 0.024 + 0.012)
			var r := clampf(Vector2(p.x / LID_SCALE.x, p.y / LID_SCALE.y).length() / lid_mesh.radius, 0.0, 1.0)
			points.append(centre + Vector3(p.x, p.y, lid_mesh.radius * LID_SCALE.z * sqrt(1.0 - r * r) + 0.004))
		var segments := []
		for k in points.size() - 1:
			segments.append([points[k], points[k + 1]])
		var line := MeshInstance3D.new()
		line.mesh = Effects.cord_mesh(segments, 0.016, lash)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lids.add_child(line)
	lids.visible = false
	return lids
