class_name ClimberOutfit
extends RefCounted
## What the rock climber wears (see ClimberNpc): the climbing helmet, a harness of yellow webbing with
## a belt, leg loops and a pouch of nails, a coil of hemp rope across the chest, a hammer on the hip,
## leather cuffs and fingerless gloves, and gaiters over thick-soled boots. Everything is built from
## parts on the bones of the Rogue rig (metres, y up, the face towards +z, see ClimbHelmet for the head)
## and every part has a grain of its own, so nothing looks like plain plastic.

const WEBBING := Color(0.86, 0.72, 0.16)
const WEBBING_DARK := Color(0.6, 0.48, 0.1)
const LEATHER := Color(0.45, 0.28, 0.14)
const LEATHER_DARK := Color(0.28, 0.17, 0.09)
const HEMP := Color(0.68, 0.56, 0.34)
const STEEL := Color(0.5, 0.51, 0.55)
const BRASS := Color(0.72, 0.56, 0.24)
const GAITER := Color(0.34, 0.3, 0.24)
const WOOD := Color(0.5, 0.34, 0.18)


## A bone's attachment, made once and found again by its name.
static func _on(model: Node3D, bone: String) -> BoneAttachment3D:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var existing := skeleton.find_child("Climb_" + bone, false, false) as BoneAttachment3D
	if existing != null:
		return existing
	var att := BoneAttachment3D.new()
	att.name = "Climb_" + bone
	att.bone_name = bone
	skeleton.add_child(att)
	return att


static func _grain(base: Color, grain: float, metal := 0.0, rough := 0.8, frequency := 0.2) -> StandardMaterial3D:
	return ClimbHelmet.material(base, grain, metal, rough, frequency)


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	return ClimbHelmet.part(parent, mesh, pos, mat, rot_deg, scale)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


static func _torus(inner: float, outer: float, rings := 20) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = 8
	return mesh


## Puts everything on `model`: the helmet, the harness, the rope, the tools, the gloves and the boots.
static func put_on(model: Node3D) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or model.find_child("Climb_hips", true, false) != null:
		return
	var slot := HairLook.head_slot(model)
	if slot != null:
		slot.add_child(ClimbHelmet.build())
		HairLook.cover(model, true)
	_harness(model)
	_rope(model)
	_tools(model)
	_hands(model)
	_boots(model)


## The belt round the hips, a loop round each thigh, and two straps over the shoulders joined by a chest strap.
static func _harness(model: Node3D) -> void:
	var web := _grain(WEBBING, 0.3, 0.0, 0.9, 0.35)
	var dark := _grain(WEBBING_DARK, 0.25, 0.0, 0.9, 0.35)
	var steel := _grain(STEEL, 0.2, 0.8, 0.35)
	var hips := _on(model, "hips")
	var belt := _torus(0.17, 0.2)
	_part(hips, belt, Vector3(0, 0.12, 0), web, Vector3.ZERO, Vector3(1.1, 0.8, 0.85))
	_part(hips, _box(Vector3(0.08, 0.07, 0.03)), Vector3(0, 0.12, 0.17), steel, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var leg := _on(model, "upperleg.l" if side > 0.0 else "upperleg.r")
		_part(leg, _torus(0.095, 0.135), Vector3(0, -0.12, 0), web, Vector3.ZERO, Vector3(1.0, 1.4, 1.0))
		_part(leg, _box(Vector3(0.03, 0.2, 0.03)), Vector3(0.0, 0.0, 0.1), dark)
	var chest := _on(model, "chest")
	for side in [-1.0, 1.0]:
		_part(chest, _box(Vector3(0.06, 0.5, 0.02)), Vector3(0.1 * side, -0.14, 0.27), web, Vector3(0, 0, -6.0 * side))
		_part(chest, _box(Vector3(0.06, 0.5, 0.02)), Vector3(0.1 * side, -0.14, -0.27), dark, Vector3(0, 0, -6.0 * side))
	_part(chest, _box(Vector3(0.3, 0.05, 0.02)), Vector3(0, -0.12, 0.28), web)
	_part(chest, _box(Vector3(0.05, 0.07, 0.025)), Vector3(0, -0.12, 0.29), steel)


## A coil of hemp rope strapped flat to the back, with the loose end hanging from it.
static func _rope(model: Node3D) -> void:
	var hemp := _grain(HEMP, 0.3, 0.0, 0.95, 0.5)
	var chest := _on(model, "chest")
	var coil := Node3D.new()
	coil.name = "RopeCoil"
	chest.add_child(coil)
	coil.position = Vector3(0, -0.12, -0.3)
	for i in 5:
		var ring := _part(coil, _torus(0.15, 0.2), Vector3(0, 0, (i - 2) * 0.03), hemp, Vector3(90, 0, 0))
		ring.name = "Turn%d" % i
	_part(coil, _box(Vector3(0.05, 0.3, 0.03)), Vector3(0.0, 0.0, -0.09), hemp)
	_part(coil, _cylinder(0.02, 0.02, 0.3, 8), Vector3(0.1, -0.2, 0.0), hemp, Vector3(0, 0, 8))


## On the belt: a pouch of nails on the left, and the hammer in its loop on the right (it moves to the
## hand while he hammers, see hammer_in_hand).
static func _tools(model: Node3D) -> void:
	var leather := _grain(LEATHER, 0.3, 0.0, 0.85, 0.3)
	var dark := _grain(LEATHER_DARK, 0.25, 0.0, 0.85, 0.3)
	var brass := _grain(BRASS, 0.18, 0.8, 0.35)
	var steel := _grain(STEEL, 0.2, 0.8, 0.35)
	var wood := _grain(WOOD, 0.3, 0.0, 0.8, 0.4)
	var hips := _on(model, "hips")
	_part(hips, _box(Vector3(0.11, 0.14, 0.07)), Vector3(0.24, 0.1, 0.1), leather, Vector3(0, 0, -6))
	_part(hips, _box(Vector3(0.12, 0.04, 0.075)), Vector3(0.24, 0.18, 0.1), dark)
	for i in 3:
		_part(hips, _cylinder(0.008, 0.008, 0.1, 6), Vector3(0.21 + i * 0.03, 0.24, 0.1), steel)
	_part(hips, _box(Vector3(0.02, 0.02, 0.005)), Vector3(0.24, 0.12, 0.14), brass)
	var loop := Node3D.new()
	loop.name = "HipHammer"
	hips.add_child(loop)
	loop.position = Vector3(-0.24, 0.02, 0.08)
	_part(loop, _cylinder(0.014, 0.017, 0.3, 8), Vector3(0, -0.12, 0), wood)
	_part(loop, _box(Vector3(0.1, 0.05, 0.05)), Vector3(0.0, 0.04, 0), steel)
	_part(loop, _box(Vector3(0.025, 0.04, 0.03)), Vector3(0.065, 0.04, 0), steel)
	var hand_slot := model.find_child("handslot_r", true, false) as Node3D
	if hand_slot != null:
		var held := Node3D.new()
		held.name = "HandHammer"
		hand_slot.add_child(held)
		held.visible = false
		_part(held, _cylinder(0.014, 0.017, 0.3, 8), Vector3(0, 0, 0.04), wood, Vector3(90, 0, 0))
		_part(held, _box(Vector3(0.06, 0.05, 0.1)), Vector3(0, 0.0, 0.2), steel)
		_part(held, _box(Vector3(0.04, 0.025, 0.03)), Vector3(0, 0.0, 0.27), steel)


## The hammer swings in the hand (true) or hangs in its loop on the belt (false).
static func hammer_in_hand(model: Node3D, in_hand: bool) -> void:
	var held := model.find_child("HandHammer", true, false) as Node3D
	var loop := model.find_child("HipHammer", true, false) as Node3D
	if held != null:
		held.visible = in_hand
	if loop != null:
		loop.visible = not in_hand


## Leather cuffs at the wrists and fingerless gloves.
static func _hands(model: Node3D) -> void:
	var leather := _grain(LEATHER, 0.3, 0.0, 0.85, 0.3)
	var dark := _grain(LEATHER_DARK, 0.25, 0.0, 0.85, 0.3)
	for side in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var hand := _on(model, "hand." + side)
		_part(hand, _cylinder(0.062, 0.058, 0.1, 10), Vector3(-0.05 * sign, 0, 0), leather, Vector3(0, 0, 90))
		_part(hand, _box(Vector3(0.13, 0.03, 0.1)), Vector3(0.05 * sign, 0.035, 0), dark)
		_part(hand, _box(Vector3(0.1, 0.05, 0.11)), Vector3(0.06 * sign, 0.0, 0), leather)


## Gaiters over the shins and thick lugged soles.
static func _boots(model: Node3D) -> void:
	var gaiter := _grain(GAITER, 0.3, 0.0, 0.9, 0.35)
	var sole := _grain(LEATHER_DARK, 0.3, 0.0, 0.9, 0.5)
	var brass := _grain(BRASS, 0.18, 0.8, 0.35)
	for side in ["l", "r"]:
		var leg := _on(model, "lowerleg." + side)
		_part(leg, _cylinder(0.092, 0.085, 0.22, 12), Vector3(0, -0.12, 0), gaiter)
		for i in 3:
			_part(leg, _cylinder(0.012, 0.012, 0.012, 8), Vector3(0, -0.06 - i * 0.07, 0.09), brass, Vector3(90, 0, 0))
		var foot := _on(model, "foot." + side)
		_part(foot, _box(Vector3(0.13, 0.05, 0.3)), Vector3(0, -0.04, 0.07), sole)
