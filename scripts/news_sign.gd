class_name NewsSign
extends RefCounted
## The town crier's NEWS! sign, made like the pub's sign (see PubSign) and the village houses' half-timber:
## a painted board of old planks in the crown's blue with the gilt NEWS! lettering, the crown in a gilt ring
## and the times of the news (tools/make_news_sign_painting.py), hanging by two iron chains from the beam of a
## little gate of oak. The board has a moulding round its edge and a cornice on top, the posts, the beam, the
## moulding and the roof boards are the hewn oak of the houses' beams (VillageHouse._beam: rounded edges, a
## hair crooked, the same grain and normal map), the feet are stone and the post caps brass. The lettering is
## part of the painting, so it is worn and shows the grain like the paint does; the text of the mouse-over is
## in CrierNews.SIGN_TIP.
##
## The sign is built in the podium's space (see CrierPodium.build); the board faces +z.

## The board in metres, its thickness and the moulding round it (as on the pub's sign).
const WIDE := 1.7
const TALL := 0.9
const THICK := 0.08
const LIP := 0.04
const LIP_RISE := 0.02
## The middle of the board over the ground, and how far the posts stand from the middle.
const BOARD_Y := 1.75
const HALF := 1.05
const BEAM_Y := 2.46
const PAINTING := "res://assets/signs/news_sign%s"
const BRASS := Color(0.95, 0.74, 0.28)
const STONE := Color(0.7, 0.68, 0.64)
const TIMBER_DARK := Color(0.32, 0.22, 0.15)
const IRON := Color(0.34, 0.35, 0.37)

static var _face: StandardMaterial3D


## Builds the sign standing on the ground at `at` (in `parent`'s space) and returns its root.
static func build(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "NewsSign"
	root.position = at
	parent.add_child(root)
	var parts := {}
	# Two posts of oak on stone feet, the beam over them and a little gabled roof of boards.
	var props := WeatheredProps.Builder.new()
	for x: float in [-HALF, HALF]:
		props.box(Vector3(x, 0, 0), Vector3(0.3, 0.2, 0.3), WeatheredProps.STONES[1], WeatheredProps.STONE)
		VillageHouse._beam(parts, Vector3(x, 1.35, 0), Vector3(0.17, 2.3, 0.17))
		props.cylinder(Vector3(x, 2.5, 0), 0.07, 0.0, 0.18, BRASS, WeatheredProps.FRESH, 8)
	VillageHouse._beam(parts, Vector3(0, BEAM_Y, 0), Vector3(HALF * 2.0 + 0.4, 0.14, 0.2))
	for side: float in [-1.0, 1.0]:
		var tilt := Basis(Vector3.RIGHT, side * 0.5)
		for i in 7:
			var x := -HALF - 0.15 + (HALF * 2.0 + 0.3) / 6.0 * i
			VillageHouse._beam(parts, Vector3(x, BEAM_Y + 0.14, side * 0.16), Vector3(0.3, 0.045, 0.42), tilt)
	# The moulding round the board and its cornice.
	var top := BOARD_Y + TALL * 0.5
	var depth := THICK + LIP_RISE * 2.0
	VillageHouse._beam(parts, Vector3(0, top - LIP * 0.5, 0), Vector3(WIDE, LIP, depth))
	VillageHouse._beam(parts, Vector3(0, top - TALL + LIP * 0.5, 0), Vector3(WIDE, LIP, depth))
	for x: float in [-1.0, 1.0]:
		VillageHouse._beam(parts, Vector3(x * (WIDE * 0.5 - LIP * 0.5), BOARD_Y, 0), Vector3(LIP, TALL - LIP * 2.0, depth))
	VillageHouse._beam(parts, Vector3(0, top + 0.03, 0), Vector3(WIDE + 0.1, 0.06, depth + 0.05))
	var timber := VillageHouse._mesh_of(parts, {"timber": VillageHouse._timber_material()})
	timber.name = "Oak"
	root.add_child(timber)
	props.finish(root, Vector3.ZERO)
	# The board itself: a dark core and the painting on both faces (the back reads the right way round too).
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDE, TALL, THICK)
	core.mesh = box
	core.material_override = WeatheredProps.colour_material(TIMBER_DARK)
	core.position = Vector3(0, BOARD_Y, 0)
	root.add_child(core)
	for side: float in [1.0, -1.0]:
		var face := MeshInstance3D.new()
		face.name = "Face"
		var quad := QuadMesh.new()
		quad.size = Vector2(WIDE, TALL)
		face.mesh = quad
		face.material_override = face_material()
		face.position = Vector3(0, BOARD_Y, side * (THICK * 0.5 + 0.002))
		face.rotation.y = 0.0 if side > 0.0 else PI
		root.add_child(face)
	# Two iron rings on the cornice and the chains up to the beam.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.02
	ring.outer_radius = 0.038
	ring.rings = 10
	ring.ring_segments = 5
	var beam_foot := BEAM_Y - 0.07
	for x: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = ring
		eye.material_override = WeatheredProps.colour_material(IRON, WeatheredProps.IRON)
		eye.position = Vector3(x * WIDE * 0.36, top + 0.09, 0)
		eye.rotation = Vector3(PI * 0.5, 0, PI * 0.5)
		root.add_child(eye)
		HangingShield._chain(root, Vector3(x * WIDE * 0.36, beam_foot, 0), beam_foot - top - 0.1)
	return root


## The painted face with its relief from the normal map.
static func face_material() -> StandardMaterial3D:
	if _face != null:
		return _face
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.78
	var colour := PAINTING % ".jpg"
	if ResourceLoader.exists(colour):
		mat.albedo_texture = load(colour)
	else:
		mat.albedo_color = Color(0.1, 0.2, 0.48)
	var normals := PAINTING % "_n.png"
	if ResourceLoader.exists(normals):
		mat.normal_enabled = true
		mat.normal_texture = load(normals)
	_face = mat
	return mat
